class SmsClassifier {
  // Regex patterns for non-transaction messages
  static final RegExp _otpPattern = RegExp(
    r'\b(otp|one\s*time\s*pass(word)?|verification\s*code|security\s*code|auth(entication)?\s*code|pin)\b',
    caseSensitive: false,
  );

  static final RegExp _otpActionPattern = RegExp(
    r'(is\s+your\s+(?:one\s*time\s*pass(word)?|otp)|use\s+otp|do\s+not\s+share|never\s+share|valid\s+for|secret\s*otp)',
    caseSensitive: false,
  );

  static final RegExp _promotionalPattern = RegExp(
    r'\b(pre-?approved|apply\s+now|offer\s+valid|cashback\s+offer|discount\s+coupon|use\s+code|win\s+upto|zero\s+balance\s+account|flat\s+\d+%\s+off|special\s+loan\s+offer|click\s+here\s+to\s+apply)\b',
    caseSensitive: false,
  );

  static final RegExp _limitNotificationPattern = RegExp(
    r'\b(credit\s+limit\s+(has\s+been\s+)?(increased|updated|enhanced)|available\s+limit\s+is\s+inr|your\s+credit\s+limit\s+is)\b',
    caseSensitive: false,
  );

  static final RegExp _failedPattern = RegExp(
    r'\b(declined|unsuccessful|failed|cancelled|could\s+not\s+be\s+processed|transaction\s+failed|payment\s+failed|payment\s+declined)\b',
    caseSensitive: false,
  );

  static final RegExp _pendingPattern = RegExp(
    r'\b(is\s+pending|in\s+process|processing\s+your\s+request|will\s+be\s+credited\s+within|payment\s+request\s+submitted)\b',
    caseSensitive: false,
  );

  static final RegExp _balanceKeywords = RegExp(
    r'\b(balance|bal|avl\s*bal|available\s+bal|a\/c\s*bal)\b',
    caseSensitive: false,
  );

  static final RegExp _transactionVerbs = RegExp(
    r'\b(debited|credited|sent|spent|withdrawn|transferred|paid|purchase|received|deposited|refund|reversal)\b',
    caseSensitive: false,
  );

  // Check if message is a genuine transaction SMS or a non-transaction alert
  static ClassificationResult classify(String body, String sender) {
    final cleanBody = body.trim();
    if (cleanBody.isEmpty) {
      return const ClassificationResult(
        isEligible: false,
        rejectionReason: 'Empty SMS message',
      );
    }

    // 1. Check for OTP messages
    if (_otpPattern.hasMatch(cleanBody) && _otpActionPattern.hasMatch(cleanBody)) {
      return const ClassificationResult(
        isEligible: false,
        isNonTransaction: true,
        rejectionReason: 'Authentication/OTP message',
      );
    }

    // 2. Check for Promotional messages
    if (_promotionalPattern.hasMatch(cleanBody) && !_transactionVerbs.hasMatch(cleanBody)) {
      return const ClassificationResult(
        isEligible: false,
        isNonTransaction: true,
        rejectionReason: 'Promotional message',
      );
    }

    // 3. Check for Credit Card Limit updates
    if (_limitNotificationPattern.hasMatch(cleanBody) && !_transactionVerbs.hasMatch(cleanBody)) {
      return const ClassificationResult(
        isEligible: false,
        isNonTransaction: true,
        rejectionReason: 'Credit card limit update notification',
      );
    }

    // 4. Check for Pending payments (not completed)
    if (_pendingPattern.hasMatch(cleanBody) &&
        !cleanBody.toLowerCase().contains('debited from') &&
        !cleanBody.toLowerCase().contains('has been credited') &&
        !cleanBody.toLowerCase().contains('is credited') &&
        !cleanBody.toLowerCase().contains('sent rs')) {
      return const ClassificationResult(
        isEligible: false,
        isNonTransaction: true,
        rejectionReason: 'Pending/unsettled transaction',
      );
    }

    // 5. Check for Failed/Declined payments
    if (_failedPattern.hasMatch(cleanBody)) {
      return const ClassificationResult(
        isEligible: false,
        isNonTransaction: true,
        rejectionReason: 'Failed/declined transaction',
      );
    }

    // 6. Check for Balance-only alerts (no debit/credit/sent)
    if (_balanceKeywords.hasMatch(cleanBody) && !_transactionVerbs.hasMatch(cleanBody)) {
      return const ClassificationResult(
        isEligible: false,
        isNonTransaction: true,
        rejectionReason: 'Balance inquiry/balance-only notification',
      );
    }

    return const ClassificationResult(
      isEligible: true,
      isNonTransaction: false,
    );
  }
}

class ClassificationResult {
  final bool isEligible;
  final bool isNonTransaction;
  final String? rejectionReason;

  const ClassificationResult({
    required this.isEligible,
    this.isNonTransaction = false,
    this.rejectionReason,
  });
}
