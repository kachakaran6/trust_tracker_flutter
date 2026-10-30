class MerchantExtractor {
  // Regex for debit recipient / merchant
  static final RegExp _debitMerchantPattern = RegExp(
    r'\b(?:to|at|paid\s+to|transferred\s+to)\s+([A-Za-z0-9.&_/-]+(?:\s+[A-Za-z0-9.&_/-]+)*?)(?=\s*(?:\.|\b(?:on\s+\d{1,2}|via\b|using\b|ref\b|upi\b|utr\b|dated\b|bal\b|avail\b|not\s+done\b|tap\s+http)\b|$))',
    caseSensitive: false,
  );

  // Regex for credit sender / beneficiary
  static final RegExp _creditSourcePattern = RegExp(
    r'\b(?:from\s+beneficiary|from\s+sender|received\s+from|credited\s+by)\s+([A-Za-z0-9.&_/-]+(?:\s+[A-Za-z0-9.&_/-]+)*?)(?=\s*(?:\.|\b(?:utr\b|ref\b|upi\b|via\b|dated\b|bal\b|avail\b|on\s+\d{1,2}|not\s+done\b)\b|$))',
    caseSensitive: false,
  );

  // VPA handles: e.g. user@okaxis, swiggy.pay@icici
  static final RegExp _vpaPattern = RegExp(
    r'\b([a-zA-Z0-9.\-_]{2,30}@[a-zA-Z0-9]{2,15})\b',
    caseSensitive: false,
  );

  // Bank reference numbers (UPI, UTR, IMPS, Txn ID, RRN)
  static final RegExp _refPattern = RegExp(
    r'(?:upi\s*ref(?:\s*no\.?)?|utr(?:\s*ref\.?)?|rrn|imps\s*ref|txn\s*id|ref(?:\s*no\.?)?)\s*[:\s-]*([a-zA-Z0-9]{6,25})',
    caseSensitive: false,
  );

  static String? extractMerchant(String body, {bool? isCredit}) {
    if (body.isEmpty) return null;

    // 1. If credit source pattern matches
    final creditMatch = _creditSourcePattern.firstMatch(body);
    if (creditMatch != null) {
      final raw = creditMatch.group(1);
      if (raw != null) {
        final cleaned = _cleanEntityName(raw);
        if (cleaned.isNotEmpty && !_isBoilerplateWord(cleaned)) {
          return cleaned;
        }
      }
    }

    // 2. Check for VPA handles (e.g. swiggy@icici or user@okaxis)
    final vpaMatch = _vpaPattern.firstMatch(body);
    if (vpaMatch != null) {
      final vpa = vpaMatch.group(1);
      if (vpa != null) {
        final namePart = vpa.split('@')[0].split('.')[0].split('-')[0];
        if (namePart.length >= 3 && !RegExp(r'^\d+$').hasMatch(namePart)) {
          return _cleanEntityName(namePart);
        }
        return vpa;
      }
    }

    // 3. Check for debit counterparty (e.g. "to BAMANIA SUNILKUMAR", "to Indian Railways", "at ZARA")
    final debitMatches = _debitMerchantPattern.allMatches(body);
    for (final match in debitMatches) {
      final raw = match.group(1);
      if (raw != null) {
        final cleaned = _cleanEntityName(raw);
        if (cleaned.isNotEmpty && !_isBoilerplateWord(cleaned)) {
          return cleaned;
        }
      }
    }

    return null;
  }

  static String? extractReferenceNumber(String body) {
    if (body.isEmpty) return null;
    final match = _refPattern.firstMatch(body);
    return match?.group(1)?.trim();
  }

  static String _cleanEntityName(String raw) {
    var s = raw.trim();

    // Strip out common preambles if caught
    s = s.replaceAll(RegExp(r'^(?:beneficiary|sender|user)\s+', caseSensitive: false), '').trim();

    // Remove stop words attached at end
    final stopWords = RegExp(r'\s+(?:on|via|ref|upi|utr|bal|dated|using|not done)$', caseSensitive: false);
    while (stopWords.hasMatch(s)) {
      s = s.replaceAll(stopWords, '').trim();
    }

    // Remove leading/trailing punctuation
    s = s.replaceAll(RegExp(r'^[\s.,:;/-]+|[\s.,:;/-]+$'), '').trim();

    return s;
  }

  static bool _isBoilerplateWord(String word) {
    final lower = word.toLowerCase().trim();
    const boilerplate = {
      'your account', 'your a/c', 'account', 'bank', 'upi', 'branch',
      'card', 'atm', 'pos', 'imps', 'neft', 'rtgs', 'transfer', 'inr', 'rs',
      'beneficiary', 'sender', 'someone', 'merchant', 'user'
    };
    if (boilerplate.contains(lower)) return true;
    if (lower.contains('your account') || lower.contains('your a/c')) return true;
    if (lower.contains('bank a/c') || lower.contains('bank acct')) return true;
    if (RegExp(r'^(?:kotak|hdfc|sbi|icici|axis)\s+bank', caseSensitive: false).hasMatch(lower)) return true;
    return false;
  }
}
