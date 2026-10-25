import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';

abstract class SmsTransactionRepository {
  Future<int> insertDetectedTransaction(DetectedSmsTransaction transaction);
  Future<bool> isDuplicate(String fingerprint);
  Future<bool> isReferenceProcessed(String referenceNumber);
  Future<List<DetectedSmsTransaction>> getPendingTransactions();
  Future<List<DetectedSmsTransaction>> getAllDetectedTransactions();
  Future<int> getPendingCount();
  Future<void> updateStatus(int id, String status, {int? transactionId});
  Future<void> updateTransactionDetails(DetectedSmsTransaction transaction);
  Future<void> deleteDetectedTransaction(int id);
  Future<void> deleteAllPendingRecords();
  Future<void> deleteAllSmsRecords();
}
