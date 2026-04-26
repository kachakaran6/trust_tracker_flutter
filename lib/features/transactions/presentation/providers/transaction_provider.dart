import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_filter.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';

// Provider to track database changes and trigger refreshes across different providers
final transactionChangeProvider = StateProvider<int>((ref) => 0);

class TransactionListState {
  final List<TransactionModel> transactions;
  final TransactionFilter filter;

  TransactionListState({
    required this.transactions,
    this.filter = const TransactionFilter(),
  });

  TransactionListState copyWith({
    List<TransactionModel>? transactions,
    TransactionFilter? filter,
  }) {
    return TransactionListState(
      transactions: transactions ?? this.transactions,
      filter: filter ?? this.filter,
    );
  }
}

class TransactionListNotifier extends StateNotifier<AsyncValue<TransactionListState>> {
  TransactionListNotifier(this._repo, this.ref) : super(const AsyncValue.loading()) {
    _loadInitial(const TransactionFilter());
  }

  final TransactionRepository _repo;
  final Ref ref;

  Future<void> _loadInitial(TransactionFilter filter) async {
    state = const AsyncValue.loading();
    try {
      // Fetch all transactions matching the filter (no pagination)
      final txns = await _repo.getPaginated(
        offset: 0,
        limit: 10000, // High limit to effectively show all
        filter: filter,
      );
      
      if (mounted) {
        state = AsyncValue.data(TransactionListState(
          transactions: txns,
          filter: filter,
        ));
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> applyFilter(TransactionFilter filter) => _loadInitial(filter);

  Future<void> refresh() {
    // Increment change counter to trigger other providers (dashboard, etc.)
    ref.read(transactionChangeProvider.notifier).update((s) => s + 1);
    final current = state.valueOrNull;
    return _loadInitial(current?.filter ?? const TransactionFilter());
  }

  // ── DB writes ────────────────────────────────────────────────────────
  
  Future<void> addTransaction(TransactionModel t) async {
    try {
      await _repo.addTransaction(t);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTransaction(TransactionModel t) async {
    try {
      await _repo.updateTransaction(t);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _repo.deleteTransaction(id);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}

final transactionListProvider = StateNotifierProvider<TransactionListNotifier,
    AsyncValue<TransactionListState>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionListNotifier(repo, ref);
});


