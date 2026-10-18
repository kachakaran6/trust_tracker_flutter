import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trust_tracker_flutter/core/services/debt_notification_service.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper;

  TransactionRepository(this._dbHelper);

  // WRITE
  static const String _lastModifiedKey = 'last_transaction_modification_time';

  Future<void> _markModified() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastModifiedKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<int> addTransaction(TransactionModel t) async {
    final db = await _dbHelper.database;
    final id = await db.insert('transactions', t.toMap());
    t.id = id;
    await _markModified();
    if (t.isDebt) {
      if (t.personName != null && t.personName!.trim().isNotEmpty) {
        await saveDebtPersonName(t.personName!.trim());
      }
      await DebtNotificationService.scheduleDebtReminder(t);
    }
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
    await _markModified();
    if (t.isDebt) {
      if (t.personName != null && t.personName!.trim().isNotEmpty) {
        await saveDebtPersonName(t.personName!.trim());
      }
      if (!t.isSettled) {
        await DebtNotificationService.scheduleDebtReminder(t);
      }
    } else if (t.id != null && (t.isSettled || !t.isDebt)) {
      await DebtNotificationService.cancelDebtReminder(t.id!);
    }
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _markModified();
    await DebtNotificationService.cancelDebtReminder(id);
  }

  Future<void> deleteAllTransactions() async {
    final db = await _dbHelper.database;
    await db.delete('transactions');
    await _markModified();
    await DebtNotificationService.cancelAllReminders();
  }

  // READ — By date range (for engagement notifications)
  Future<List<TransactionModel>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // READ — Total count across all transactions (for smart backup)
  Future<int> getTotalCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM transactions');
    return Sqflite.firstIntValue(result) ?? 0;
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
        SUM(CASE WHEN type = ? AND (affectsBalance IS NULL OR affectsBalance = 1) THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = ? AND (affectsBalance IS NULL OR affectsBalance = 1) THEN amount ELSE 0 END) as expense
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
        SUM(CASE WHEN type = ? AND (affectsBalance IS NULL OR affectsBalance = 1) THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = ? AND (affectsBalance IS NULL OR affectsBalance = 1) THEN amount ELSE 0 END) as expense
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
      WHERE date < ? AND (affectsBalance IS NULL OR affectsBalance = 1)
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
      WHERE date >= ? AND date <= ? AND type = ? AND (affectsBalance IS NULL OR affectsBalance = 1)
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
      WHERE date >= ? AND date <= ? AND type = ? AND (affectsBalance IS NULL OR affectsBalance = 1)
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
      WHERE date >= ? AND date <= ? AND type = ? AND (affectsBalance IS NULL OR affectsBalance = 1)
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
      WHERE date >= ? AND date <= ? AND type = ? AND (affectsBalance IS NULL OR affectsBalance = 1)
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

  // ── DEBT & UDHAR SPECIFIC METHODS ──────────────────────────────────────────

  /// Get debts by status (active vs settled) and optional debtType ('given' | 'taken')
  Future<List<TransactionModel>> getDebts({
    bool? isSettled,
    String? debtType,
  }) async {
    final db = await _dbHelper.database;
    final List<String> conditions = ['isDebt = 1'];
    final List<dynamic> args = [];

    if (isSettled != null) {
      conditions.add('isSettled = ?');
      args.add(isSettled ? 1 : 0);
    }

    if (debtType != null && debtType.isNotEmpty) {
      conditions.add('debtType = ?');
      args.add(debtType);
    }

    final result = await db.query(
      'transactions',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'dueDate ASC, date DESC',
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  /// Get debts for a specific person with optional isSettled and debtType filters
  Future<List<TransactionModel>> getDebtsForPerson(
    String personName, {
    bool? isSettled,
    String? debtType,
  }) async {
    final db = await _dbHelper.database;
    final List<String> conditions = ['isDebt = 1', 'LOWER(TRIM(personName)) = LOWER(TRIM(?))'];
    final List<dynamic> args = [personName.trim()];

    if (isSettled != null) {
      conditions.add('isSettled = ?');
      args.add(isSettled ? 1 : 0);
    }

    if (debtType != null && debtType.isNotEmpty) {
      conditions.add('debtType = ?');
      args.add(debtType);
    }

    final result = await db.query(
      'transactions',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return result.map((e) => TransactionModel.fromMap(e)).toList();
  }

  /// Mark a debt transaction as settled (repaid/cleared)
  Future<void> markDebtAsSettled(int transactionId, {bool createSettlementTxn = false}) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (result.isEmpty) return;
    final txn = TransactionModel.fromMap(result.first);

    txn.isSettled = true;
    txn.settledAt = DateTime.now();

    await db.update(
      'transactions',
      txn.toMap(),
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    await DebtNotificationService.cancelDebtReminder(transactionId);
    await _markModified();

    // Optionally create a settlement transaction to record returned/paid cashflow
    if (createSettlementTxn) {
      final isGiven = (txn.debtType ?? 'given') == 'given';
      final personStr = txn.personName?.isNotEmpty == true ? ' to/from ${txn.personName}' : '';
      
      final settlementTxn = TransactionModel.create(
        amount: txn.amount,
        description: isGiven
            ? 'Udhar Settlement Received ($personStr)'
            : 'Udhar Settlement Paid ($personStr)',
        date: DateTime.now(),
        type: isGiven ? TransactionType.income : TransactionType.expense,
        note: 'Settlement for transaction #${txn.id}',
      );
      await db.insert('transactions', settlementTxn.toMap());
    }
  }

  /// Partially settle a debt transaction, reducing its remaining amount and creating a settled record
  Future<void> settlePartialDebt({
    required int transactionId,
    required double settledAmount,
    bool createSettlementTxn = false,
  }) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (result.isEmpty) return;
    final orig = TransactionModel.fromMap(result.first);

    if (settledAmount >= orig.amount) {
      await markDebtAsSettled(transactionId, createSettlementTxn: createSettlementTxn);
      return;
    }

    final remainingAmount = orig.amount - settledAmount;

    // 1. Update original transaction with remaining active debt amount
    await db.update(
      'transactions',
      {'amount': remainingAmount},
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    // 2. Insert the settled portion as a settled debt record
    final isGiven = (orig.debtType ?? 'given') == 'given';
    final personStr = orig.personName?.isNotEmpty == true ? orig.personName! : 'Person';

    final settledTxn = TransactionModel.create(
      amount: settledAmount,
      description: isGiven ? 'Lent to $personStr (Settled)' : 'Borrowed from $personStr (Settled)',
      date: DateTime.now(),
      type: orig.type,
      categoryId: orig.categoryId,
      isDebt: true,
      debtType: orig.debtType,
      personName: orig.personName,
      dueDate: orig.dueDate,
      isSettled: true,
      settledAt: DateTime.now(),
      affectsBalance: orig.affectsBalance,
      note: 'Partial recovery from #${orig.id}',
    );
    await db.insert('transactions', settledTxn.toMap());

    // 3. Create cashflow entry if affects balance
    if (createSettlementTxn) {
      final settlementTxn = TransactionModel.create(
        amount: settledAmount,
        description: isGiven
            ? 'Udhar Settlement Received ($personStr)'
            : 'Udhar Settlement Paid ($personStr)',
        date: DateTime.now(),
        type: isGiven ? TransactionType.income : TransactionType.expense,
        note: 'Partial settlement for transaction #${orig.id}',
      );
      await db.insert('transactions', settlementTxn.toMap());
    }

    await _markModified();
  }

  /// Remove debt flag completely from transaction
  Future<void> clearDebtFlag(int transactionId) async {
    final db = await _dbHelper.database;
    await db.rawUpdate('''
      UPDATE transactions
      SET isDebt = 0, debtType = NULL, personName = NULL, dueDate = NULL, isSettled = 0, settledAt = NULL
      WHERE id = ?
    ''', [transactionId]);

    await DebtNotificationService.cancelDebtReminder(transactionId);
    await _markModified();
  }

  /// Calculate summary stats for debts (Total Given Active, Total Taken Active, Overdue count)
  Future<Map<String, dynamic>> getDebtSummary() async {
    final activeDebts = await getDebts(isSettled: false);
    double totalGiven = 0.0;
    double totalTaken = 0.0;
    int overdueCount = 0;
    final now = DateTime.now();

    for (final d in activeDebts) {
      if ((d.debtType ?? 'given') == 'given') {
        totalGiven += d.amount;
      } else {
        totalTaken += d.amount;
      }

      if (d.dueDate != null && d.dueDate!.isBefore(now)) {
        overdueCount++;
      }
    }

    return {
      'totalGiven': totalGiven,
      'totalTaken': totalTaken,
      'netBalance': totalGiven - totalTaken, // Positive means net receivable
      'activeCount': activeDebts.length,
      'overdueCount': overdueCount,
    };
  }

  /// Get distinct person names previously entered for debts
  Future<List<String>> getDistinctDebtPersonNames() async {
    final prefs = await SharedPreferences.getInstance();
    final prefNames = prefs.getStringList('saved_debt_person_names') ?? [];

    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT DISTINCT personName 
        FROM transactions 
        WHERE isDebt = 1 AND personName IS NOT NULL AND TRIM(personName) != ''
        ORDER BY id DESC
      ''');
      final dbNames = result
          .map((row) => (row['personName'] as String?)?.trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final combinedSet = <String>{};
      for (final n in prefNames) {
        if (n.trim().isNotEmpty) combinedSet.add(n.trim());
      }
      for (final n in dbNames) {
        if (n.trim().isNotEmpty) combinedSet.add(n.trim());
      }
      return combinedSet.toList();
    } catch (_) {
      return prefNames;
    }
  }

  /// Explicitly save a person name to persistent storage
  Future<void> saveDebtPersonName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('saved_debt_person_names') ?? [];
      list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
      list.insert(0, trimmed);
      if (list.length > 100) {
        list.removeRange(100, list.length);
      }
      await prefs.setStringList('saved_debt_person_names', list);
    } catch (_) {}
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(DatabaseHelper.instance);
});
