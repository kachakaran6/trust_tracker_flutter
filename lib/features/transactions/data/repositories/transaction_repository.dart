import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:trust_tracker_flutter/core/di/providers.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

class TransactionRepository {
  final Isar _db;
  TransactionRepository(this._db);

  // WRITE
  Future<int> addTransaction(TransactionModel t) async {
    return await _db.writeTxn(() => _db.transactionModels.put(t));
  }

  Future<void> updateTransaction(TransactionModel t) async {
    await _db.writeTxn(() => _db.transactionModels.put(t));
  }

  Future<void> deleteTransaction(int id) async {
    await _db.writeTxn(() => _db.transactionModels.delete(id));
  }

  // READ — All for a given month key (e.g. "2025-03")
  Future<List<TransactionModel>> getByMonth(String monthKey) {
    return _db.transactionModels
        .filter()
        .monthKeyEqualTo(monthKey)
        .sortByDateDesc()
        .findAll();
  }

  // READ — All transactions (for analytics / history)
  Future<List<TransactionModel>> getAll() {
    return _db.transactionModels.where().sortByDateDesc().findAll();
  }

  // READ — paginated (date desc) for transaction list
  Future<List<TransactionModel>> getPaginated({int offset = 0, int limit = 20}) {
    return _db.transactionModels
        .where()
        .sortByDateDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  // READ — recent N
  Future<List<TransactionModel>> getRecent(int n) {
    return _db.transactionModels.where().sortByDateDesc().limit(n).findAll();
  }

  // Monthly Summary (income vs expense)
  Future<Map<String, double>> getMonthlySummary(String monthKey) async {
    final txns = await getByMonth(monthKey);
    double income = 0, expense = 0;
    for (final t in txns) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  // Category spending for a month by transaction type
  Future<Map<int, double>> getCategorySpendingForMonth(
      String monthKey, TransactionType type) async {
    final txns = await _db.transactionModels
        .filter()
        .monthKeyEqualTo(monthKey)
        .typeEqualTo(type)
        .findAll();

    final Map<int, double> result = {};
    for (final t in txns) {
      if (t.categoryId != null) {
        result[t.categoryId!] = (result[t.categoryId!] ?? 0) + t.amount;
      }
    }
    return result;
  }

  // Last 6 months summary for trend chart
  Future<List<Map<String, dynamic>>> getLast6MonthsTrend() async {
    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final summary = await getMonthlySummary(key);
      results.add({
        'month': key,
        'label': _shortMonth(month.month),
        ...summary,
      });
    }
    return results;
  }

  String _shortMonth(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }

  // NEW: Daily spending for a month
  Future<Map<int, double>> getDailySpending(String monthKey, TransactionType type) async {
    final txns = await _db.transactionModels
        .filter()
        .monthKeyEqualTo(monthKey)
        .typeEqualTo(type)
        .findAll();

    final Map<int, double> result = {};
    for (final t in txns) {
      final day = t.date.day;
      result[day] = (result[day] ?? 0) + t.amount;
    }
    return result;
  }

  // NEW: Weekday distribution for a month
  Future<Map<int, double>> getWeekdaySpending(String monthKey, TransactionType type) async {
    final txns = await _db.transactionModels
        .filter()
        .monthKeyEqualTo(monthKey)
        .typeEqualTo(type)
        .findAll();

    final Map<int, double> result = {};
    for (final t in txns) {
      final weekday = t.date.weekday; // 1 = Monday, 7 = Sunday
      result[weekday] = (result[weekday] ?? 0) + t.amount;
    }
    return result;
  }

  // NEW: Time of day distribution
  Future<Map<String, double>> getTimeOfDaySpending(String monthKey, TransactionType type) async {
    final txns = await _db.transactionModels
        .filter()
        .monthKeyEqualTo(monthKey)
        .typeEqualTo(type)
        .findAll();

    final Map<String, double> result = {
      'morning': 0,   // 5am - 12pm
      'afternoon': 0, // 12pm - 5pm
      'evening': 0,   // 5pm - 9pm
      'night': 0,     // 9pm - 5am
    };

    for (final t in txns) {
      final hour = t.date.hour;
      if (hour >= 5 && hour < 12) {
        result['morning'] = result['morning']! + t.amount;
      } else if (hour >= 12 && hour < 17) {
        result['afternoon'] = result['afternoon']! + t.amount;
      } else if (hour >= 17 && hour < 21) {
        result['evening'] = result['evening']! + t.amount;
      } else {
        result['night'] = result['night']! + t.amount;
      }
    }
    return result;
  }

  // NEW: Savings rate trend (last N months)
  Future<List<Map<String, dynamic>>> getSavingsRateTrend(int n) async {
    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];
    for (int i = n - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final summary = await getMonthlySummary(key);
      final inc = summary['income'] ?? 0;
      final exp = summary['expense'] ?? 0;
      final rate = inc > 0 ? ((inc - exp) / inc * 100) : 0.0;
      
      results.add({
        'month': key,
        'label': _shortMonth(month.month),
        'savingsRate': rate,
      });
    }
    return results;
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final isar = ref.watch(isarServiceProvider).db;
  return TransactionRepository(isar);
});
