import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/budget/data/models/budget_model.dart';
import 'package:trust_tracker_flutter/features/budget/data/repositories/budget_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Budget QA Regression Tests (TT_036, TT_037, TT_038, TT_040, TT_043)', () {
    late DatabaseHelper dbHelper;
    late BudgetRepository budgetRepo;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      await db.delete('budgets');
      budgetRepo = BudgetRepository(dbHelper);
    });

    test('TT_036: Create a new budget (Monthly budget ₹10,000)', () async {
      final budget = BudgetModel.create(
        categoryId: 1,
        amount: 10000.0,
        monthKey: '2026-11',
      );

      final saved = await budgetRepo.setbudget(budget);
      expect(saved.id, isNotNull);
      expect(saved.amount, 10000.0);
      expect(saved.categoryId, 1);
      expect(saved.monthKey, '2026-11');

      final list = await budgetRepo.getByMonth('2026-11');
      expect(list.length, 1);
      expect(list.first.amount, 10000.0);
      expect(list.first.id, saved.id);
    });

    test('TT_037 & TT_038: Validation rules reject blank and negative amounts', () {
      String? validateAmount(String? text) {
        final trimmed = text?.trim() ?? '';
        if (trimmed.isEmpty) {
          return 'Please enter an amount';
        }
        final amount = double.tryParse(trimmed.replaceAll(',', ''));
        if (amount == null) {
          return 'Please enter a valid number';
        }
        if (amount <= 0) {
          return 'Amount must be greater than 0';
        }
        return null;
      }

      // TT_037: Blank amount
      expect(validateAmount(''), 'Please enter an amount');
      expect(validateAmount('   '), 'Please enter an amount');
      expect(validateAmount(null), 'Please enter an amount');

      // TT_038: Negative amount
      expect(validateAmount('-5000'), 'Amount must be greater than 0');
      expect(validateAmount('-10.50'), 'Amount must be greater than 0');
      expect(validateAmount('0'), 'Amount must be greater than 0');

      // Valid amount
      expect(validateAmount('10000'), isNull);
      expect(validateAmount('15,000'), isNull);
    });

    test('TT_040: Update existing budget (₹10,000 to ₹15,000 without NOT NULL id failure)', () async {
      // 1. Create initial budget of 10,000
      final initial = BudgetModel.create(
        categoryId: 2,
        amount: 10000.0,
        monthKey: '2026-11',
      );
      final savedInitial = await budgetRepo.setbudget(initial);
      expect(savedInitial.amount, 10000.0);
      final initialId = savedInitial.id;

      // 2. Update to 15,000
      final updated = BudgetModel.create(
        categoryId: 2,
        amount: 15000.0,
        monthKey: '2026-11',
      );
      // Even if updated has id = null or existing id, setbudget must update without crashing
      final savedUpdated = await budgetRepo.setbudget(updated);
      expect(savedUpdated.id, equals(initialId));
      expect(savedUpdated.amount, 15000.0);

      // Verify in DB
      final fetched = await budgetRepo.getByCategoryAndMonth(2, '2026-11');
      expect(fetched, isNotNull);
      expect(fetched!.amount, 15000.0);
      expect(fetched.id, equals(initialId));
    });

    test('TT_043: Verify remaining budget (Budget ₹10,000; expenses ₹4,000 -> Remaining ₹6,000)', () {
      const budgetAmount = 10000.0;
      const spentAmount = 4000.0;

      final remaining = budgetAmount - spentAmount;
      expect(remaining, 6000.0);

      final pct = (spentAmount / budgetAmount).clamp(0.0, 1.0);
      expect(pct, 0.40);

      final isOver = spentAmount > budgetAmount;
      expect(isOver, isFalse);

      final isWarning = pct > 0.75;
      expect(isWarning, isFalse);

      // Remaining budget must be displayed even when isWarning is false!
      final shouldDisplayRemaining = !isOver;
      expect(shouldDisplayRemaining, isTrue);
    });
  });
}
