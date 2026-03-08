import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:trust_tracker_flutter/core/di/providers.dart';
import 'package:trust_tracker_flutter/features/budget/data/models/budget_model.dart';

class BudgetRepository {
  final Isar _db;
  BudgetRepository(this._db);

  Future<List<BudgetModel>> getByMonth(String monthKey) {
    return _db.budgetModels.filter().monthKeyEqualTo(monthKey).findAll();
  }

  Future<BudgetModel?> getByCategoryAndMonth(int categoryId, String monthKey) {
    return _db.budgetModels
        .filter()
        .categoryIdEqualTo(categoryId)
        .monthKeyEqualTo(monthKey)
        .findFirst();
  }

  Future<void> setbudget(BudgetModel b) async {
    // Upsert: delete old for same category+month, then insert
    final existing = await getByCategoryAndMonth(b.categoryId, b.monthKey);
    await _db.writeTxn(() async {
      if (existing != null) await _db.budgetModels.delete(existing.id);
      await _db.budgetModels.put(b);
    });
  }

  Future<void> deleteBudget(int id) async {
    await _db.writeTxn(() => _db.budgetModels.delete(id));
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final isar = ref.watch(isarServiceProvider).db;
  return BudgetRepository(isar);
});
