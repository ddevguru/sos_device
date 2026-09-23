import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/device_model.dart';
import '../../services/ble_service.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../services/background_guard_service.dart';
import '../../services/clap_detection_service.dart';

class IotDeviceScreen extends StatefulWidget {
  final VoidCallback onSimulateTrigger;

  const IotDeviceScreen({
    Key? key,
    required this.onSimulateTrigger,
  }) : super(key: key);

  @override
  State<IotDeviceScreen> createState() => _IotDeviceScreenState();
}

class _IotDeviceScreenState extends State<IotDeviceScreen> {
  final BleService _bleService = BleService();
  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  DeviceModel? _pairedDevice;
  bool _isPairing = false;
  List<ScanResult> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    _status = _bleService.status;
    _pairedDevice = StorageService.getPairedDevice();
    _bleService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
          _pairedDevice = StorageService.getPairedDevice();
        });
      }
    });

    // Auto-fetch paired device from Render cloud database
    _loadCloudDevice();
  }

  void _loadCloudDevice() async {
    final res = await ApiService.getUserDevices();
    if (res.success && res.data != null && res.data!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _pairedDevice = res.data!.first;
        });
        await StorageService.savePairedDevice(res.data!.first);
      }
    } else {
      // Default to pre-configured hardware model if not yet set
      if (_pairedDevice == null) {
        final defaultDev = DeviceModel(
          deviceName: 'ESP32 Smart SOS Button',
          deviceIdentifier: 'SOS-LIFELINK-BTN',
          deviceType: 'ble_gps_button',
          batteryLevel: 98,
        );
        if (mounted) setState(() => _pairedDevice = defaultDev);
        await StorageService.savePairedDevice(defaultDev);
      }
    }
  }

  void _startScanning() async {
    setState(() {
      _discoveredDevices.clear();
    });

    await _bleService.startScan(
      onResults: (results) {
        if (mounted) {
          setState(() {
            _discoveredDevices = results;
          });
        }
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanning for SOS-LIFELINK-BTN... Make sure ESP32 is powered on!'),
        ),
      );
    }
  }

  void _disconnectDevice() async {
    await _bleService.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BLE Device disconnected.')),
      );
    }
  }

  void _simulateHardwareClick() {
    widget.onSimulateTrigger();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.primaryRed,
        content: Text('🚨 Physical IoT Button Click simulated! SMS alert dispatched to contacts.'),
      ),
    );
  }

  void _manualPairESP32() async {
    final macCtrl = TextEditingController(text: _pairedDevice?.deviceIdentifier ?? 'SOS-LIFELINK-BTN');
    final nameCtrl = TextEditingController(text: _pairedDevice?.deviceName ?? 'ESP32 Smart SOS Button');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pair ESP32 Device Manually', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Device Name', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 12),
            const Text('Hardware Identifier / MAC', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            TextField(controller: macCtrl, style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isPairing = true);
              final res = await ApiService.pairDevice(
                deviceIdentifier: macCtrl.text.trim(),
                deviceName: nameCtrl.text.trim(),
              );
              if (!mounted) return;
              setState(() {
                _isPairing = false;
                if (res.success && res.data != null) {
                  _pairedDevice = res.data;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res.message)),
              );
            },
            child: const Text('Pair Device'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDevicesSection() {
    if (_status != BleConnectionStatus.scanning && _discoveredDevices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (_status == BleConnectionStatus.scanning) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _status == BleConnectionStatus.scanning
                        ? 'Scanning Nearby Devices (${_discoveredDevices.length})'
                        : 'Discovered Devices (${_discoveredDevices.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              if (_status == BleConnectionStatus.scanning)
                TextButton(
                  onPressed: () => _bleService.stopScan(),
                  child: const Text('Stop Scan', style: TextStyle(color: AppTheme.primaryRed, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_discoveredDevices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Searching... Ensure ESP32 is powered on and within range.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            )
          else
            ..._discoveredDevices.map((r) {
              final advName = r.advertisementData.advName;
              final pName = r.device.platformName;
              final displayName = advName.isNotEmpty ? advName : (pName.isNotEmpty ? pName : 'Unknown Peripheral');
              final isSos = displayName.toUpperCase().contains('SOS') ||
                  r.advertisementData.serviceUuids.any(
                    (u) => u.toString().toLowerCase() == AppConstants.bleServiceUuid.toLowerCase(),
                  );

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSos ? AppTheme.accentCyan.withOpacity(0.12) : AppTheme.surfaceCardElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSos ? AppTheme.accentCyan : AppTheme.borderStroke,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSos ? Icons.warning_rounded : Icons.bluetooth_rounded,
                      color: isSos ? AppTheme.accentCyan : AppTheme.textMuted,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: isSos ? AppTheme.accentCyan : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r.device.remoteId.str} | RSSI: ${r.rssi} dBm',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSos ? AppTheme.accentGreen : AppTheme.surfaceCardElevated,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        _bleService.stopScan();
                        _bleService.connectToDevice(r.device, advertisedName: displayName);
                      },
                      child: const Text('Connect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('IoT Hardware Button'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _status == BleConnectionStatus.connected
                      ? AppTheme.accentGreen.withOpacity(0.5)
                      : AppTheme.borderStroke,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_status == BleConnectionStatus.connected
                                  ? AppTheme.accentGreen
                                  : AppTheme.primaryRed)
                              .withOpacity(0.15),
                        ),
                        child: Icon(
                          _status == BleConnectionStatus.connected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_disabled_rounded,
                          size: 32,
                          color: _status == BleConnectionStatus.connected
                              ? AppTheme.accentGreen
                              : AppTheme.primaryRed,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _status == BleConnectionStatus.connected
                                  ? 'Device Connected'
                                  : 'Disconnected',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _pairedDevice?.deviceName ?? 'No physical button paired',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.borderStroke, height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _status == BleConnectionStatus.scanning ? null : _startScanning,
                          icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
                          label: Text(_status == BleConnectionStatus.scanning ? 'Scanning...' : 'Scan & Connect BLE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceCardElevated,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _manualPairESP32,
                          icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                          label: const Text('Save to Cloud DB'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentCyan,
                            side: const BorderSide(color: AppTheme.accentCyan),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_status == BleConnectionStatus.connected) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _disconnectDevice,
                        icon: const Icon(Icons.bluetooth_disabled_rounded, color: AppTheme.primaryRed, size: 18),
                        label: const Text('Disconnect BLE Device', style: TextStyle(color: AppTheme.primaryRed)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryRed),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildDiscoveredDevicesSection(),
            const SizedBox(height: 16),

            // Cloud Database Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderStroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_done_rounded, color: AppTheme.accentGreen),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Render Cloud Database Status',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _pairedDevice != null
                              ? 'Device ID: ${_pairedDevice!.deviceIdentifier}'
                              : 'Pre-linked: SOS-LIFELINK-BTN',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Hardware triggers save alerts to your PostgreSQL DB',
                          style: TextStyle(fontSize: 11, color: AppTheme.accentGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Double Clap Detection Setting Card
            const Text(
              'Acoustic Trigger (Double Clap)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderStroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.mic_rounded, color: AppTheme.accentCyan, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Clap Twice for SOS',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      Switch(
                        value: StorageService.isClapDetectionEnabled(),
                        activeColor: AppTheme.accentCyan,
                        onChanged: (val) async {
                          await StorageService.setClapDetectionEnabled(val);
                          if (val) {
                            await BackgroundGuardService().startGuard();
                          } else {
                            await BackgroundGuardService().stopGuard();
                          }
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val
                                  ? '🛡️ 24/7 Background Clap Guard Activated! Works even when app is closed.'
                                  : 'Background Clap Guard Disabled'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'When enabled, clapping twice in quick succession automatically sounds the loud alarm and dispatches your emergency SMS — even if the phone screen is locked or the app is closed!',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sensitivity Threshold', style: TextStyle(fontSize: 13, color: Colors.white70)),
                      Text('${StorageService.getClapSensitivity().toStringAsFixed(0)} dB',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentCyan)),
                    ],
                  ),
                  Slider(
                    value: StorageService.getClapSensitivity(),
                    min: 65.0,
                    max: 92.0,
                    divisions: 27,
                    activeColor: AppTheme.accentCyan,
                    inactiveColor: AppTheme.surfaceCardElevated,
                    onChanged: (val) async {
                      await StorageService.setClapSensitivity(val);
                      ClapDetectionService().thresholdDb = val;
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final granted = await BackgroundGuardService().requestBatteryOptimizationExemption();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(granted
                                  ? 'Battery optimization disabled for 24/7 guard!'
                                  : 'Battery optimization setting opened'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.battery_charging_full_rounded, size: 18, color: AppTheme.accentAmber),
                      label: const Text('Allow 24/7 Background Running (Disable Battery Saver)', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentAmber,
                        side: const BorderSide(color: AppTheme.accentAmber),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Live Simulator Card
            const Text(
              'Hardware Simulation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderStroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Without Physical Device',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Simulate pressing the hardware button. The app will immediately sound the siren alarm and dispatch SMS to your emergency contacts.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _simulateHardwareClick,
                      icon: const Icon(Icons.touch_app_rounded, color: Colors.white),
                      label: const Text('⚡ Simulate IoT Button Press'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ESP32 Guide Card
            const Text(
              'Hardware Setup (Your ESP32 Wiring)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderStroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('🔘 Push Button: Connect between GPIO 25 and GND (Internal pull-up enabled).',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                  SizedBox(height: 6),
                  Text('💡 Status LED: Connect between GPIO 26 (with 220Ω resistor) and GND.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                  SizedBox(height: 6),
                  Text('🛰️ GPS Module (TinyGPSPlus): GPS TX -> GPIO 16, GPS RX -> GPIO 17.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                  SizedBox(height: 6),
                  Text('⚡ Firmware: Flash esp32_smart_sos_device.ino from the iot_firmware/ folder.',
                      style: TextStyle(fontSize: 13, color: AppTheme.accentCyan, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
