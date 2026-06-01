import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/subscriptions/data/models/subscription_model.dart';
import 'package:trust_tracker_flutter/core/di/providers.dart';

class SubscriptionRepository {
  final DatabaseHelper _dbHelper;

  SubscriptionRepository(this._dbHelper);

  Future<Database> get _db async => await _dbHelper.database;

  Future<int> addSubscription(SubscriptionModel subscription) async {
    final db = await _db;
    subscription.createdAt = DateTime.now();
    subscription.updatedAt = DateTime.now();
    final id = await db.insert('subscriptions', subscription.toMap());
    subscription.id = id;
    return id;
  }

  Future<void> updateSubscription(SubscriptionModel subscription) async {
    final db = await _db;
    subscription.updatedAt = DateTime.now();
    await db.update(
      'subscriptions',
      subscription.toMap(),
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
  }

  Future<void> deleteSubscription(int id) async {
    final db = await _db;
    await db.delete(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SubscriptionModel>> getAllSubscriptions() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'subscriptions',
      orderBy: 'nextDueDate ASC',
    );
    return maps.map((map) => SubscriptionModel.fromMap(map)).toList();
  }

  Future<List<SubscriptionModel>> getActiveSubscriptions() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'subscriptions',
      where: 'isPaused = ?',
      whereArgs: [0],
      orderBy: 'nextDueDate ASC',
    );
    return maps.map((map) => SubscriptionModel.fromMap(map)).toList();
  }

  Future<SubscriptionModel?> getSubscriptionById(int id) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'subscriptions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return SubscriptionModel.fromMap(maps.first);
    }
    return null;
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  return SubscriptionRepository(dbHelper);
});
