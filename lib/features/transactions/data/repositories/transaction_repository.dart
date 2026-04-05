import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper;
  final _controller = StreamController<List<TransactionModel>>.broadcast();

  TransactionRepository(this._dbHelper);

  // WRITE
  Future<int> addTransaction(TransactionModel t) async {
    final db = await _dbHelper.database;
    final id = await db.insert('transactions', t.toMap());
    t.id = id; // Set the ID on the object
    _refresh();
    return id;
  }

  Future<void> updateTransaction(TransactionModel t) async {
    final db = await _dbHelper.database;
    await db.update(
      'transactions',
      t.toMap(),
      where: 'id = ?',
      whereArgs: [t.id],
    );
    _refresh();
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    _refresh();
  }

  // READ — All for a given month key (e.g. "2025-03")
  Future<List<TransactionModel>> getByMonth(String monthKey) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'monthKey = ?',
      whereArgs: [monthKey],
      orderBy: 'date DESC',
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // READ — All transactions (for analytics / history)
  Future<List<TransactionModel>> getAll() async {
    final db = await _dbHelper.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // READ — paginated (date desc) for transaction list
  Future<List<TransactionModel>> getPaginated({int offset = 0, int limit = 20}) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // READ — recent N
  Future<List<TransactionModel>> getRecent(int n) async {
    final db = await _dbHelper.database;
    final result = await db.query('transactions', orderBy: 'date DESC', limit: n);
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Stream<List<TransactionModel>> watchAll() {
    _refresh();
    return _controller.stream;
  }

  Future<void> _refresh() async {
    final list = await getAll();
    if (!_controller.isClosed) _controller.add(list);
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
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'monthKey = ? AND type = ?',
      whereArgs: [monthKey, type.index],
    );

    final Map<int, double> spending = {};
    for (final t in result) {
      final model = TransactionModel.fromMap(t);
      if (model.categoryId != null) {
        spending[model.categoryId!] = (spending[model.categoryId!] ?? 0) + model.amount;
      }
    }
    return spending;
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
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'monthKey = ? AND type = ?',
      whereArgs: [monthKey, type.index],
    );

    final Map<int, double> daily = {};
    for (final t in result) {
      final model = TransactionModel.fromMap(t);
      final day = model.date.day;
      daily[day] = (daily[day] ?? 0) + model.amount;
    }
    return daily;
  }

  // NEW: Weekday distribution for a month
  Future<Map<int, double>> getWeekdaySpending(String monthKey, TransactionType type) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'monthKey = ? AND type = ?',
      whereArgs: [monthKey, type.index],
    );

    final Map<int, double> distribution = {};
    for (final t in result) {
      final model = TransactionModel.fromMap(t);
      final weekday = model.date.weekday;
      distribution[weekday] = (distribution[weekday] ?? 0) + model.amount;
    }
    return distribution;
  }

  // NEW: Time of day distribution
  Future<Map<String, double>> getTimeOfDaySpending(String monthKey, TransactionType type) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'monthKey = ? AND type = ?',
      whereArgs: [monthKey, type.index],
    );

    final Map<String, double> hourly = {
      'morning': 0,   // 5am - 12pm
      'afternoon': 0, // 12pm - 5pm
      'evening': 0,   // 5pm - 9pm
      'night': 0,     // 9pm - 5am
    };

    for (final t in result) {
      final model = TransactionModel.fromMap(t);
      final hour = model.date.hour;
      if (hour >= 5 && hour < 12) {
        hourly['morning'] = hourly['morning']! + model.amount;
      } else if (hour >= 12 && hour < 17) {
        hourly['afternoon'] = hourly['afternoon']! + model.amount;
      } else if (hour >= 17 && hour < 21) {
        hourly['evening'] = hourly['evening']! + model.amount;
      } else {
        hourly['night'] = hourly['night']! + model.amount;
      }
    }
    return hourly;
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
  return TransactionRepository(DatabaseHelper.instance);
});
