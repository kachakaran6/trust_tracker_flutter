import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/repositories/sms_transaction_repository.dart';

class SmsDeduplicationService {
  final SmsTransactionRepository _repository;

  SmsDeduplicationService(this._repository);

  Future<bool> isDuplicate(DetectedSmsTransaction transaction) async {
    // 1. Check by reference number if available
    if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty) {
      final isRefDuplicate = await _repository.isReferenceProcessed(transaction.referenceNumber!);
      if (isRefDuplicate) return true;
    }

    // 2. Check by composite fingerprint
    final isFingerprintDuplicate = await _repository.isDuplicate(transaction.smsFingerprint);
    if (isFingerprintDuplicate) return true;

    return false;
  }
}
