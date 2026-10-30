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
    r'\b(credited\s*(with|to|by)?|deposited|received|added\s+to|refund(ed)?(\s+of)?|revers(ed|al)(\s+of)?|cashback\s+received|cr\.?)\b',
    caseSensitive: false,
  );

  // Regex to detect explicit debit phrases
  // NOTE: Includes "sent" in patterns like "Sent Rs.10.00 from Kotak Bank..."
  static final RegExp _debitDirectPatterns = RegExp(
    r'\b(sent\b|debited\s*(from|by|for|with)?|spent|paid\s*(to|via|for)?|withdrawn|purchase\s*(of|at)?|card\s*purchase|deducted\s*from|transferred\s*to|dr\.?)\b',
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

    // 1. Check for refunds or reversals first
    if (_refundPattern.hasMatch(lower) || _reversalPattern.hasMatch(lower)) {
      if (lower.contains('credit') ||
          lower.contains('refund') ||
          lower.contains('reversed') ||
          lower.contains('reversal') ||
          lower.contains('received') ||
          lower.contains('back to your')) {
        return const DirectionResult(
          type: TransactionType.income,
          category: SmsTransactionCategory.refund,
          confidence: 0.95,
        );
      }
    }

    final hasDebit = _debitDirectPatterns.hasMatch(lower);
    final hasCredit = _creditDirectPatterns.hasMatch(lower);

    // 2. Clear debit without credit
    if (hasDebit && !hasCredit) {
      return const DirectionResult(
        type: TransactionType.expense,
        category: SmsTransactionCategory.debit,
        confidence: 0.98,
      );
    }

    // 3. Clear credit without debit
    if (hasCredit && !hasDebit) {
      return const DirectionResult(
        type: TransactionType.income,
        category: SmsTransactionCategory.credit,
        confidence: 0.98,
      );
    }

    // 4. Both match: Resolve contextual ambiguity
    if (hasDebit && hasCredit) {
      // Case A: "debited ... has been reversed / refunded" -> Income
      if (lower.contains('debited') &&
          (lower.contains('reversed') || lower.contains('refunded') || lower.contains('reversal'))) {
        return const DirectionResult(
          type: TransactionType.income,
          category: SmsTransactionCategory.reversal,
          confidence: 0.92,
        );
      }

      // Case B: "request received ... debited from your a/c" -> Expense
      if (lower.contains('received') && (lower.contains('debited') || lower.contains('sent'))) {
        final debitedIndex = lower.indexOf('debited');
        final receivedIndex = lower.indexOf('received');
        if (lower.contains('request received') ||
            lower.contains('mandate received') ||
            debitedIndex > receivedIndex ||
            lower.contains('sent rs')) {
          return const DirectionResult(
            type: TransactionType.expense,
            category: SmsTransactionCategory.debit,
            confidence: 0.90,
          );
        }
      }

      // Case C: "credited ... for earlier debit" -> Income
      if (lower.contains('credited') && lower.contains('debit')) {
        return const DirectionResult(
          type: TransactionType.income,
          category: SmsTransactionCategory.credit,
          confidence: 0.90,
        );
      }

      // Case D: "Sent Rs.X from ... credited to" (e.g. sender alert) -> Expense
      if (lower.startsWith('sent') || lower.contains('sent rs') || lower.contains('sent inr')) {
        return const DirectionResult(
          type: TransactionType.expense,
          category: SmsTransactionCategory.debit,
          confidence: 0.92,
        );
      }

      // Default to debit if "debited from" or "spent" appears
      if (lower.contains('debited from') || lower.contains('card purchase') || lower.contains('spent')) {
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
