import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/budget/data/models/budget_model.dart';
import 'package:trust_tracker_flutter/features/budget/data/repositories/budget_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class BudgetState {
  final AsyncValue<List<BudgetModel>> budgets;
  const BudgetState({this.budgets = const AsyncValue.loading()});

  BudgetState copyWith({AsyncValue<List<BudgetModel>>? budgets}) =>
      BudgetState(budgets: budgets ?? this.budgets);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class BudgetNotifier extends StateNotifier<BudgetState> {
  final BudgetRepository _repo;
  final String _monthKey;

  BudgetNotifier(this._repo, this._monthKey) : super(const BudgetState()) {
    _load();
  }

  /// Load all budgets for the current month from Isar into memory.
  Future<void> _load() async {
    try {
      final list = await _repo.getByMonth(_monthKey);
      // Guard: don't update disposed notifier
      if (!mounted) return;
      state = state.copyWith(budgets: AsyncValue.data(list));
    } catch (e, st) {
      if (!mounted) return;
      state = state.copyWith(budgets: AsyncValue.error(e, st));
    }
  }

  /// Save (upsert) a budget and update the in-memory list immediately.
  /// Returns the saved budget so the caller can close the sheet afterwards.
  Future<void> setBudget(BudgetModel budget) async {
    // 1. Write to DB (safe — no provider interaction here)
    await _repo.setbudget(budget);

    // 2. Update in-memory list — one atomic state update, no invalidation
    if (!mounted) return;
    state.budgets.whenData((list) {
      final updated = [
        for (final b in list)
          if (b.categoryId != budget.categoryId) b,
        budget, // replace or append
      ];
      state = state.copyWith(budgets: AsyncValue.data(updated));
    });
  }

  /// Delete a budget and remove it from the in-memory list.
  Future<void> deleteBudget(int id) async {
    await _repo.deleteBudget(id);

    if (!mounted) return;
    state.budgets.whenData((list) {
      state = state.copyWith(
        budgets: AsyncValue.data([for (final b in list) if (b.id != id) b]),
      );
    });
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Non-autoDispose so the in-memory budget list survives the bottom-sheet
/// open/close lifecycle without triggering the '_dependents.isEmpty' assertion.
final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, BudgetState>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  final monthKey = DateTime.now().toMonthKey();
  return BudgetNotifier(repo, monthKey);
});

// ── Helper so other files can keep using toMonthKey() ─────────────────────────
extension _DateMonthKey on DateTime {
  String toMonthKey() =>
      '$year-${month.toString().padLeft(2, '0')}';
}
