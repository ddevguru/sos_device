import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Token
  static Future<void> saveToken(String token) async {
    await init();
    await _prefs!.setString(AppConstants.keyAuthToken, token);
  }

  static String? getToken() {
    return _prefs?.getString(AppConstants.keyAuthToken);
  }

  static bool hasToken() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearToken() async {
    await init();
    await _prefs!.remove(AppConstants.keyAuthToken);
  }

  // User Data
  static Future<void> saveUser(UserModel user) async {
    await init();
    await _prefs!.setString(AppConstants.keyUserData, jsonEncode(user.toJson()));
  }

  static UserModel? getUser() {
    final raw = _prefs?.getString(AppConstants.keyUserData);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // Onboarding
  static Future<void> setOnboardingSeen() async {
    await init();
    await _prefs!.setBool(AppConstants.keyOnboardingSeen, true);
  }

  static bool hasSeenOnboarding() {
    return _prefs?.getBool(AppConstants.keyOnboardingSeen) ?? false;
  }

  // Paired Device
  static Future<void> savePairedDevice(DeviceModel device) async {
    await init();
    await _prefs!.setString(AppConstants.keyPairedDevice, jsonEncode(device.toJson()));
  }

  static DeviceModel? getPairedDevice() {
    final raw = _prefs?.getString(AppConstants.keyPairedDevice);
    if (raw == null) return null;
    try {
      return DeviceModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPairedDevice() async {
    await init();
    await _prefs!.remove(AppConstants.keyPairedDevice);
  }

  // Base URL
  static Future<void> saveBaseUrl(String url) async {
    await init();
    await _prefs!.setString(AppConstants.keyCustomBaseUrl, url);
  }

  static String getBaseUrl() {
    return _prefs?.getString(AppConstants.keyCustomBaseUrl) ?? AppConstants.defaultBaseUrl;
  }

  // Custom Predefined SOS Message
  static Future<void> saveCustomSosMessage(String message) async {
    await init();
    await _prefs!.setString(AppConstants.keyCustomSosMessage, message.trim());
  }

  static String getCustomSosMessage() {
    final msg = _prefs?.getString(AppConstants.keyCustomSosMessage);
    if (msg != null && msg.trim().isNotEmpty) {
      return msg;
    }
    return AppConstants.defaultSosMessageTemplate;
  }

  // Outgoing SMS Sender Number
  static Future<void> saveSmsSenderNumber(String number) async {
    await init();
    await _prefs!.setString(AppConstants.keySmsSenderNumber, number.trim());
  }

  static String getSmsSenderNumber() {
    final num = _prefs?.getString(AppConstants.keySmsSenderNumber);
    if (num != null && num.trim().isNotEmpty) {
      return num;
    }
    return getUser()?.smsSenderNumber ?? getUser()?.phone ?? '';
  }

  // Double-Clap Detection Settings
  static Future<void> setClapDetectionEnabled(bool enabled) async {
    await init();
    await _prefs!.setBool(AppConstants.keyClapDetectionEnabled, enabled);
  }

  static bool isClapDetectionEnabled() {
    return _prefs?.getBool(AppConstants.keyClapDetectionEnabled) ?? true;
  }

  static Future<void> setClapSensitivity(double thresholdDb) async {
    await init();
    await _prefs!.setDouble(AppConstants.keyClapSensitivity, thresholdDb);
  }

  static double getClapSensitivity() {
    return _prefs?.getDouble(AppConstants.keyClapSensitivity) ?? 78.0;
  }

  // Logout All
  static Future<void> clearAll() async {
    await init();
    await _prefs!.remove(AppConstants.keyAuthToken);
    await _prefs!.remove(AppConstants.keyUserData);
    await _prefs!.remove(AppConstants.keyPairedDevice);
  }
}
