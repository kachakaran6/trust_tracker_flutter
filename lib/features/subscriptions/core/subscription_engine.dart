import 'package:trust_tracker_flutter/features/subscriptions/data/models/subscription_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';

class SubscriptionEngine {
  static DateTime calculateNextDueDate(DateTime currentDate, BillingCycle cycle, {int? customDays}) {
    switch (cycle) {
      case BillingCycle.daily:
        return currentDate.add(const Duration(days: 1));
      case BillingCycle.weekly:
        return currentDate.add(const Duration(days: 7));
      case BillingCycle.monthly:
        return _addMonths(currentDate, 1);
      case BillingCycle.quarterly:
        return _addMonths(currentDate, 3);
      case BillingCycle.halfYearly:
        return _addMonths(currentDate, 6);
      case BillingCycle.yearly:
        return _addMonths(currentDate, 12);
      case BillingCycle.custom:
        return currentDate.add(Duration(days: customDays ?? 1));
    }
  }

  /// Alias used by AddSubscriptionPage for preview calculation from start date
  static DateTime calcNextDueDate(DateTime startDate, BillingCycle cycle, {int? customDays}) {
    return calculateNextDueDate(startDate, cycle, customDays: customDays);
  }

  static DateTime _addMonths(DateTime date, int months) {
    int newYear = date.year;
    int newMonth = date.month + months;
    if (newMonth > 12) {
      newYear += (newMonth - 1) ~/ 12;
      newMonth = ((newMonth - 1) % 12) + 1;
    }
    
    int newDay = date.day;
    int daysInNewMonth = _daysInMonth(newYear, newMonth);
    if (newDay > daysInNewMonth) {
      newDay = daysInNewMonth;
    }
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute);
  }

  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      return _isLeapYear(year) ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  static bool _isLeapYear(int year) {
    return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
  }

  static Future<void> processDueSubscriptions(
      SubscriptionRepository repo, 
      TransactionRepository txnRepo,
      String currency) async {
    
    final activeSubs = await repo.getActiveSubscriptions();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var sub in activeSubs) {
      if (sub.isPaused) continue;

      final dueDate = DateTime(sub.nextDueDate.year, sub.nextDueDate.month, sub.nextDueDate.day);
      
      // If it's due today or overdue
      if (dueDate.isBefore(today) || dueDate.isAtSameMomentAs(today)) {
        
        // Prevent processing multiple times on same day
        if (sub.lastProcessedDate != null) {
          final lastProcessed = DateTime(sub.lastProcessedDate!.year, sub.lastProcessedDate!.month, sub.lastProcessedDate!.day);
          if (lastProcessed.isAtSameMomentAs(today)) {
            continue;
          }
        }

        // Auto Add Expense
        if (sub.autoAddExpense) {
          final txn = TransactionModel.create(
            amount: sub.amount,
            description: '${sub.name} (Auto-renewal)',
            date: now,
            type: TransactionType.expense,
            categoryId: sub.categoryId,
            note: sub.notes,
          );
          await txnRepo.addTransaction(txn);
        }

        // Generate next due date
        if (sub.repeatEnabled) {
          sub.nextDueDate = calculateNextDueDate(sub.nextDueDate, sub.billingCycle, customDays: sub.customDays);
        } else {
          sub.isPaused = true;
        }

        sub.lastProcessedDate = now;
        await repo.updateSubscription(sub);

        // Notify if enabled
        if (sub.notifyBeforeDays >= 0) {
           // Notifications are handled by background_service scheduling, 
           // but we could also fire immediate local notification here if it auto-renewed today
        }
      }
    }
  }
}
