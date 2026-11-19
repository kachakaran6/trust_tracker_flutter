import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/budget/data/models/budget_model.dart';

class BudgetRepository {
  final DatabaseHelper _dbHelper;
  BudgetRepository(this._dbHelper);

  Future<List<BudgetModel>> getByMonth(String monthKey) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'budgets',
      where: 'monthKey = ?',
      whereArgs: [monthKey],
    );
    return result.map((e) => BudgetModel.fromMap(e)).toList();
  }

  Future<BudgetModel?> getByCategoryAndMonth(int categoryId, String monthKey) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'budgets',
      where: 'categoryId = ? AND monthKey = ?',
      whereArgs: [categoryId, monthKey],
    );
    if (result.isNotEmpty) {
      return BudgetModel.fromMap(result.first);
    }
    return null;
  }

  Future<BudgetModel> setbudget(BudgetModel b) async {
    final db = await _dbHelper.database;
    final existing = await getByCategoryAndMonth(b.categoryId, b.monthKey);
    final map = b.toMap()..remove('id');
    if (existing != null) {
      b.id = existing.id;
      await db.update(
        'budgets',
        map,
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      final id = await db.insert('budgets', map);
      b.id = id;
    }
    return b;
  }

  Future<void> deleteBudget(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(DatabaseHelper.instance);
});
