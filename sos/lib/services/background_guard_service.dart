import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'storage_service.dart';
import 'alarm_service.dart';
import 'clap_detection_service.dart';
import 'location_service.dart';
import 'api_service.dart';

// The callback function should always be a top-level or static function with @pragma('vm:entry-point')
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SosBackgroundTaskHandler());
}

/// Task handler that runs in the background isolate even when app is closed / minimized
@pragma('vm:entry-point')
class SosBackgroundTaskHandler extends TaskHandler {
  final ClapDetectionService _clapService = ClapDetectionService();
  final AlarmService _alarmService = AlarmService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialize storage in the background isolate
    await StorageService.init();

    // Start background microphone listening
    _clapService.thresholdDb = StorageService.getClapSensitivity();
    await _clapService.startListening(onClap: _onBackgroundDoubleClap);

    await FlutterForegroundTask.updateService(
      notificationTitle: '🛡️ SOS Emergency Guard Active',
      notificationText: 'Listening for Double Claps & ESP32 triggers 24/7',
    );
  }

  void _onBackgroundDoubleClap() async {
    // 1. Immediately sound loud siren alarm on device
    await _alarmService.startAlarm();

    // 2. Update persistent notification
    await FlutterForegroundTask.updateService(
      notificationTitle: '🚨 SOS TRIGGERED VIA DOUBLE CLAP! 🚨',
      notificationText: 'Loud alarm sounding! Dispatching emergency SMS...',
    );

    // 3. Acquire GPS location
    final loc = await LocationService.getCurrentLocation();

    // 4. Retrieve user's custom message
    final customMsg = StorageService.getCustomSosMessage();

    // 5. Send SOS to backend for SMS broadcast
    await ApiService.triggerSOS(
      latitude: loc.latitude,
      longitude: loc.longitude,
      triggerSource: 'clap_detection',
      customMessage: customMsg,
    );

    // 6. Bring the app window to the front on screen
    FlutterForegroundTask.launchApp();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep-alive heartbeat every 15 seconds
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _clapService.stopListening();
  }

  @override
  void onNotificationButtonPressed(String id) async {
    if (id == 'stop_alarm') {
      await _alarmService.stopAlarm();
      await FlutterForegroundTask.updateService(
        notificationTitle: '🛡️ SOS Emergency Guard Active',
        notificationText: 'Alarm silenced. Guard is still monitoring.',
      );
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

/// Controller to manage the 24/7 background guard service
class BackgroundGuardService {
  static final BackgroundGuardService _instance = BackgroundGuardService._internal();
  factory BackgroundGuardService() => _instance;
  BackgroundGuardService._internal();

  /// Initialize foreground task communication port
  static void init() {
    FlutterForegroundTask.initCommunicationPort();
  }

  /// Request permission to ignore battery optimizations so OEM doesn't kill background audio
  Future<bool> requestBatteryOptimizationExemption() async {
    return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  /// Start persistent 24/7 foreground service
  Future<ServiceRequestResult> startGuard() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sos_emergency_guard_channel',
        channelName: 'SOS Emergency Background Guard',
        channelDescription: 'Maintains background microphone listening for double-clap SOS triggers',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        enableVibration: true,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    return await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '🛡️ SOS Emergency Guard Active',
      notificationText: 'Double-clap detection active in background',
      notificationButtons: [
        const NotificationButton(id: 'stop_alarm', text: 'SILENCE ALARM'),
      ],
      callback: startCallback,
    );
  }

  /// Stop persistent foreground service
  Future<ServiceRequestResult> stopGuard() async {
    return await FlutterForegroundTask.stopService();
  }

  /// Check if the service is currently running
  Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
