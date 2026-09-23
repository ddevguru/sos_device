import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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
  StreamSubscription? _connStateSubscription;

  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleConnectionStatus get status => _status;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  final StreamController<BleConnectionStatus> _statusController =
      StreamController<BleConnectionStatus>.broadcast();
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  SOSButtonCallback? onSOSButtonPressed;

  void _setStatus(BleConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  /// Request Bluetooth & Location permissions required for BLE on Android
  Future<bool> requestBlePermissions() async {
    try {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      await Permission.location.request();

      return scanStatus.isGranted && connectStatus.isGranted;
    } catch (e) {
      debugPrint('[BLE] Permission request error: $e');
      return false;
    }
  }

  /// Start scanning for the ESP32 SOS Button
  Future<void> startScan({Function(List<ScanResult>)? onResults}) async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        debugPrint('[BLE] Bluetooth Low Energy is not supported on this device.');
        _setStatus(BleConnectionStatus.error);
        return;
      }

      // 1. Ensure runtime permissions are granted
      await requestBlePermissions();

      // 2. Check if Bluetooth is turned on
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
          await Future.delayed(const Duration(milliseconds: 800));
        } catch (e) {
          debugPrint('[BLE] Could not turn on Bluetooth automatically: $e');
        }
      }

      _setStatus(BleConnectionStatus.scanning);

      // Stop any existing scan before starting fresh
      await FlutterBluePlus.stopScan();

      // Start scanning with 20 second timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 20),
      );

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (onResults != null) {
          onResults(results);
        }

        // Auto-connect to paired device or any device advertising SOS
        final paired = StorageService.getPairedDevice();
        for (ScanResult r in results) {
          final advName = r.advertisementData.advName;
          final platformName = r.device.platformName;
          final id = r.device.remoteId.str;

          final matchesName = advName.toUpperCase().contains('SOS') ||
              platformName.toUpperCase().contains('SOS') ||
              advName == AppConstants.defaultDeviceName;

          final matchesUuid = r.advertisementData.serviceUuids.any(
            (u) => u.toString().toLowerCase() == AppConstants.bleServiceUuid.toLowerCase(),
          );

          final matchesPaired = paired != null && (
            paired.deviceIdentifier.toLowerCase() == id.toLowerCase() ||
            (paired.deviceIdentifier.isNotEmpty &&
                advName.toLowerCase().contains(paired.deviceIdentifier.toLowerCase()))
          );

          if (matchesPaired || matchesName || matchesUuid) {
            debugPrint('[BLE] Discovered target device: ${advName.isNotEmpty ? advName : platformName} ($id). Auto-connecting...');
            stopScan();
            connectToDevice(r.device, advertisedName: advName.isNotEmpty ? advName : platformName);
            break;
          }
        }
      });
    } catch (e) {
      debugPrint('[BLE] startScan error: $e');
      _setStatus(BleConnectionStatus.error);
    }
  }

  /// Stop active scan
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      if (_status == BleConnectionStatus.scanning) {
        _setStatus(BleConnectionStatus.disconnected);
      }
    } catch (e) {
      debugPrint('[BLE] stopScan error: $e');
    }
  }

  /// Connect to ESP32 Device and subscribe to SOS notifications
  Future<bool> connectToDevice(BluetoothDevice device, {String? advertisedName}) async {
    try {
      _setStatus(BleConnectionStatus.connecting);

      // autoConnect: false enables immediate active connection on Android
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      _connectedDevice = device;

      // Monitor device connection lifecycle
      _connStateSubscription?.cancel();
      _connStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BLE] Device disconnected: ${device.remoteId.str}');
          _connectedDevice = null;
          _notifyCharacteristic = null;
          _setStatus(BleConnectionStatus.disconnected);
        }
      });

      // Brief delay for Android GATT stack to settle before discovering services
      await Future.delayed(const Duration(milliseconds: 500));

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
                debugPrint('[BLE Notification Received]: $message');
                if (message.startsWith('SOS_TRIGGER')) {
                  // Parse optional hardware GPS coordinates from ESP32 NEO-6M
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

      // Save as paired device in local storage
      final effectiveName = (advertisedName != null && advertisedName.isNotEmpty)
          ? advertisedName
          : (device.platformName.isNotEmpty ? device.platformName : 'ESP32 Smart SOS Button');

      await StorageService.savePairedDevice(DeviceModel(
        deviceName: effectiveName,
        deviceIdentifier: device.remoteId.str,
        deviceType: 'ble_button',
        batteryLevel: 98,
      ));

      debugPrint('[BLE] Successfully connected and subscribed to $effectiveName (${device.remoteId.str})');
      return true;
    } catch (e) {
      debugPrint('[BLE] connectToDevice error: $e');
      _setStatus(BleConnectionStatus.error);
      return false;
    }
  }

  /// Disconnect device
  Future<void> disconnect() async {
    _connStateSubscription?.cancel();
    _charSubscription?.cancel();
    _scanSubscription?.cancel();
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
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
    } catch (e) {
      debugPrint('[BLE] Error sending STOP_SOS: $e');
    }
  }
}
