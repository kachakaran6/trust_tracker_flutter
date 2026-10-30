import 'package:trust_tracker_flutter/core/utils/money.dart';

class AmountResult {
  final Money money;
  final String currency;
  final String rawMatch;
  final double confidence;
  final bool isAmbiguous;
  final String? warning;

  double get amount => money.toRupeesDouble();
  int get paise => money.paise;

  const AmountResult({
    required this.money,
    required this.currency,
    required this.rawMatch,
    this.confidence = 0.95,
    this.isAmbiguous = false,
    this.warning,
  });
}

class AmountExtractor {
  // Matches currency symbol/code followed by an amount (with boundary to prevent partial matches)
  // Group 1: Currency prefix
  // Group 2: Amount with commas: 1,25,000.00 or 35,931
  // Group 3: Amount without commas: 35931 or 10.00 or 53.35
  static final RegExp _prefixedAmountPattern = RegExp(
    r'(?:^|[^\w])(inr|rs\.?|₹)\s*(?:[:\s-]*)\s*([0-9]{1,3}(?:,[0-9]{2,3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)(?!\d)',
    caseSensitive: false,
  );

  // Matches amount followed by currency symbol/code or slash-hyphen
  // Group 1: Amount with commas
  // Group 2: Amount without commas
  // Group 3: Currency suffix
  static final RegExp _suffixedAmountPattern = RegExp(
    r'(?:^|[^\w])([0-9]{1,3}(?:,[0-9]{2,3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:[:\s-]*)\s*(inr|rs\.?|₹|/-)(?!\w)',
    caseSensitive: false,
  );

  // Fallback pattern for action verb followed by amount without currency prefix
  // e.g. "debited with 500.00", "credited 2500", "sent 50.00"
  static final RegExp _actionVerbAmountPattern = RegExp(
    r'\b(debited(?:\s+(?:by|with|for))?|credited(?:\s+(?:with|by))?|spent|paid|withdrawn|sent|purchase\s+of|refund\s+of|reversal\s+of)\s+([0-9]{1,3}(?:,[0-9]{2,3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)(?!\d)',
    caseSensitive: false,
  );

  // Balance and limit clause patterns to scrub out
  static final RegExp _balanceClausePattern = RegExp(
    r'(?:avail(?:able)?\s*bal(?:ance)?|avl\s*bal|total\s*bal(?:ance)?|bal|a\/c\s*bal|net\s*bal(?:ance)?)\s*(?:is|:)?\s*(?:inr|rs\.?|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _limitClausePattern = RegExp(
    r'(?:credit\s*limit|available\s*limit|avail\s*limit|total\s*limit|limit)\s*(?:is|:)?\s*(?:inr|rs\.?|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  // Reference numbers to exclude
  static final RegExp _refNumberPattern = RegExp(
    r'(?:upi\s*ref(?:\s*no\.?)?|ref(?:\s*no\.?)?|txn\s*id|utr(?:\s*ref\.?)?|rrn|imps\s*ref)\s*[:\s-]*([a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  // Account numbers to exclude
  static final RegExp _accountPattern = RegExp(
    r'(?:a\/c|acct|account|card)\s*(?:no\.?|number)?\s*(?:ending\s*(?:with|in)?\s*)?([xX*•]*\d{3,18})',
    caseSensitive: false,
  );

  // Date pattern to exclude
  static final RegExp _datePattern = RegExp(
    r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b',
  );

  // Phone numbers or helpline
  static final RegExp _helplinePattern = RegExp(
    r'\b(?:\+91[\s-]?)?[6-9]\d{9}\b|1800\s*\d{3}\s*\d{4}',
  );

  static AmountResult? extract(String body) {
    if (body.trim().isEmpty) return null;

    final originalBody = body.trim();

    // 1. Gather all excluded numbers (balance, limits, reference numbers, accounts)
    final Set<String> excludedStrings = {};

    for (final m in _balanceClausePattern.allMatches(originalBody)) {
      if (m.group(1) != null) excludedStrings.add(m.group(1)!.replaceAll(',', ''));
    }
    for (final m in _limitClausePattern.allMatches(originalBody)) {
      if (m.group(1) != null) excludedStrings.add(m.group(1)!.replaceAll(',', ''));
    }
    for (final m in _refNumberPattern.allMatches(originalBody)) {
      if (m.group(1) != null) excludedStrings.add(m.group(1)!.replaceAll(',', ''));
    }
    for (final m in _accountPattern.allMatches(originalBody)) {
      if (m.group(1) != null) {
        final digits = m.group(1)!.replaceAll(RegExp(r'\D'), '');
        if (digits.isNotEmpty) excludedStrings.add(digits);
      }
    }

    // 2. Scrub balance and limit clauses so they don't get matched as transactions
    String scrubbed = originalBody;
    scrubbed = scrubbed.replaceAll(_balanceClausePattern, ' [BAL_OMITTED] ');
    scrubbed = scrubbed.replaceAll(_limitClausePattern, ' [LIMIT_OMITTED] ');

    final List<_AmountCandidate> candidates = [];

    // 3. Extract prefixed amounts (e.g. "Rs.10.00", "Rs.35931", "INR 2,500.00")
    for (final match in _prefixedAmountPattern.allMatches(scrubbed)) {
      final cur = match.group(1) ?? 'INR';
      final valStr = match.group(2);
      if (valStr == null) continue;

      final normalized = valStr.replaceAll(',', '').trim();
      if (excludedStrings.contains(normalized)) continue;

      final money = Money.tryParse(valStr, defaultCurrency: _normalizeCurrency(cur));
      if (money == null || !money.isPositive) continue;

      // Score context: check proximity to action verbs
      final score = _scoreCandidateContext(
        fullText: originalBody,
        matchIndex: match.start,
        matchLength: match.end - match.start,
      );

      candidates.add(_AmountCandidate(
        money: money,
        rawMatch: match.group(0)!.trim(),
        score: score,
        isPrefixed: true,
      ));
    }

    // 4. Extract suffixed amounts (e.g. "53.35 INR", "250/-")
    for (final match in _suffixedAmountPattern.allMatches(scrubbed)) {
      final valStr = match.group(1);
      final cur = match.group(2) ?? 'INR';
      if (valStr == null) continue;

      final normalized = valStr.replaceAll(',', '').trim();
      if (excludedStrings.contains(normalized)) continue;

      final money = Money.tryParse(valStr, defaultCurrency: _normalizeCurrency(cur));
      if (money == null || !money.isPositive) continue;

      final score = _scoreCandidateContext(
        fullText: originalBody,
        matchIndex: match.start,
        matchLength: match.end - match.start,
      );

      candidates.add(_AmountCandidate(
        money: money,
        rawMatch: match.group(0)!.trim(),
        score: score,
        isPrefixed: false,
      ));
    }

    // 5. Fallback for verb-preceded amounts without explicit symbol (e.g. "debited with 500.00")
    if (candidates.isEmpty) {
      for (final match in _actionVerbAmountPattern.allMatches(scrubbed)) {
        final valStr = match.group(2);
        if (valStr == null) continue;

        final normalized = valStr.replaceAll(',', '').trim();
        if (excludedStrings.contains(normalized)) continue;

        final money = Money.tryParse(valStr);
        if (money == null || !money.isPositive) continue;

        candidates.add(_AmountCandidate(
          money: money,
          rawMatch: match.group(0)!.trim(),
          score: 80,
          isPrefixed: false,
        ));
      }
    }

    if (candidates.isEmpty) return null;

    // Sort by context score descending
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final best = candidates.first;

    // Check if there is ambiguity: multiple differing positive candidates with high similar scores
    bool isAmbiguous = false;
    String? warning;

    if (candidates.length > 1) {
      final distinctAmounts = candidates.map((c) => c.money.paise).toSet();
      if (distinctAmounts.length > 1) {
        final second = candidates[1];
        if ((best.score - second.score).abs() < 15) {
          isAmbiguous = true;
          warning = 'Multiple transaction amounts detected in SMS. Please verify.';
        }
      }
    }

    final confidence = isAmbiguous
        ? 0.50
        : (best.score >= 70 ? 0.98 : (best.score >= 40 ? 0.85 : 0.65));

    return AmountResult(
      money: best.money,
      currency: best.money.currency,
      rawMatch: best.rawMatch,
      confidence: confidence,
      isAmbiguous: isAmbiguous,
      warning: warning,
    );
  }

  static int _scoreCandidateContext({
    required String fullText,
    required int matchIndex,
    required int matchLength,
  }) {
    int score = 40; // Base score for having currency marker

    // Extract window of text around the match (-30 to +30 chars)
    final startWindow = matchIndex >= 35 ? matchIndex - 35 : 0;
    final endWindow = (matchIndex + matchLength + 35) <= fullText.length
        ? matchIndex + matchLength + 35
        : fullText.length;
    final contextSnippet = fullText.substring(startWindow, endWindow).toLowerCase();

    // High confidence action verbs in proximity
    if (contextSnippet.contains('sent') ||
        contextSnippet.contains('debited') ||
        contextSnippet.contains('credited') ||
        contextSnippet.contains('paid') ||
        contextSnippet.contains('spent') ||
        contextSnippet.contains('purchase') ||
        contextSnippet.contains('transferred') ||
        contextSnippet.contains('withdrawn') ||
        contextSnippet.contains('received')) {
      score += 45;
    }

    // Direct prefix: e.g. "Sent Rs.10.00" or "debited with Rs."
    if (contextSnippet.contains('sent rs') ||
        contextSnippet.contains('sent inr') ||
        contextSnippet.contains('credited to') ||
        contextSnippet.contains('debited by') ||
        contextSnippet.contains('debited with') ||
        contextSnippet.contains('paid rs') ||
        contextSnippet.contains('paid inr')) {
      score += 25;
    }

    return score;
  }

  static String _normalizeCurrency(String cur) {
    final clean = cur.toUpperCase().trim();
    if (clean.contains('INR') || clean.contains('RS') || clean.contains('₹') || clean.contains('/-')) {
      return 'INR';
    }
    if (clean.contains('USD') || clean.contains('\$')) return 'USD';
    if (clean.contains('EUR') || clean.contains('€')) return 'EUR';
    if (clean.contains('GBP') || clean.contains('£')) return 'GBP';
    return 'INR';
  }
}

class _AmountCandidate {
  final Money money;
  final String rawMatch;
  final int score;
  final bool isPrefixed;

  _AmountCandidate({
    required this.money,
    required this.rawMatch,
    required this.score,
    required this.isPrefixed,
  });
}
