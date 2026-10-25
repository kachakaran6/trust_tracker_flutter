import 'package:sqflite/sqflite.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:intl/intl.dart';

class SummaryService {
  final DatabaseHelper _dbHelper;

  SummaryService(this._dbHelper);

  Future<Map<String, dynamic>> getSummaryData(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );

    final transactions = maps.map((m) => TransactionModel.fromJson(m)).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> categorySpending = {};

    for (var t in transactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        // Simplified category tracking
        final categoryId = t.categoryId.toString();
        categorySpending[categoryId] = (categorySpending[categoryId] ?? 0) + t.amount;
      }
    }

    // Find top category
    String topCategoryName = "General";
    if (categorySpending.isNotEmpty) {
      final topCategoryId = categorySpending.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      // We'd need to fetch category name here for better insight
      final catMaps = await db.query('categories', where: 'id = ?', whereArgs: [topCategoryId]);
      if (catMaps.isNotEmpty) {
        topCategoryName = catMaps.first['name'] as String;
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
      'topCategory': topCategoryName,
      'count': transactions.length,
    };
  }

  String generateDailyMessage(Map<String, dynamic> data, String currencyCode) {
    if (data['count'] == 0) return "No transactions recorded today.";
    
    final income = data['income'] as double;
    final expense = data['expense'] as double;
    final balance = data['balance'] as double;
    final topCat = data['topCategory'] as String;
    
    final symbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;

    if (balance >= 0) {
      return "You spent $symbol ${expense.toStringAsFixed(0)} today. $topCat was your top category. You saved $symbol ${balance.toStringAsFixed(0)} — great job!";
    } else {
      return "Today Summary: Income $symbol ${income.toStringAsFixed(0)} | Expense $symbol ${expense.toStringAsFixed(0)}. Watch your spending in $topCat!";
    }
  }

  String generateWeeklyMessage(Map<String, dynamic> data, String currencyCode) {
    final income = data['income'] as double;
    final expense = data['expense'] as double;
    final balance = data['balance'] as double;
    
    final symbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    
    return "This week: $symbol ${income.toStringAsFixed(0)} earned, $symbol ${expense.toStringAsFixed(0)} spent. Net: $symbol ${balance.toStringAsFixed(0)} 📈";
  }
}
