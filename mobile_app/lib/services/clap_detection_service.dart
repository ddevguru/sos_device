import 'dart:async';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

typedef DoubleClapCallback = void Function();

/// Service to detect double-clap sound spikes via device microphone in real-time
class ClapDetectionService {
  static final ClapDetectionService _instance = ClapDetectionService._internal();
  factory ClapDetectionService() => _instance;
  ClapDetectionService._internal();

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  bool _isListening = false;
  bool get isListening => _isListening;

  // Sound threshold for detecting a clap (default ~78 dB)
  double _thresholdDb = 78.0;
  double get thresholdDb => _thresholdDb;
  set thresholdDb(double val) => _thresholdDb = val;

  DateTime? _firstClapTime;
  DateTime? _lastTriggerTime;

  DoubleClapCallback? onDoubleClapDetected;

  final StreamController<double> _liveDecibelController = StreamController<double>.broadcast();
  Stream<double> get liveDecibelStream => _liveDecibelController.stream;

  final StreamController<bool> _listeningStatusController = StreamController<bool>.broadcast();
  Stream<bool> get listeningStatusStream => _listeningStatusController.stream;

  /// Start microphone listening for double-clap detection
  Future<bool> startListening({DoubleClapCallback? onClap}) async {
    if (onClap != null) {
      onDoubleClapDetected = onClap;
    }

    if (_isListening) return true;

    // Check & request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _isListening = false;
      _listeningStatusController.add(false);
      return false;
    }

    try {
      _noiseMeter = NoiseMeter();
      _noiseSubscription = _noiseMeter!.noiseStream.listen(
        _onNoiseData,
        onError: (err) {
          _isListening = false;
          _listeningStatusController.add(false);
        },
      );

      _isListening = true;
      _listeningStatusController.add(true);
      return true;
    } catch (e) {
      _isListening = false;
      _listeningStatusController.add(false);
      return false;
    }
  }

  void _onNoiseData(NoiseReading reading) {
    final maxDb = reading.maxDecibel;
    _liveDecibelController.add(maxDb);

    final now = DateTime.now();

    // Prevent re-triggering during cooldown (3 seconds after SOS trigger)
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inMilliseconds < 3000) {
      return;
    }

    // Check if current sound spike exceeds clap threshold
    if (maxDb >= _thresholdDb) {
      if (_firstClapTime == null) {
        // First Clap Detected!
        _firstClapTime = now;
      } else {
        final diffMs = now.difference(_firstClapTime!).inMilliseconds;

        // Check if second clap occurred within the valid double-clap window (200ms - 1200ms)
        if (diffMs >= 200 && diffMs <= 1200) {
          // Double Clap Confirmed!
          _firstClapTime = null;
          _lastTriggerTime = now;

          if (onDoubleClapDetected != null) {
            onDoubleClapDetected!();
          }
        } else if (diffMs > 1200) {
          // Window expired: treat this clap as a new first clap
          _firstClapTime = now;
        }
      }
    }
  }

  /// Stop listening to microphone
  Future<void> stopListening() async {
    await _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _isListening = false;
    _firstClapTime = null;
    _listeningStatusController.add(false);
  }

  void dispose() {
    stopListening();
    _liveDecibelController.close();
    _listeningStatusController.close();
  }
}
