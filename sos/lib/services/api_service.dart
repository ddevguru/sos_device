import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/contact_model.dart';
import '../models/device_model.dart';
import 'storage_service.dart';

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({required this.success, required this.message, this.data});
}

class ApiService {
  static String get baseUrl => StorageService.getBaseUrl();

  static Map<String, String> _headers({bool needsAuth = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (needsAuth) {
      final token = StorageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // --- AUTHENTICATION ---

  static Future<ApiResponse<UserModel>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? bloodGroup,
    String? medicalNotes,
    String? smsSenderNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers(needsAuth: false),
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'blood_group': bloodGroup ?? '',
          'medical_notes': medicalNotes ?? '',
          if (smsSenderNumber != null && smsSenderNumber.isNotEmpty) 'smsSenderNumber': smsSenderNumber,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = body['token'];
        if (token != null) {
          await StorageService.saveToken(token);
        }
        final user = UserModel.fromJson(body['user']);
        await StorageService.saveUser(user);
        return ApiResponse(success: true, message: body['message'] ?? 'Registration successful', data: user);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Registration failed');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Connection error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<UserModel>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers(needsAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = body['token'];
        if (token != null) {
          await StorageService.saveToken(token);
        }
        final user = UserModel.fromJson(body['user']);
        await StorageService.saveUser(user);
        return ApiResponse(success: true, message: body['message'] ?? 'Login successful', data: user);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Login failed');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Connection error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<UserModel>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers(),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(body['user']);
        await StorageService.saveUser(user);
        return ApiResponse(success: true, message: 'Profile loaded', data: user);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<UserModel>> updateProfile({
    String? name,
    String? phone,
    String? bloodGroup,
    String? medicalNotes,
    String? customSosMessage,
    String? smsSenderNumber,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers(),
        body: jsonEncode({
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (bloodGroup != null) 'bloodGroup': bloodGroup,
          if (medicalNotes != null) 'medicalNotes': medicalNotes,
          if (customSosMessage != null) 'customSosMessage': customSosMessage,
          if (smsSenderNumber != null) 'smsSenderNumber': smsSenderNumber,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(body['user']);
        await StorageService.saveUser(user);
        return ApiResponse(success: true, message: body['message'] ?? 'Profile updated', data: user);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Update failed');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // --- EMERGENCY CONTACTS ---

  static Future<ApiResponse<List<ContactModel>>> getContacts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/contacts'),
        headers: _headers(),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final list = (body['contacts'] as List)
            .map((item) => ContactModel.fromJson(item))
            .toList();
        return ApiResponse(success: true, message: 'Contacts loaded', data: list);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Failed to fetch contacts');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<ContactModel>> addContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/contacts'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'relationship': relationship,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final contact = ContactModel.fromJson(body['contact']);
        return ApiResponse(success: true, message: body['message'] ?? 'Contact added', data: contact);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Failed to add contact');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<void>> deleteContact(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/contacts/$id'),
        headers: _headers(),
      );

      final body = jsonDecode(response.body);
      return ApiResponse(
        success: response.statusCode == 200,
        message: body['message'] ?? 'Contact deleted',
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // --- SOS TRIGGER & ALERTS ---

  static Future<ApiResponse<Map<String, dynamic>>> triggerSOS({
    double? latitude,
    double? longitude,
    String? address,
    String triggerSource = 'app_button',
    int? deviceId,
    String? customMessage,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sos/trigger'),
        headers: _headers(),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'triggerSource': triggerSource,
          'deviceId': deviceId,
          if (customMessage != null && customMessage.isNotEmpty) 'customMessage': customMessage,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          message: body['message'] ?? 'SOS Triggered! SMS dispatched.',
          data: body,
        );
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Failed to trigger SOS');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<List<AlertModel>>> getAlertHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sos/history'),
        headers: _headers(),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final list = (body['alerts'] as List)
            .map((item) => AlertModel.fromJson(item))
            .toList();
        return ApiResponse(success: true, message: 'Alerts loaded', data: list);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Failed to fetch history');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // --- IOT HARDWARE DEVICE PAIRING ---

  static Future<ApiResponse<DeviceModel>> pairDevice({
    required String deviceIdentifier,
    String deviceName = 'SOS IoT Button',
    String deviceType = 'ble_button',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/iot/pair'),
        headers: _headers(),
        body: jsonEncode({
          'deviceIdentifier': deviceIdentifier,
          'deviceName': deviceName,
          'deviceType': deviceType,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final device = DeviceModel.fromJson(body['device']);
        await StorageService.savePairedDevice(device);
        return ApiResponse(success: true, message: body['message'] ?? 'Device paired', data: device);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Failed to pair device');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<List<DeviceModel>>> getDevices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/iot/devices'),
        headers: _headers(),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final list = (body['devices'] as List)
            .map((item) => DeviceModel.fromJson(item))
            .toList();
        return ApiResponse(success: true, message: 'Devices loaded', data: list);
      } else {
        return ApiResponse(success: false, message: body['message'] ?? 'Failed to fetch devices');
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<List<DeviceModel>>> getUserDevices() => getDevices();
}
