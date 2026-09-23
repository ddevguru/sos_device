import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact_model.dart';

/// Direct SIM SMS Service: Sends SMS directly from the user's phone SIM card
/// without requiring any 3rd-party provider (no Twilio, no Fast2SMS).
class SmsDirectService {
  static const MethodChannel _smsChannel = MethodChannel('com.example.sos/sms');

  /// Check & request Android SMS permission at runtime
  static Future<bool> requestSmsPermission() async {
    try {
      if (!Platform.isAndroid) return false;
      var status = await Permission.sms.status;
      if (!status.isGranted) {
        status = await Permission.sms.request();
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('[SmsDirectService] Permission error: $e');
      return false;
    }
  }

  /// Send SMS directly through the device's native SIM card via Android SmsManager
  static Future<bool> sendDirectSms({
    required String phoneNumber,
    required String message,
  }) async {
    // Sanitize phone number (remove spaces, dashes)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleanPhone.isEmpty || message.isEmpty) return false;

    try {
      if (Platform.isAndroid) {
        final hasPermission = await requestSmsPermission();
        if (hasPermission) {
          final bool? result = await _smsChannel.invokeMethod('sendDirectSms', {
            'phoneNumber': cleanPhone,
            'message': message,
          });
          return result ?? false;
        }
      }

      // If not Android or permission denied, fallback to opening SMS app
      return await openSmsApp(phoneNumbers: [cleanPhone], message: message);
    } catch (e) {
      debugPrint('[SmsDirectService] Failed to send direct SMS to $cleanPhone: $e');
      // Fallback to opening device's SMS app
      return await openSmsApp(phoneNumbers: [cleanPhone], message: message);
    }
  }

  /// Sends the emergency SOS message to all configured emergency contacts via device SIM
  static Future<Map<String, dynamic>> sendSosToAllContacts({
    required List<ContactModel> contacts,
    required String message,
  }) async {
    if (contacts.isEmpty) {
      return {
        'success': false,
        'sentCount': 0,
        'message': 'No emergency contacts found to send SMS.',
      };
    }

    int sentCount = 0;
    List<String> failedPhones = [];

    // Ensure SMS permission is requested up front
    final hasPermission = await requestSmsPermission();

    for (final contact in contacts) {
      final phone = contact.phone.trim();
      if (phone.isEmpty) continue;

      if (hasPermission && Platform.isAndroid) {
        try {
          final ok = await _smsChannel.invokeMethod<bool>('sendDirectSms', {
            'phoneNumber': phone.replaceAll(RegExp(r'[\s\-]'), ''),
            'message': message,
          });
          if (ok == true) {
            sentCount++;
            continue;
          }
        } catch (e) {
          debugPrint('[SmsDirectService] MethodChannel failed for $phone: $e');
        }
      }
      failedPhones.add(phone);
    }

    // If direct sending wasn't permitted or all failed, open SMS app with all recipients
    if (sentCount == 0 && failedPhones.isNotEmpty) {
      final opened = await openSmsApp(phoneNumbers: failedPhones, message: message);
      return {
        'success': opened,
        'sentCount': opened ? failedPhones.length : 0,
        'message': opened
            ? 'Opened your SMS app with pre-filled SOS message and contacts.'
            : 'SMS permission was denied and could not launch SMS app.',
        'openedSmsApp': true,
      };
    }

    return {
      'success': sentCount > 0,
      'sentCount': sentCount,
      'totalContacts': contacts.length,
      'message': 'Sent direct SIM SMS to $sentCount contact(s)!',
      'openedSmsApp': false,
    };
  }

  /// Fallback: Launches the device's default Messaging app with pre-filled recipients and body
  static Future<bool> openSmsApp({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      final separator = Platform.isAndroid ? '?' : '&';
      final recipients = phoneNumbers.join(';');
      final encodedBody = Uri.encodeComponent(message);
      final uri = Uri.parse('sms:$recipients${separator}body=$encodedBody');

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      } else {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[SmsDirectService] Could not open SMS app: $e');
      return false;
    }
  }
}
