import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
import 'package:trust_tracker_flutter/features/budget/data/models/budget_model.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';

class IsarService {
  late Isar _isar;

  Isar get db => _isar;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [TransactionModelSchema, CategoryModelSchema, BudgetModelSchema],
      directory: dir.path,
      name: AppConstants.dbName,
    );
    _initialized = true;
    await _seedDefaultCategories();
  }

  Future<void> _seedDefaultCategories() async {
    final count = await _isar.categoryModels.count();
    if (count > 0) return; // Already seeded

    final defaults = AppConstants.defaultCategories.map((c) {
      return CategoryModel.create(
        name: c['name'] as String,
        colorHex: c['color'] as String,
        iconName: c['icon'] as String,
        type: c['type'] == 'income' ? CategoryType.income : CategoryType.expense,
        isDefault: true,
      );
    }).toList();

    await _isar.writeTxn(() async {
      await _isar.categoryModels.putAll(defaults);
    });
  }

  Future<void> close() async {
    if (_initialized) await _isar.close();
  }
}
