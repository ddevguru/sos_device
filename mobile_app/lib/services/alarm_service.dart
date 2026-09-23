import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Singleton Service to control the loud emergency siren alarm and vibration
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Timer? _vibrationTimer;

  final StreamController<bool> _alarmStateController = StreamController<bool>.broadcast();
  Stream<bool> get alarmStateStream => _alarmStateController.stream;

  /// Starts the loud emergency siren at maximum volume with pulsing vibration
  Future<void> startAlarm() async {
    if (_isPlaying) return;

    _isPlaying = true;
    _alarmStateController.add(true);

    try {
      // Play system alarm ringtone in continuous loop at maximum volume (1.0)
      FlutterRingtonePlayer().playAlarm(
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    } catch (e) {
      // Fallback: play notification or ringtone if alarm channel has platform issue
      try {
        FlutterRingtonePlayer().playRingtone(
          looping: true,
          volume: 1.0,
          asAlarm: true,
        );
      } catch (_) {}
    }

    // Start aggressive pulsing vibration pattern
    _startVibrationPulse();
  }

  /// Stops and silences the emergency alarm and vibration immediately
  Future<void> stopAlarm() async {
    _isPlaying = false;
    _alarmStateController.add(false);

    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}

    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  void _startVibrationPulse() {
    _vibrationTimer?.cancel();
    // Vibrate immediately
    HapticFeedback.vibrate();

    // Repeat vibration every 600ms while alarm is active
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      HapticFeedback.heavyImpact();
    });
  }

  void dispose() {
    stopAlarm();
    _alarmStateController.close();
  }
}
