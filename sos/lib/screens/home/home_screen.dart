import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../models/contact_model.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/ble_service.dart';
import '../../services/alarm_service.dart';
import '../../services/clap_detection_service.dart';
import '../../services/sms_direct_service.dart';
import '../../widgets/sos_pulse_button.dart';
import '../../widgets/iot_status_badge.dart';
import '../contacts/contacts_screen.dart';
import '../profile/profile_screen.dart';
import '../iot/iot_device_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  UserModel? _user;
  final BleService _bleService = BleService();
  final AlarmService _alarmService = AlarmService();
  final ClapDetectionService _clapService = ClapDetectionService();

  BleConnectionStatus _bleStatus = BleConnectionStatus.disconnected;
  bool _isAlarmPlaying = false;
  bool _isClapListening = false;

  bool _isTriggering = false;
  double? _currentLat;
  double? _currentLon;
  String _locationStatusText = 'Fetching live GPS...';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initBleListener();
    _initClapDetection();
    _initAlarmListener();
    _updateLocation();
  }

  void _loadUser() {
    setState(() {
      _user = StorageService.getUser();
    });
    ApiService.getProfile().then((res) {
      if (res.success && res.data != null && mounted) {
        setState(() => _user = res.data);
      }
    });
  }

  void _initAlarmListener() {
    _isAlarmPlaying = _alarmService.isPlaying;
    _alarmService.alarmStateStream.listen((playing) {
      if (mounted) setState(() => _isAlarmPlaying = playing);
    });
  }

  void _initBleListener() {
    _bleStatus = _bleService.status;
    _bleService.statusStream.listen((status) {
      if (mounted) setState(() => _bleStatus = status);
    });

    // Listen to physical IoT button triggers with optional hardware GPS
    _bleService.onSOSButtonPressed = (source, {hardwareLat, hardwareLng}) {
      _triggerEmergencyAlert(
        source: source,
        hardwareLat: hardwareLat,
        hardwareLng: hardwareLng,
      );
    };
  }

  void _initClapDetection() {
    if (StorageService.isClapDetectionEnabled()) {
      _clapService.thresholdDb = StorageService.getClapSensitivity();
      _clapService.startListening(onClap: () {
        // Double clap detected by phone microphone!
        _triggerEmergencyAlert(source: 'clap_detection');
      }).then((started) {
        if (mounted) setState(() => _isClapListening = started);
      });
    }
  }

  Future<void> _updateLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLat = loc.latitude;
        _currentLon = loc.longitude;
        _locationStatusText = loc.latitude != null
            ? '${loc.latitude!.toStringAsFixed(4)}, ${loc.longitude!.toStringAsFixed(4)}'
            : 'Location Unavailable';
      });
    }
  }

  /// Triggers emergency SOS: starts loud siren, sends direct SIM SMS with GPS, and logs to backend
  Future<void> _triggerEmergencyAlert({
    String source = 'app_button',
    double? hardwareLat,
    double? hardwareLng,
  }) async {
    // 1. Immediately sound loud siren alarm on phone!
    await _alarmService.startAlarm();

    if (_isTriggering) return;
    setState(() => _isTriggering = true);

    // 2. Resolve GPS coordinates: prioritize ESP32 hardware GPS if valid, else phone GPS
    if (hardwareLat != null && hardwareLng != null) {
      _currentLat = hardwareLat;
      _currentLon = hardwareLng;
    } else {
      final loc = await LocationService.getCurrentLocation();
      _currentLat = loc.latitude;
      _currentLon = loc.longitude;
    }

    // 3. Prepare Emergency Message with live Google Maps link
    final mapsLink = (_currentLat != null && _currentLon != null)
        ? 'https://maps.google.com/?q=$_currentLat,$_currentLon'
        : 'Location unavailable';

    final user = StorageService.getUser();
    final customMsg = StorageService.getCustomSosMessage();
    String formattedMessage = customMsg
        .replaceAll('{name}', user?.name ?? 'User')
        .replaceAll('{phone}', user?.phone ?? '')
        .replaceAll('{location}', mapsLink);

    if (!formattedMessage.contains('maps.google.com') && mapsLink.startsWith('http')) {
      formattedMessage += '\nLive GPS: $mapsLink';
    }

    // 4. Retrieve Emergency Contacts (Cached locally for instantaneous offline dispatch)
    List<ContactModel> contacts = StorageService.getCachedContacts();
    if (contacts.isEmpty) {
      final contactsRes = await ApiService.getContacts();
      if (contactsRes.success && contactsRes.data != null && contactsRes.data!.isNotEmpty) {
        contacts = contactsRes.data!;
        await StorageService.saveCachedContacts(contacts);
      }
    }

    // 5. Send Direct SMS via Phone SIM (No 3rd-party provider)
    Map<String, dynamic> simResult = {
      'success': false,
      'sentCount': 0,
      'message': 'No contacts saved. Please add emergency contacts in Contacts tab.',
    };

    if (contacts.isNotEmpty) {
      simResult = await SmsDirectService.sendSosToAllContacts(
        contacts: contacts,
        message: formattedMessage,
      );
    }

    // 6. Log SOS event to backend database (asynchronous cloud sync)
    ApiService.triggerSOS(
      latitude: _currentLat,
      longitude: _currentLon,
      triggerSource: source,
      customMessage: customMsg,
    );

    if (!mounted) return;
    setState(() => _isTriggering = false);

    // 7. Display active siren & emergency alert dialog
    _showActiveAlarmModal(simResult, source, contacts.length);
  }

  void _showActiveAlarmModal(Map<String, dynamic> simResult, String source, int contactsCount) {
    String sourceTitle = 'Mobile App Button';
    if (source == 'iot_ble' || source == 'iot_device') {
      sourceTitle = '🔘 ESP32 Hardware Button';
    } else if (source == 'clap_detection') {
      sourceTitle = '👏 Double Clap Detection';
    }

    final bool isSuccess = simResult['success'] == true;
    final int sentCount = simResult['sentCount'] ?? 0;
    final String statusMsg = isSuccess
        ? '📱 Direct SIM SMS sent to $sentCount emergency contact(s) with live Google Maps GPS!'
        : (simResult['message'] ?? 'Direct SMS could not be sent. Tap below to send via SMS app.');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.primaryRed, width: 2),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded, color: AppTheme.primaryRed, size: 48),
            ),
            const SizedBox(height: 12),
            const Text(
              '🚨 SOS ACTIVE - ALARM BLARING!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSuccess
                    ? AppTheme.accentGreen.withOpacity(0.15)
                    : AppTheme.accentAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSuccess ? AppTheme.accentGreen : AppTheme.accentAmber,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.sim_card_download_rounded : Icons.sms_failed_rounded,
                    color: isSuccess ? AppTheme.accentGreen : AppTheme.accentAmber,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusMsg,
                      style: TextStyle(
                        color: isSuccess ? AppTheme.accentGreen : AppTheme.accentAmber,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCardElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trigger Source: $sourceTitle',
                      style: const TextStyle(fontSize: 12, color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('GPS Sent: ${_currentLat != null ? '$_currentLat, $_currentLon' : 'Location Not Available'}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loud siren is sounding at maximum volume. Press the button below to silence.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentCyan,
                side: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _sendDirectSimSms(),
              icon: const Icon(Icons.sms_rounded, color: AppTheme.accentCyan),
              label: const Text(
                '📱 RE-SEND SMS VIA PHONE SIM',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                // Silence alarm & send STOP_SOS to ESP32
                await _alarmService.stopAlarm();
                await _bleService.sendStopSosCommand();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.volume_off_rounded, color: Colors.white),
              label: const Text(
                '🛑 STOP ALARM & SILENCE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendDirectSimSms() async {
    try {
      List<ContactModel> contacts = StorageService.getCachedContacts();
      if (contacts.isEmpty) {
        final contactsRes = await ApiService.getContacts();
        contacts = contactsRes.data ?? [];
        if (contacts.isNotEmpty) {
          await StorageService.saveCachedContacts(contacts);
        }
      }

      final locStr = _currentLat != null
          ? 'https://maps.google.com/?q=$_currentLat,$_currentLon'
          : 'Location not available';
      final user = StorageService.getUser();
      final customMsg = StorageService.getCustomSosMessage();
      String body = customMsg
          .replaceAll('{name}', user?.name ?? 'User')
          .replaceAll('{phone}', user?.phone ?? '')
          .replaceAll('{location}', locStr);

      if (!body.contains('maps.google.com') && locStr.startsWith('http')) {
        body += '\nLive GPS: $locStr';
      }

      final res = await SmsDirectService.sendSosToAllContacts(
        contacts: contacts,
        message: body,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: res['success'] == true ? AppTheme.accentGreen : AppTheme.accentAmber,
            content: Text(res['message'] ?? 'SMS dispatch processed.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Direct SMS Error]: $e');
    }
  }

  void _callHelpline(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildHomeDashboard() {
    final pairedDevice = StorageService.getPairedDevice();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // Flashing Top Siren Warning Banner if Alarm is Active
            if (_isAlarmPlaying)
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryRed.withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SIREN ALARM ACTIVE!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Emergency alarm is sounding at max volume',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () async {
                        await _alarmService.stopAlarm();
                        await _bleService.sendStopSosCommand();
                      },
                      child: const Text('STOP', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Top Bar: User Greeting & IoT / Clap Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${_user?.name.split(' ').first ?? 'User'} 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppTheme.accentGreen, size: 14),
                        const SizedBox(width: 4),
                        const Text(
                          'Emergency System Active',
                          style: TextStyle(fontSize: 12, color: AppTheme.accentGreen, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final status = await Permission.microphone.request();
                            if (status.isGranted) {
                              _initClapDetection();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('🎤 Microphone enabled! Clap twice to trigger SOS.')),
                                );
                              }
                            } else {
                              await openAppSettings();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isClapListening
                                  ? AppTheme.accentCyan.withOpacity(0.18)
                                  : AppTheme.accentAmber.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isClapListening
                                    ? AppTheme.accentCyan.withOpacity(0.4)
                                    : AppTheme.accentAmber.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isClapListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                                  size: 11,
                                  color: _isClapListening ? AppTheme.accentCyan : AppTheme.accentAmber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isClapListening ? 'Clap Active' : 'Mic Off (Tap)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _isClapListening ? AppTheme.accentCyan : AppTheme.accentAmber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IotStatusBadge(
                  status: _bleStatus,
                  deviceName: pairedDevice?.deviceName,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Huge Center Pulse SOS Button
            SosPulseButton(
              isTriggering: _isTriggering,
              onTrigger: () => _triggerEmergencyAlert(source: 'app_button'),
            ),
            const SizedBox(height: 36),

            // Live Location Status Card
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
                      color: AppTheme.primaryRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_rounded, color: AppTheme.brightCrimson),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Live GPS Position',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _locationStatusText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                    tooltip: 'Refresh Location',
                    onPressed: _updateLocation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Hotlines Strip
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Instant Emergency Helplines',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildHotlineCard('Police', AppConstants.policeNumber, Icons.local_police_rounded, AppTheme.accentCyan),
                const SizedBox(width: 10),
                _buildHotlineCard('Ambulance', AppConstants.ambulanceNumber, Icons.medical_services_rounded, AppTheme.primaryRed),
                const SizedBox(width: 10),
                _buildHotlineCard('Fire', AppConstants.fireNumber, Icons.local_fire_department_rounded, AppTheme.accentAmber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotlineCard(String label, String number, IconData icon, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () => _callHelpline(number),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderStroke),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text(number, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeDashboard(),
      const ContactsScreen(),
      IotDeviceScreen(onSimulateTrigger: () => _triggerEmergencyAlert(source: 'iot_device')),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: AppTheme.surfaceCard,
        indicatorColor: AppTheme.primaryRed.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primaryRed),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts_rounded, color: AppTheme.primaryRed),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_outlined),
            selectedIcon: Icon(Icons.bluetooth_connected_rounded, color: AppTheme.accentCyan),
            label: 'IoT Button',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primaryRed),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
