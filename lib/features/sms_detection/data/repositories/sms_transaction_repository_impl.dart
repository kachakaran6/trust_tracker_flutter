import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/repositories/sms_transaction_repository.dart';

class SmsTransactionRepositoryImpl implements SmsTransactionRepository {
  final DatabaseHelper _dbHelper;

  SmsTransactionRepositoryImpl(this._dbHelper);

  @override
  Future<int> insertDetectedTransaction(DetectedSmsTransaction transaction) async {
    final db = await _dbHelper.database;
    final map = transaction.toMap();
    map.remove('id'); // Auto-incremented
    final id = await db.insert(
      'sms_detected_transactions',
      map,
    );
    transaction.id = id;
    return id;
  }

  @override
  Future<bool> isDuplicate(String fingerprint) async {
    if (fingerprint.isEmpty) return false;
    final db = await _dbHelper.database;
    final result = await db.query(
      'sms_detected_transactions',
      columns: ['id'],
      where: 'smsFingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  @override
  Future<bool> isReferenceProcessed(String referenceNumber) async {
    if (referenceNumber.isEmpty) return false;
    final db = await _dbHelper.database;
    final result = await db.query(
      'sms_detected_transactions',
      columns: ['id'],
      where: 'referenceNumber = ?',
      whereArgs: [referenceNumber],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  @override
  Future<List<DetectedSmsTransaction>> getPendingTransactions() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'sms_detected_transactions',
      where: 'status = ?',
      whereArgs: ['pending_review'],
      orderBy: 'date DESC',
    );
    return result.map((e) => DetectedSmsTransaction.fromMap(e)).toList();
  }

  @override
  Future<List<DetectedSmsTransaction>> getAllDetectedTransactions() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'sms_detected_transactions',
      orderBy: 'date DESC',
    );
    return result.map((e) => DetectedSmsTransaction.fromMap(e)).toList();
  }

  @override
  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM sms_detected_transactions WHERE status = 'pending_review'",
    );
    if (result.isNotEmpty && result.first['c'] != null) {
      return result.first['c'] as int;
    }
    return 0;
  }

  @override
  Future<void> updateStatus(int id, String status, {int? transactionId}) async {
    final db = await _dbHelper.database;
    final values = <String, dynamic>{
      'status': status,
    };
    if (transactionId != null) {
      values['transactionId'] = transactionId;
    }
    await db.update(
      'sms_detected_transactions',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateTransactionDetails(DetectedSmsTransaction transaction) async {
    if (transaction.id == null) return;
    final db = await _dbHelper.database;
    await db.update(
      'sms_detected_transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  @override
  Future<void> deleteDetectedTransaction(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'sms_detected_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteAllPendingRecords() async {
    final db = await _dbHelper.database;
    await db.delete(
      'sms_detected_transactions',
      where: 'status = ?',
      whereArgs: ['pending_review'],
    );
  }

  @override
  Future<void> deleteAllSmsRecords() async {
    final db = await _dbHelper.database;
    await db.delete('sms_detected_transactions');
  }
}
