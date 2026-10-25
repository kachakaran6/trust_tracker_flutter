import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';

class SmsParseResult {
  final bool isEligible;
  final bool isTransaction;
  final DetectedSmsTransaction? transaction;
  final String? rejectionReason;
  final bool isDuplicate;

  const SmsParseResult({
    required this.isEligible,
    required this.isTransaction,
    this.transaction,
    this.rejectionReason,
    this.isDuplicate = false,
  });

  factory SmsParseResult.rejected(String reason) {
    return SmsParseResult(
      isEligible: false,
      isTransaction: false,
      rejectionReason: reason,
    );
  }

  factory SmsParseResult.nonTransaction(String reason) {
    return SmsParseResult(
      isEligible: true,
      isTransaction: false,
      rejectionReason: reason,
    );
  }

  factory SmsParseResult.success(DetectedSmsTransaction transaction) {
    return SmsParseResult(
      isEligible: true,
      isTransaction: true,
      transaction: transaction,
    );
  }

  factory SmsParseResult.duplicate(String reason) {
    return SmsParseResult(
      isEligible: true,
      isTransaction: true,
      isDuplicate: true,
      rejectionReason: reason,
    );
  }
}
