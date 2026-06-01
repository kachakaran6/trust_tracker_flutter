import 'package:workmanager/workmanager.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/core/services/backup_service.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trust_tracker_flutter/core/services/summary_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/subscriptions/core/subscription_engine.dart';
import 'package:trust_tracker_flutter/core/constants/motivation_messages.dart';
import 'dart:math';

const String autoBackupTask = "com.trusttracker.auto_backup";
const String summaryNotificationTask = "com.trusttracker.summary_notification";
const String subscriptionProcessTask = "com.trusttracker.subscription_process";
const String engagementTask = "com.trusttracker.engagement_task";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    
    final prefs = await SharedPreferences.getInstance();
    final dbHelper = DatabaseHelper.instance;
    final settingsNotifier = SettingsNotifier(prefs);
    final backupService = BackupService(dbHelper, settingsNotifier);
    final subscriptionRepo = SubscriptionRepository(dbHelper);
    final txnRepo = TransactionRepository(dbHelper);

    if (task == subscriptionProcessTask) {
      await SubscriptionEngine.processDueSubscriptions(subscriptionRepo, txnRepo, settingsNotifier.state.currency);
    } else if (task == autoBackupTask) {
      await backupService.performAutoBackup();
    } else if (task == summaryNotificationTask) {
      final summaryService = SummaryService(dbHelper);
      final frequency = settingsNotifier.state.summaryFrequency;
      
      DateTime start;
      DateTime end = DateTime.now();
      
      if (frequency == SummaryFrequency.daily) {
        start = DateTime(end.year, end.month, end.day);
      } else if (frequency == SummaryFrequency.weekly) {
        start = end.subtract(const Duration(days: 7));
      } else {
        start = DateTime(end.year, end.month, 1);
      }

      final data = await summaryService.getSummaryData(start, end);
      final currency = settingsNotifier.state.currency;
      
      String message;
      if (frequency == SummaryFrequency.daily) {
        message = summaryService.generateDailyMessage(data, currency);
      } else {
        message = summaryService.generateWeeklyMessage(data, currency);
      }

      // Show Notification
      final notifications = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('tt_stat_icon');
      await notifications.initialize(const InitializationSettings(android: androidInit));

      const android = AndroidNotificationDetails(
        'summary_channel', 'Financial Summaries',
        importance: Importance.high, priority: Priority.high,
        color: const Color(0xFF008B9C),
        icon: 'tt_stat_icon',
        styleInformation: const BigTextStyleInformation(''),
      );

      await notifications.show(
        100, 
        frequency == SummaryFrequency.daily ? 'Daily Summary' : 
        frequency == SummaryFrequency.weekly ? 'Weekly Insight' : 'Monthly Report',
        message,
        const NotificationDetails(android: android),
      );

      // Schedule the NEXT occurrence recursively
      final hour = prefs.getInt('summary_time_hour') ?? 21;
      final minute = prefs.getInt('summary_time_minute') ?? 0;
      final dayOfWeek = prefs.getInt('summary_day_of_week');
      
      await BackgroundService.scheduleSummaryNotification(
        frequency, 
        hour, 
        minute, 
        dayOfWeek: dayOfWeek,
        isRecursive: true
      );
    } else if (task == engagementTask) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final txns = await txnRepo.getTransactionsByDateRange(startOfDay, endOfDay);
      
      final notifications = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('tt_stat_icon');
      await notifications.initialize(const InitializationSettings(android: androidInit));
      
      const android = AndroidNotificationDetails(
        'engagement_channel', 'Daily Engagement',
        importance: Importance.high, priority: Priority.high,
        color: Color(0xFF008B9C),
        icon: 'tt_stat_icon',
        styleInformation: BigTextStyleInformation(''),
      );

      if (txns.isEmpty) {
        await notifications.show(
          200, 
          'Friendly Reminder', 
          "You haven't recorded any expense today. Keep your records accurate by adding today's transactions.",
          const NotificationDetails(android: android),
        );
      }

      final usedMsgs = prefs.getStringList('used_motivation_msgs') ?? [];
      final msgs = MotivationMessages.messages;
      
      var availableMsgs = msgs.where((m) => !usedMsgs.contains(m)).toList();
      if (availableMsgs.isEmpty) {
        usedMsgs.clear();
        availableMsgs = List.from(msgs);
      }
      
      availableMsgs.shuffle(Random());
      final selectedMsg = availableMsgs.first;
      
      usedMsgs.add(selectedMsg);
      if (usedMsgs.length > 30) {
        usedMsgs.removeAt(0);
      }
      await prefs.setStringList('used_motivation_msgs', usedMsgs);
      
      await notifications.show(
        201, 
        'Daily Insight', 
        selectedMsg,
        const NotificationDetails(android: android),
      );

      await BackgroundService.scheduleEngagementTask();
    }
    
    return Future.value(true);
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      "subscription_periodic",
      subscriptionProcessTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    
    // Always attempt to schedule the engagement task on init so it runs daily
    await scheduleEngagementTask();
  }

  static Future<void> scheduleEngagementTask() async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 21, 0); // 9:00 PM
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    final initialDelay = scheduledDate.difference(now);

    await Workmanager().registerOneOffTask(
      "engagement_task_daily", 
      engagementTask,
      initialDelay: initialDelay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> scheduleBackup(BackupInterval interval, {int? customHours}) async {
    Duration frequency;
    switch (interval) {
      case BackupInterval.hours6:
        frequency = const Duration(hours: 6);
        break;
      case BackupInterval.hours12:
        frequency = const Duration(hours: 12);
        break;
      case BackupInterval.daily:
        frequency = const Duration(days: 1);
        break;
      case BackupInterval.weekly:
        frequency = const Duration(days: 7);
        break;
      case BackupInterval.custom:
        frequency = Duration(hours: customHours ?? 24);
        break;
    }

    await Workmanager().registerPeriodicTask(
      "1",
      autoBackupTask,
      frequency: frequency,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      tag: 'backup',
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> stopBackups() async {
    await Workmanager().cancelByTag('backup');
  }

  static Future<void> scheduleSummaryNotification(SummaryFrequency freq, int hour, int minute, {int? dayOfWeek, bool isRecursive = false}) async {
    print("BackgroundService: Scheduling Summary (One-Off) -> $hour:$minute (Freq: $freq)");
    
    // Only cancel if this is a fresh manual schedule from settings
    if (!isRecursive) {
      await Workmanager().cancelByTag('summary');
    }

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    
    // If we are scheduling for today and it's already past, move to tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (freq == SummaryFrequency.weekly && dayOfWeek != null) {
      while (scheduledDate.weekday != dayOfWeek) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    } else if (freq == SummaryFrequency.monthly) {
      if (scheduledDate.day != 1) {
         scheduledDate = DateTime(now.year, now.month + 1, 1, hour, minute);
      }
    }

    final initialDelay = scheduledDate.difference(now);
    print("BackgroundService: Next task in ${initialDelay.inMinutes} minutes");

    await Workmanager().registerOneOffTask(
      "summary_task_${DateTime.now().millisecondsSinceEpoch}", // Unique ID for every one-off
      summaryNotificationTask,
      initialDelay: initialDelay,
      tag: 'summary',
      existingWorkPolicy: ExistingWorkPolicy.append, // Keep them coming
    );
  }

  static Future<void> cancelSummaryNotifications() async {
    await Workmanager().cancelByTag('summary');
  }
}
