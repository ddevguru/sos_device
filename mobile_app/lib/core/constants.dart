class AppConstants {
  // Live Render Backend API URL
  static const String defaultBaseUrl = 'https://sos-emergency-backend-277q.onrender.com/api';

  // Storage Keys
  static const String keyAuthToken = 'sos_auth_token';
  static const String keyUserData = 'sos_user_data';
  static const String keyPairedDevice = 'sos_paired_device';
  static const String keyOnboardingSeen = 'sos_onboarding_seen';
  static const String keyCustomBaseUrl = 'sos_custom_base_url';
  static const String keyCustomSosMessage = 'sos_custom_sos_message';
  static const String keySmsSenderNumber = 'sos_sms_sender_number';
  static const String keyClapDetectionEnabled = 'sos_clap_detection_enabled';
  static const String keyClapSensitivity = 'sos_clap_sensitivity';

  static const String defaultSosMessageTemplate =
      '🚨 EMERGENCY SOS! I need immediate help. Please contact me or send emergency services. My live location: {location}';

  // IoT Bluetooth Low Energy UUIDs (must match ESP32 firmware)
  static const String bleServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String bleCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String defaultDeviceName = 'SOS-LIFELINK-BTN';

  // Emergency Hotlines (India / International)
  static const String policeNumber = '112';
  static const String ambulanceNumber = '108';
  static const String fireNumber = '101';
  static const String womenHelpline = '1091';
}
