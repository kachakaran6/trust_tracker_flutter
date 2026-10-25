import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/models/subscription_model.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:trust_tracker_flutter/features/subscriptions/core/subscription_engine.dart';

class SubscriptionListState {
  final AsyncValue<List<SubscriptionModel>> subscriptions;
  const SubscriptionListState({this.subscriptions = const AsyncValue.loading()});

  SubscriptionListState copyWith({AsyncValue<List<SubscriptionModel>>? subscriptions}) {
    return SubscriptionListState(subscriptions: subscriptions ?? this.subscriptions);
  }
}

class SubscriptionListNotifier extends StateNotifier<SubscriptionListState> {
  final SubscriptionRepository _repo;
  final Ref ref;

  SubscriptionListNotifier(this._repo, this.ref) : super(const SubscriptionListState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(subscriptions: const AsyncValue.loading());
    try {
      final list = await _repo.getAllSubscriptions();
      if (mounted) {
        state = state.copyWith(subscriptions: AsyncValue.data(list));
      }
    } catch (e, st) {
      if (mounted) {
        state = state.copyWith(subscriptions: AsyncValue.error(e, st));
      }
    }
  }

  Future<void> refresh() => _load();

  Future<void> addSubscription(SubscriptionModel sub) async {
    await _repo.addSubscription(sub);
    await refresh();
  }

  Future<void> updateSubscription(SubscriptionModel sub) async {
    await _repo.updateSubscription(sub);
    await refresh();
  }

  Future<void> deleteSubscription(int id) async {
    await _repo.deleteSubscription(id);
    await refresh();
  }
  
  Future<void> togglePause(SubscriptionModel sub) async {
    sub.isPaused = !sub.isPaused;
    await _repo.updateSubscription(sub);
    await refresh();
  }
}

final subscriptionListProvider = StateNotifierProvider<SubscriptionListNotifier, SubscriptionListState>((ref) {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return SubscriptionListNotifier(repo, ref);
});

// Provides only the upcoming renewals for dashboard widget
final upcomingSubscriptionsProvider = Provider<AsyncValue<List<SubscriptionModel>>>((ref) {
  final state = ref.watch(subscriptionListProvider);
  return state.subscriptions.whenData((list) {
    final now = DateTime.now();
    // active and next due date is soon
    final active = list.where((s) => !s.isPaused).toList();
    active.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return active;
  });
});
