import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Income History & Filtering Tests (TT_020)', () {
    late DatabaseHelper dbHelper;
    late TransactionRepository repo;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      await db.delete('transactions');
      repo = TransactionRepository(dbHelper);
    });

    test('TT_020: Saved income records are all displayed when viewing income history', () async {
      // Insert mixed transactions: 2 incomes and 2 expenses
      final income1 = TransactionModel.create(
        amount: 50000.0,
        description: 'Monthly Salary',
        date: DateTime.now(),
        type: TransactionType.income,
      );
      final income2 = TransactionModel.create(
        amount: 15000.0,
        description: 'Freelance Project',
        date: DateTime.now(),
        type: TransactionType.income,
      );
      final expense1 = TransactionModel.create(
        amount: 2500.0,
        description: 'Groceries',
        date: DateTime.now(),
        type: TransactionType.expense,
      );
      final expense2 = TransactionModel.create(
        amount: 800.0,
        description: 'Dinner',
        date: DateTime.now(),
        type: TransactionType.expense,
      );

      await repo.addTransaction(income1);
      await repo.addTransaction(income2);
      await repo.addTransaction(expense1);
      await repo.addTransaction(expense2);

      // Verify All transactions count
      final allTxns = await repo.getPaginated(filter: const TransactionFilter(type: 'all'));
      expect(allTxns.length, 4);

      // Verify Income history filter
      final incomeTxns = await repo.getPaginated(filter: const TransactionFilter(type: 'income'));
      expect(incomeTxns.length, 2);
      expect(incomeTxns.every((t) => t.type == TransactionType.income), isTrue);

      final descriptions = incomeTxns.map((t) => t.description).toList();
      expect(descriptions, contains('Monthly Salary'));
      expect(descriptions, contains('Freelance Project'));
      expect(descriptions, isNot(contains('Groceries')));
      expect(descriptions, isNot(contains('Dinner')));

      // Total income amount
      final totalIncome = incomeTxns.fold<double>(0.0, (sum, t) => sum + t.amount);
      expect(totalIncome, 65000.0);
    });

    test('TT_020: Legacy transactions with null isDebt are safely included in income history', () async {
      final db = await dbHelper.database;
      await db.insert('transactions', {
        'amount': 25000.0,
        'description': 'Bonus Payment',
        'date': DateTime.now().toIso8601String(),
        'type': TransactionType.income.index,
        'monthKey': '2026-11',
        'createdAt': DateTime.now().toIso8601String(),
        'isDebt': null, // Legacy null value
        'affectsBalance': 1,
      });

      final incomeTxns = await repo.getPaginated(filter: const TransactionFilter(type: 'income'));
      expect(incomeTxns.length, 1);
      expect(incomeTxns.first.description, 'Bonus Payment');
      expect(incomeTxns.first.amount, 25000.0);
    });
  });
}
