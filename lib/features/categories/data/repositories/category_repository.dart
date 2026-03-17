import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:trust_tracker_flutter/core/di/providers.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';

class CategoryRepository {
  final Isar _db;
  CategoryRepository(this._db);

  Future<List<CategoryModel>> getAll() {
    return _db.categoryModels.where().sortByName().findAll();
  }

  Future<List<CategoryModel>> getByType(CategoryType type) {
    return _db.categoryModels.filter().typeEqualTo(type).sortByName().findAll();
  }

  Stream<List<CategoryModel>> watchAll() {
    return _db.categoryModels
        .where()
        .sortByName()
        .build()
        .watch(fireImmediately: true);
  }

  Stream<List<CategoryModel>> watchByType(CategoryType type) {
    return _db.categoryModels
        .filter()
        .typeEqualTo(type)
        .sortByName()
        .build()
        .watch(fireImmediately: true);
  }

  Future<CategoryModel?> getById(int id) {
    return _db.categoryModels.get(id);
  }

  Future<int> add(CategoryModel c) async {
    return await _db.writeTxn(() => _db.categoryModels.put(c));
  }

  Future<void> update(CategoryModel c) async {
    await _db.writeTxn(() => _db.categoryModels.put(c));
  }

  Future<bool> delete(int id) async {
    return await _db.writeTxn(() => _db.categoryModels.delete(id));
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final isar = ref.watch(isarServiceProvider).db;
  return CategoryRepository(isar);
});
