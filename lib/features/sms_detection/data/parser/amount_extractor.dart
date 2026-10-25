class AmountExtractor {
  // Regex for extracting currency symbol/code and amount
  // Matches: INR 450.00, Rs. 250, Rs 1,200.50, ₹450, 450.00 INR, 250/-
  static final RegExp _currencyAmountPattern = RegExp(
    r'(?:(?:inr|rs\.?|₹)\s*([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)|([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:inr|rs\.?|₹|/-))',
    caseSensitive: false,
  );

  // Patterns for balance/limit clauses to ignore
  static final RegExp _balanceClausePattern = RegExp(
    r'(?:avail(?:able)?\s*bal(?:ance)?|avl\s*bal|total\s*bal(?:ance)?|bal|a\/c\s*bal)\s*(?:is|:)?\s*(?:inr|rs\.?|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _limitClausePattern = RegExp(
    r'(?:credit\s*limit|available\s*limit|limit)\s*(?:is|:)?\s*(?:inr|rs\.?|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static AmountResult? extract(String body) {
    if (body.isEmpty) return null;

    // 1. Identify balance values to exclude
    final balanceMatches = _balanceClausePattern.allMatches(body);
    final Set<String> balanceStrings = {};
    for (final m in balanceMatches) {
      if (m.group(1) != null) {
        balanceStrings.add(m.group(1)!.replaceAll(',', ''));
      }
    }

    // 2. Identify limit values to exclude
    final limitMatches = _limitClausePattern.allMatches(body);
    final Set<String> limitStrings = {};
    for (final m in limitMatches) {
      if (m.group(1) != null) {
        limitStrings.add(m.group(1)!.replaceAll(',', ''));
      }
    }

    // Remove the balance and limit substrings to avoid accidental extraction
    String scrubbed = body;
    scrubbed = scrubbed.replaceAll(_balanceClausePattern, ' [BAL_OMITTED] ');
    scrubbed = scrubbed.replaceAll(_limitClausePattern, ' [LIMIT_OMITTED] ');

    // 3. Find amounts in the scrubbed text
    final matches = _currencyAmountPattern.allMatches(scrubbed);
    for (final match in matches) {
      final rawAmountStr = match.group(1) ?? match.group(2);
      if (rawAmountStr == null) continue;

      final normalized = rawAmountStr.replaceAll(',', '').trim();
      final parsed = double.tryParse(normalized);
      if (parsed == null || parsed <= 0) continue;

      // Ensure this amount is not one of the excluded balances/limits
      if (balanceStrings.contains(normalized) || limitStrings.contains(normalized)) {
        continue;
      }

      // Check currency symbol
      String currency = 'INR';
      final fullMatchStr = match.group(0)?.toUpperCase() ?? '';
      if (fullMatchStr.contains('USD') || fullMatchStr.contains('\$')) {
        currency = 'USD';
      } else if (fullMatchStr.contains('EUR') || fullMatchStr.contains('€')) {
        currency = 'EUR';
      } else if (fullMatchStr.contains('GBP') || fullMatchStr.contains('£')) {
        currency = 'GBP';
      }

      return AmountResult(
        amount: parsed,
        currency: currency,
        rawMatch: match.group(0) ?? '',
      );
    }

    return null;
  }
}

class AmountResult {
  final double amount;
  final String currency;
  final String rawMatch;

  const AmountResult({
    required this.amount,
    required this.currency,
    required this.rawMatch,
  });
}
