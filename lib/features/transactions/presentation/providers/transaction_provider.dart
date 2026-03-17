import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TransactionListNotifier — optimistic in-memory list + background Isar writes
// ─────────────────────────────────────────────────────────────────────────────

class TransactionListNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  TransactionListNotifier(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final TransactionRepository _repo;

  // ── Initial load ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    try {
      final txns = await _repo.getAll();
      if (mounted) state = AsyncValue.data(txns);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Force-refresh from database (e.g. after returning from AddTransaction)
  Future<void> refresh() => _load();

  // ── Optimistic add ────────────────────────────────────────────────────────
  /// 1. Inserts a temporary model into the in-memory list immediately (id = 0).
  /// 2. Writes to Isar in the background.
  /// 3. Replaces the temp entry with the real persisted model (with a real id).
  Future<void> addTransaction(TransactionModel t) async {
    // --- Step 1: Optimistic insert ---
    final current = state.valueOrNull ?? [];
    // Prepare a "pending" copy with id=0 as placeholder
    final pending = t; // same object, id hasn't been assigned yet
    final optimistic = [pending, ...current];
    state = AsyncValue.data(optimistic);

    // --- Step 2: Persist to Isar ---
    try {
      await _repo.addTransaction(t);
      // t.id is now set by Isar (autoIncrement mutates the object)
      // Re-read the list so the id is properly reflected
      final updated = await _repo.getAll();
      if (mounted) state = AsyncValue.data(updated);
    } catch (e) {
      // Rollback on failure
      if (mounted) state = AsyncValue.data(current);
      rethrow;
    }
  }

  // ── Optimistic edit ───────────────────────────────────────────────────────
  Future<void> updateTransaction(TransactionModel t) async {
    final current = state.valueOrNull ?? [];
    // Optimistic replace in list
    final optimistic =
        current.map((item) => item.id == t.id ? t : item).toList();
    state = AsyncValue.data(optimistic);

    try {
      await _repo.updateTransaction(t);
      // Re-sort (date may have changed) by reloading
      final updated = await _repo.getAll();
      if (mounted) state = AsyncValue.data(updated);
    } catch (e) {
      if (mounted) state = AsyncValue.data(current);
      rethrow;
    }
  }

  // ── Optimistic delete ─────────────────────────────────────────────────────
  Future<void> deleteTransaction(int id) async {
    final current = state.valueOrNull ?? [];
    final optimistic = current.where((t) => t.id != id).toList();
    state = AsyncValue.data(optimistic);

    try {
      await _repo.deleteTransaction(id);
    } catch (e) {
      if (mounted) state = AsyncValue.data(current); // rollback
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final transactionListProvider = StateNotifierProvider<TransactionListNotifier,
    AsyncValue<List<TransactionModel>>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionListNotifier(repo);
});
