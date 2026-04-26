import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper;

  TransactionRepository(this._dbHelper);

  // WRITE
  Future<int> addTransaction(TransactionModel t) async {
    final db = await _dbHelper.database;
    final id = await db.insert('transactions', t.toMap());
    t.id = id;
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
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
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

  // READ — All transactions
  Future<List<TransactionModel>> getAll() async {
    final db = await _dbHelper.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // READ — paginated
  Future<int> getCount({TransactionFilter? filter}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic> whereArgs = [];

    if (filter != null) {
      final List<String> conditions = [];
      if (filter.type == 'income') {
        conditions.add('type = ?');
        whereArgs.add(TransactionType.income.index);
      } else if (filter.type == 'expense') {
        conditions.add('type = ?');
        whereArgs.add(TransactionType.expense.index);
      }
      if (filter.searchQuery.isNotEmpty) {
        conditions.add('(description LIKE ? OR note LIKE ?)');
        whereArgs.add('%${filter.searchQuery}%');
        whereArgs.add('%${filter.searchQuery}%');
      }
      if (filter.categoryIds.isNotEmpty) {
        conditions.add('categoryId IN (${filter.categoryIds.map((_) => '?').join(',')})');
        whereArgs.addAll(filter.categoryIds);
      }
      if (filter.dateRange != null) {
        final start = DateTime(filter.dateRange!.start.year, filter.dateRange!.start.month, filter.dateRange!.start.day);
        final end = DateTime(filter.dateRange!.end.year, filter.dateRange!.end.month, filter.dateRange!.end.day, 23, 59, 59);
        conditions.add('date >= ? AND date <= ?');
        whereArgs.add(start.toIso8601String());
        whereArgs.add(end.toIso8601String());
      }
      if (conditions.isNotEmpty) where = conditions.join(' AND ');
    }

    final result = await db.query(
      'transactions',
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<TransactionModel>> getPaginated({
    int offset = 0,
    int limit = 20,
    TransactionFilter? filter,
  }) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs = [];
    
    if (filter != null) {
      final List<String> conditions = [];
      if (filter.type == 'income') {
        conditions.add('type = ?');
        whereArgs.add(TransactionType.income.index);
      } else if (filter.type == 'expense') {
        conditions.add('type = ?');
        whereArgs.add(TransactionType.expense.index);
      }
      if (filter.searchQuery.isNotEmpty) {
        conditions.add('(description LIKE ? OR note LIKE ?)');
        whereArgs.add('%${filter.searchQuery}%');
        whereArgs.add('%${filter.searchQuery}%');
      }
      if (filter.categoryIds.isNotEmpty) {
        conditions.add('categoryId IN (${filter.categoryIds.map((_) => '?').join(',')})');
        whereArgs.addAll(filter.categoryIds);
      }
      if (filter.dateRange != null) {
        final start = DateTime(filter.dateRange!.start.year, filter.dateRange!.start.month, filter.dateRange!.start.day);
        final end = DateTime(filter.dateRange!.end.year, filter.dateRange!.end.month, filter.dateRange!.end.day, 23, 59, 59);
        conditions.add('date >= ? AND date <= ?');
        whereArgs.add(start.toIso8601String());
        whereArgs.add(end.toIso8601String());
      }
      if (conditions.isNotEmpty) where = conditions.join(' AND ');
    }
    
    String orderBy = 'date DESC';
    if (filter != null) {
      String sortCol = 'date';
      switch (filter.sortBy) {
        case TransactionSortBy.date: sortCol = 'date'; break;
        case TransactionSortBy.amount: sortCol = 'amount'; break;
        case TransactionSortBy.description: sortCol = 'description'; break;
      }
      orderBy = '$sortCol ${filter.isAscending ? 'ASC' : 'DESC'}';
    }

    final result = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<List<TransactionModel>> getFilteredForExport(TransactionFilter filter) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs = [];
    final List<String> conditions = [];
    if (filter.type == 'income') {
      conditions.add('type = ?');
      whereArgs.add(TransactionType.income.index);
    } else if (filter.type == 'expense') {
      conditions.add('type = ?');
      whereArgs.add(TransactionType.expense.index);
    }
    if (filter.searchQuery.isNotEmpty) {
      conditions.add('(description LIKE ? OR note LIKE ?)');
      whereArgs.add('%${filter.searchQuery}%');
      whereArgs.add('%${filter.searchQuery}%');
    }
    if (filter.categoryIds.isNotEmpty) {
      conditions.add('categoryId IN (${filter.categoryIds.map((_) => '?').join(',')})');
      whereArgs.addAll(filter.categoryIds);
    }
    if (filter.dateRange != null) {
      final start = DateTime(filter.dateRange!.start.year, filter.dateRange!.start.month, filter.dateRange!.start.day);
      final end = DateTime(filter.dateRange!.end.year, filter.dateRange!.end.month, filter.dateRange!.end.day, 23, 59, 59);
      conditions.add('date >= ? AND date <= ?');
      whereArgs.add(start.toIso8601String());
      whereArgs.add(end.toIso8601String());
    }
    if (conditions.isNotEmpty) where = conditions.join(' AND ');

    String orderBy = 'date ASC';
    final result = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: orderBy,
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<List<TransactionModel>> getRecent(int n) async {
    final db = await _dbHelper.database;
    final result = await db.query('transactions', orderBy: 'date DESC', limit: n);
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // SUMMARIES

  Future<Map<String, double>> getMonthlySummary(String monthKey) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = ? THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = ? THEN amount ELSE 0 END) as expense
      FROM transactions
      WHERE monthKey = ?
    ''', [TransactionType.income.index, TransactionType.expense.index, monthKey]);

    if (result.isEmpty) return {'income': 0, 'expense': 0, 'balance': 0};
    final income = (result.first['income'] as num?)?.toDouble() ?? 0.0;
    final expense = (result.first['expense'] as num?)?.toDouble() ?? 0.0;
    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  Future<Map<String, double>> getRangeSummary(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = ? THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = ? THEN amount ELSE 0 END) as expense
      FROM transactions
      WHERE date >= ? AND date <= ?
    ''', [
      TransactionType.income.index, 
      TransactionType.expense.index, 
      start.toIso8601String(), 
      end.toIso8601String()
    ]);

    if (result.isEmpty) return {'income': 0, 'expense': 0, 'balance': 0};
    final income = (result.first['income'] as num?)?.toDouble() ?? 0.0;
    final expense = (result.first['expense'] as num?)?.toDouble() ?? 0.0;
    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  Future<double> getNetBalanceBefore(DateTime date) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = ? THEN amount ELSE -amount END) as balance
      FROM transactions
      WHERE date < ?
    ''', [TransactionType.income.index, date.toIso8601String()]);

    if (result.isEmpty) return 0.0;
    return (result.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  // ANALYTICS

  Future<Map<int, double>> getCategorySpendingInRange(
      DateTime start, DateTime end, TransactionType type) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT categoryId, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ? AND type = ?
      GROUP BY categoryId
    ''', [start.toIso8601String(), end.toIso8601String(), type.index]);

    final Map<int, double> spending = {};
    for (final row in result) {
      if (row['categoryId'] != null) {
        spending[row['categoryId'] as int] = (row['total'] as num).toDouble();
      }
    }
    return spending;
  }

  Future<Map<int, double>> getDailySpendingInRange(
      DateTime start, DateTime end, TransactionType type) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT CAST(strftime('%d', date) AS INTEGER) as day, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ? AND type = ?
      GROUP BY day
    ''', [start.toIso8601String(), end.toIso8601String(), type.index]);

    final Map<int, double> daily = {};
    for (final t in result) {
      if (t['day'] != null) {
        daily[t['day'] as int] = (t['total'] as num).toDouble();
      }
    }
    return daily;
  }

  Future<Map<int, double>> getWeekdaySpendingInRange(
      DateTime start, DateTime end, TransactionType type) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT strftime('%w', date) as wday, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ? AND type = ?
      GROUP BY wday
    ''', [start.toIso8601String(), end.toIso8601String(), type.index]);

    final Map<int, double> distribution = {};
    for (final t in result) {
      if (t['wday'] != null) {
        int w = int.parse(t['wday'] as String);
        int flutterWday = w == 0 ? 7 : w;
        distribution[flutterWday] = (t['total'] as num).toDouble();
      }
    }
    return distribution;
  }

  Future<Map<String, double>> getTimeOfDaySpendingInRange(
      DateTime start, DateTime end, TransactionType type) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT CAST(strftime('%H', date) AS INTEGER) as hour, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ? AND type = ?
      GROUP BY hour
    ''', [start.toIso8601String(), end.toIso8601String(), type.index]);

    final Map<String, double> hourly = {
      'morning': 0, 'afternoon': 0, 'evening': 0, 'night': 0,
    };
    for (final t in result) {
      final hour = t['hour'] as int;
      final total = (t['total'] as num).toDouble();
      if (hour >= 5 && hour < 12) {
        hourly['morning'] = hourly['morning']! + total;
      } else if (hour >= 12 && hour < 17) {
        hourly['afternoon'] = hourly['afternoon']! + total;
      } else if (hour >= 17 && hour < 21) {
        hourly['evening'] = hourly['evening']! + total;
      } else {
        hourly['night'] = hourly['night']! + total;
      }
    }
    return hourly;
  }

  // TRENDS

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

  String _shortMonth(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(DatabaseHelper.instance);
});
