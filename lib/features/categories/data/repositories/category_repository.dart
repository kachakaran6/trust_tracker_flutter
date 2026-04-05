import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper;
  final _controller = StreamController<List<CategoryModel>>.broadcast();

  CategoryRepository(this._dbHelper);

  Future<List<CategoryModel>> getAll() async {
    final db = await _dbHelper.database;
    final result = await db.query('categories', orderBy: 'name ASC');
    return result.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<List<CategoryModel>> getByType(CategoryType type) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type.index],
      orderBy: 'name ASC',
    );
    return result.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Stream<List<CategoryModel>> watchAll() {
    _refresh();
    return _controller.stream;
  }

  Stream<List<CategoryModel>> watchByType(CategoryType type) {
    _refreshByType(type);
    return _controller.stream.map((list) => list.where((c) => c.type == type).toList());
  }

  Future<void> _refreshByType(CategoryType type) async {
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await getAll();
    if (!_controller.isClosed) _controller.add(list);
  }

  Future<CategoryModel?> getById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return CategoryModel.fromMap(result.first);
    }
    return null;
  }

  Future<int> add(CategoryModel c) async {
    final db = await _dbHelper.database;
    final id = await db.insert('categories', c.toMap());
    c.id = id;
    _refresh();
    return id;
  }

  Future<void> update(CategoryModel c) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
    _refresh();
  }

  Future<bool> delete(int id) async {
    final db = await _dbHelper.database;
    final count = await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    _refresh();
    return count > 0;
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(DatabaseHelper.instance);
});
