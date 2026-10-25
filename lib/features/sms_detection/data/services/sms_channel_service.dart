import 'package:flutter/services.dart';

class SmsChannelService {
  static const MethodChannel _channel = MethodChannel('com.trusttracker/sms_detection');

  static void Function(String sender, String body, int timestamp)? _onSmsCallback;

  static void initialize({
    required void Function(String sender, String body, int timestamp) onSmsReceived,
  }) {
    _onSmsCallback = onSmsReceived;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null && _onSmsCallback != null) {
          final sender = args['sender'] as String? ?? 'UNKNOWN';
          final body = args['body'] as String? ?? '';
          final timestamp = args['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
          _onSmsCallback!(sender, body, timestamp);
        }
      }
    });
  }

  static Future<bool> isSmsDetectionSupported() async {
    try {
      final result = await _channel.invokeMethod<bool>('isSmsDetectionSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkSmsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestSmsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  static Future<void> setDetectionEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSmsDetectionEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> pollPendingNativeSms() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('pollPendingNativeSms');
      if (raw == null) return [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> checkReadPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkReadSmsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestReadPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestReadSmsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> readHistoricalSms({int days = 30}) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('readHistoricalSms', {'days': days});
      if (raw == null) return [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
