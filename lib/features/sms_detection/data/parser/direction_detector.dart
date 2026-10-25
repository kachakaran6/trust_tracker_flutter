import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

enum SmsTransactionCategory {
  debit,
  credit,
  refund,
  reversal,
  unknown,
}

class DirectionDetector {
  // Regex to detect explicit credit phrases
  static final RegExp _creditDirectPatterns = RegExp(
    r'\b(credited\s*(with|to|by)?|deposited|received|added\s+to|refund(ed)?(\s+of)?|revers(ed|al)(\s+of)?|cashback\s+received)\b',
    caseSensitive: false,
  );

  // Regex to detect explicit debit phrases
  static final RegExp _debitDirectPatterns = RegExp(
    r'\b(debited\s*(from|by|for)?|spent|paid\s*(to|via|for)?|withdrawn|purchase\s*(of|at)?|card\s*purchase|deducted\s*from|sent\s*to)\b',
    caseSensitive: false,
  );

  // Reversal or Refund patterns
  static final RegExp _refundPattern = RegExp(
    r'\b(refund(ed)?|cashback)\b',
    caseSensitive: false,
  );

  static final RegExp _reversalPattern = RegExp(
    r'\b(revers(ed|al))\b',
    caseSensitive: false,
  );

  static DirectionResult detect(String body) {
    final lower = body.toLowerCase();

    // Check for refunds first: "refund of INR 450 has been processed/credited"
    if (_refundPattern.hasMatch(lower) || _reversalPattern.hasMatch(lower)) {
      // If it says "refund of Rs X credited" or "reversed to your account" -> credit
      if (lower.contains('credit') ||
          lower.contains('refund') ||
          lower.contains('reversed') ||
          lower.contains('received') ||
          lower.contains('back to your')) {
        return const DirectionResult(
          type: TransactionType.income,
          category: SmsTransactionCategory.refund,
          confidence: 0.95,
        );
      }
    }

    // Safeguard 1: "Request received for Rs 500 debited from a/c" -> Debit wins!
    // If it has both "received" and "debited", check context.
    final hasDebit = _debitDirectPatterns.hasMatch(lower);
    final hasCredit = _creditDirectPatterns.hasMatch(lower);

    if (hasDebit && !hasCredit) {
      return const DirectionResult(
        type: TransactionType.expense,
        category: SmsTransactionCategory.debit,
        confidence: 0.98,
      );
    }

    if (hasCredit && !hasDebit) {
      return const DirectionResult(
        type: TransactionType.income,
        category: SmsTransactionCategory.credit,
        confidence: 0.98,
      );
    }

    if (hasDebit && hasCredit) {
      // Both match, resolve with strict context analysis:
      // Case A: "debited ... has been reversed / refunded" -> Income
      if (lower.contains('debited') &&
          (lower.contains('reversed') || lower.contains('refunded'))) {
        return const DirectionResult(
          type: TransactionType.income,
          category: SmsTransactionCategory.reversal,
          confidence: 0.90,
        );
      }

      // Case B: "request received ... debited from your a/c" -> Expense
      if (lower.contains('received') && lower.contains('debited')) {
        final debitedIndex = lower.indexOf('debited');
        final receivedIndex = lower.indexOf('received');
        if (lower.contains('request received') || lower.contains('mandate received') || debitedIndex > receivedIndex) {
          return const DirectionResult(
            type: TransactionType.expense,
            category: SmsTransactionCategory.debit,
            confidence: 0.88,
          );
        }
      }

      // Case C: "credited ... for earlier debit" -> Income
      if (lower.contains('credited') && lower.contains('debit')) {
        return const DirectionResult(
          type: TransactionType.income,
          category: SmsTransactionCategory.credit,
          confidence: 0.88,
        );
      }

      // Default to debit if "debited from" appears
      if (lower.contains('debited from') || lower.contains('card purchase')) {
        return const DirectionResult(
          type: TransactionType.expense,
          category: SmsTransactionCategory.debit,
          confidence: 0.85,
        );
      }

      return const DirectionResult(
        type: TransactionType.expense,
        category: SmsTransactionCategory.unknown,
        confidence: 0.50,
      );
    }

    // No clear direction found
    return const DirectionResult(
      type: TransactionType.expense,
      category: SmsTransactionCategory.unknown,
      confidence: 0.0,
    );
  }
}

class DirectionResult {
  final TransactionType type;
  final SmsTransactionCategory category;
  final double confidence;

  const DirectionResult({
    required this.type,
    required this.category,
    required this.confidence,
  });
}
