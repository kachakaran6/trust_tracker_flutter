import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        await _ensureDefaultCategories(db);
        await _ensureDefaultBudgets(db);
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const boolType = 'INTEGER NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const textNullable = 'TEXT';
    const integerNullable = 'INTEGER';

    // Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id $idType,
        name $textType,
        colorHex $textType,
        iconName $textType,
        type $integerType,
        isDefault $boolType
      )
    ''');

    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id $idType,
        amount $realType,
        description $textType,
        date $textType,
        type $integerType,
        categoryId $integerNullable,
        note $textNullable,
        monthKey $textType,
        createdAt $textType
      )
    ''');

    // Budgets Table
    await db.execute('''
      CREATE TABLE budgets (
        id $idType,
        categoryId $integerType,
        amount $realType,
        monthKey $textType,
        createdAt $textType
      )
    ''');
  }

  Future<void> _ensureDefaultCategories(Database db) async {
    final List<Map<String, dynamic>> maps = await db.query('categories');
    if (maps.isEmpty) {
      for (final c in AppConstants.defaultCategories) {
        final category = {
          'name': c['name'] as String,
          'colorHex': c['color'] as String,
          'iconName': c['icon'] as String,
          'type': c['type'] == 'income'
              ? CategoryType.income.index
              : CategoryType.expense.index,
          'isDefault': 1,
        };
        await db.insert('categories', category);
      }
    }
  }

  Future<void> _ensureDefaultBudgets(Database db) async {
    final List<Map<String, dynamic>> maps = await db.query('budgets');
    if (maps.isEmpty) {
      // Get expense categories to set initial budgets
      final List<Map<String, dynamic>> categories = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: [CategoryType.expense.index],
        limit: 5,
      );

      if (categories.isNotEmpty) {
        final now = DateTime.now();
        final monthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";

        for (final cat in categories) {
          double amount = 0.0;
          final name = cat['name'] as String;
          if (name == 'Food & Dining') amount = 5000.0;
          else if (name == 'Transport') amount = 2000.0;
          else if (name == 'Shopping') amount = 3000.0;
          else if (name == 'Entertainment') amount = 1500.0;
          else continue;

          await db.insert('budgets', {
            'categoryId': cat['id'],
            'amount': amount,
            'monthKey': monthKey,
            'createdAt': now.toIso8601String(),
          });
        }
      }
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
