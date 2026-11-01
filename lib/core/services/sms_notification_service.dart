import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/core/router/app_router.dart';
import 'package:go_router/go_router.dart';

class SmsNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'sms_transaction_channel';
  static const String channelName = 'SMS Transaction Alerts';
  static const String channelDesc =
      'Instant notifications for automatically detected bank SMS transactions';

  static const String prefKeyNotifications = 'sms_notifications_enabled';
  static const String prefKeyExpenseNotifications = 'sms_expense_notifications_enabled';
  static const String prefKeyIncomeNotifications = 'sms_income_notifications_enabled';
  static const String prefKeyRefundNotifications = 'sms_refund_notifications_enabled';

  // In-memory set of notified fingerprints to prevent duplicate notifications
  static final Set<String> _notifiedFingerprints = {};

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('tt_stat_icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  static void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final context = rootNavigatorKey.currentState?.context;
      if (context == null || !context.mounted) return;

      final data = jsonDecode(payload) as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'pending_review';

      if (status == 'approved') {
        // Navigate to general transactions ledger
        context.push('/transactions');
      } else {
        // Navigate to pending SMS review screen
        context.push('/sms-pending');
      }
    } catch (_) {
      // Fail-safe
    }
  }

  /// Sends a rich Trust Tracker notification after transaction persistence
  static Future<void> showTransactionNotification(
    DetectedSmsTransaction transaction, {
    SharedPreferences? prefs,
  }) async {
    // 1. Guard against duplicate notifications for the same transaction
    if (_notifiedFingerprints.contains(transaction.smsFingerprint)) {
      return;
    }

    final p = prefs ?? await SharedPreferences.getInstance();

    // 2. Global notification preference check
    final notificationsEnabled = p.getBool(prefKeyNotifications) ?? true;
    if (!notificationsEnabled) return;

    // 3. Category & direction specific preference checks
    final isExpense = transaction.type == TransactionType.expense;
    if (isExpense) {
      final expenseEnabled = p.getBool(prefKeyExpenseNotifications) ?? true;
      if (!expenseEnabled) return;
    } else {
      final incomeEnabled = p.getBool(prefKeyIncomeNotifications) ?? true;
      if (!incomeEnabled) return;
    }

    // 4. Do not notify for rejected or non-transactions
    if (transaction.status == 'rejected' || transaction.status == 'ignored') {
      return;
    }

    // Mark as notified to ensure idempotency
    _notifiedFingerprints.add(transaction.smsFingerprint);

    final formattedAmt = transaction.money.formatIndian();
    final bank = transaction.bankName ?? 'Bank';
    final merchant = transaction.merchant ?? 'Merchant';

    String title;
    String body;
    Color accentColor;

    if (isExpense) {
      title = 'Expense Detected';
      body = '$formattedAmt debited to $merchant via $bank.';
      accentColor = const Color(0xFFEF4444);
    } else {
      title = 'Income Detected';
      body = '$formattedAmt credited to your $bank account.';
      accentColor = const Color(0xFF10B981);
    }

    final notificationId = (transaction.smsFingerprint.hashCode & 0x7FFFFFFF) % 100000;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      color: accentColor,
      icon: 'tt_stat_icon',
      styleInformation: BigTextStyleInformation(body),
    );

    final details = NotificationDetails(android: androidDetails);

    final payload = jsonEncode({
      'id': transaction.id,
      'status': transaction.status,
      'transactionId': transaction.transactionId,
    });

    try {
      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (_) {
      // Notification failure must not crash or rollback the transaction persistence
    }
  }
}
