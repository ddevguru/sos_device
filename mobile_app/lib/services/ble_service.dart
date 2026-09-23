import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import 'storage_service.dart';

typedef SOSButtonCallback = void Function(String triggerSource, {double? hardwareLat, double? hardwareLng});

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error
}

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _charSubscription;

  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleConnectionStatus get status => _status;

  final StreamController<BleConnectionStatus> _statusController =
      StreamController<BleConnectionStatus>.broadcast();
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  SOSButtonCallback? onSOSButtonPressed;

  void _setStatus(BleConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  /// Start scanning for the ESP32 SOS Button
  Future<void> startScan({Function(List<ScanResult>)? onResults}) async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        _setStatus(BleConnectionStatus.error);
        return;
      }

      _setStatus(BleConnectionStatus.scanning);

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (onResults != null) {
          onResults(results);
        }

        // Auto-connect to known paired device or SOS button
        final paired = StorageService.getPairedDevice();
        for (ScanResult r in results) {
          final name = r.device.platformName;
          final id = r.device.remoteId.str;

          if ((paired != null && paired.deviceIdentifier == id) ||
              name.contains('SOS') ||
              name == AppConstants.defaultDeviceName) {
            FlutterBluePlus.stopScan();
            connectToDevice(r.device);
            break;
          }
        }
      });
    } catch (e) {
      _setStatus(BleConnectionStatus.error);
    }
  }

  /// Stop active scan
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    if (_status == BleConnectionStatus.scanning) {
      _setStatus(BleConnectionStatus.disconnected);
    }
  }

  /// Connect to ESP32 Device and subscribe to SOS notifications
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _setStatus(BleConnectionStatus.connecting);
      await device.connect(autoConnect: true, timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Discover Services
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == AppConstants.bleServiceUuid.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == AppConstants.bleCharUuid.toLowerCase()) {
              _notifyCharacteristic = characteristic;

              // Enable Notifications on ESP32 button pin
              await characteristic.setNotifyValue(true);
              _charSubscription?.cancel();
              _charSubscription = characteristic.onValueReceived.listen((value) {
                final message = utf8.decode(value);
                if (message.startsWith('SOS_TRIGGER')) {
                  // Parse optional hardware GPS coordinates from ESP32
                  double? hLat;
                  double? hLng;
                  if (message.contains('LAT:') && message.contains('LNG:')) {
                    try {
                      final latPart = message.split('LAT:')[1].split(',')[0];
                      final lngPart = message.split('LNG:')[1];
                      hLat = double.tryParse(latPart);
                      hLng = double.tryParse(lngPart);
                    } catch (_) {}
                  }

                  // Physical IoT Button was clicked!
                  if (onSOSButtonPressed != null) {
                    onSOSButtonPressed!('iot_ble', hardwareLat: hLat, hardwareLng: hLng);
                  }
                }
              });
              break;
            }
          }
        }
      }

      _setStatus(BleConnectionStatus.connected);

      // Save as paired device
      await StorageService.savePairedDevice(DeviceModel(
        deviceName: device.platformName.isNotEmpty ? device.platformName : 'SOS Button',
        deviceIdentifier: device.remoteId.str,
        deviceType: 'ble_button',
        batteryLevel: 98,
      ));

      return true;
    } catch (e) {
      _setStatus(BleConnectionStatus.error);
      return false;
    }
  }

  /// Disconnect device
  Future<void> disconnect() async {
    _charSubscription?.cancel();
    _scanSubscription?.cancel();
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
    _setStatus(BleConnectionStatus.disconnected);
  }

  /// Simulator method to trigger IoT button event without physical hardware
  void simulateHardwareButtonPress() {
    if (onSOSButtonPressed != null) {
      onSOSButtonPressed!('iot_simulated');
    }
  }

  /// Sends STOP_SOS command to ESP32 to turn off LED and reset hardware alarm
  Future<void> sendStopSosCommand() async {
    try {
      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.write(utf8.encode('STOP_SOS'));
      }
    } catch (_) {}
  }
}
