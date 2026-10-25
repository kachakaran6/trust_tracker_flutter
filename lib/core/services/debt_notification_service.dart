import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

class DebtNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'debt_reminder_channel';
  static const String channelName = 'Debt & Udhar Reminders';
  static const String channelDesc = 'Notifications for upcoming and due debts or lent money';

  /// Base notification ID offset for debts to avoid collisions with other notification channels
  static const int notificationIdOffset = 50000;

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('tt_stat_icon');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);

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

  /// Schedule a notification for a debt when its due date arrives
  static Future<void> scheduleDebtReminder(TransactionModel transaction) async {
    if (transaction.id == null ||
        !transaction.isDebt ||
        transaction.isSettled ||
        transaction.dueDate == null) {
      return;
    }

    final dueDate = transaction.dueDate!;
    // Only schedule if due date is in the future or today
    final now = DateTime.now();
    if (dueDate.isBefore(now.subtract(const Duration(minutes: 5)))) {
      return;
    }

    final notificationId = notificationIdOffset + (transaction.id! % 40000);

    final isGiven = (transaction.debtType ?? 'given') == 'given';
    final person = transaction.personName?.isNotEmpty == true
        ? transaction.personName!
        : 'Person';

    final title = isGiven
        ? '🏷️ Udhar Reminder (Debt Receivable)'
        : '🏷️ Udhar Reminder (Debt Payable)';

    final body = isGiven
        ? 'Reminder: You gave debt of ₹${transaction.amount.toStringAsFixed(0)} to $person. Time period is completed today! Tap to settle.'
        : 'Reminder: You took debt of ₹${transaction.amount.toStringAsFixed(0)} from $person. Due today! Tap to settle.';

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF8B5CF6), // Purple indicator matching theme
      icon: 'tt_stat_icon',
      styleInformation: BigTextStyleInformation(''),
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      final scheduledTzDateTime = tz.TZDateTime.from(dueDate, tz.local);
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Fallback: If exact scheduling fails, schedule normally if possible
      debugPrint("Scheduled debt notification fallback: $e");
    }
  }

  /// Cancel a scheduled notification when debt is settled or deleted
  static Future<void> cancelDebtReminder(int transactionId) async {
    final notificationId = notificationIdOffset + (transactionId % 40000);
    try {
      await _notifications.cancel(notificationId);
    } catch (e) {
      debugPrint("Failed to cancel debt notification: $e");
    }
  }

  /// Cancel all scheduled debt notifications
  static Future<void> cancelAllReminders() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint("Failed to cancel all debt notifications: $e");
    }
  }
}
