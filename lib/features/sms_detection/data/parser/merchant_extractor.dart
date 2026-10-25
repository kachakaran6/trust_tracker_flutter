class MerchantExtractor {
  // Regex to extract merchant name after prepositions (non-greedy, 1-3 words, stopping before prepositions/dates)
  static final RegExp _merchantPattern = RegExp(
    r'(?:at|to|info:?|vpa|paid to|transfer(?:red)? to)\s+([A-Za-z0-9.&_-]+(?:\s+(?!on\b|via\b|ref\b|upi\b|using\b|dated\b|bal\b)[A-Za-z0-9.&_-]+){0,2})',
    caseSensitive: false,
  );

  static final RegExp _vpaPattern = RegExp(
    r'\b([a-zA-Z0-9.\-_]{2,30}@[a-zA-Z0-9]{2,15})\b',
    caseSensitive: false,
  );

  static final RegExp _refPattern = RegExp(
    r'(?:upi\s*ref(?:\s*no\.?)?|ref(?:\s*no\.?)?|txn\s*id|utr|rrn|imps\s*ref)\s*[:\s-]*([a-zA-Z0-9]{6,22})',
    caseSensitive: false,
  );

  static String? extractMerchant(String body) {
    if (body.isEmpty) return null;

    // First try to check VPA handles (e.g. swiggy@icici or merchant@okaxis)
    final vpaMatch = _vpaPattern.firstMatch(body);
    if (vpaMatch != null) {
      final vpa = vpaMatch.group(1);
      if (vpa != null) {
        // If VPA contains readable name like swiggy.pay@icici, return Swiggy
        final namePart = vpa.split('@')[0].split('.')[0].split('-')[0];
        if (namePart.length >= 3 && !RegExp(r'^\d+$').hasMatch(namePart)) {
          return _cleanMerchantName(namePart);
        }
        return vpa;
      }
    }

    // Try finding preposition-based merchant: "at SWIGGY on" or "to Amazon via"
    final match = _merchantPattern.firstMatch(body);
    if (match != null) {
      final raw = match.group(1);
      if (raw != null) {
        final cleaned = _cleanMerchantName(raw);
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

  static String _cleanMerchantName(String raw) {
    var s = raw.trim();

    // Remove stop words that might be attached at the end
    final stopWords = RegExp(r'\s+(?:on|via|ref|upi|bal|dated|using)$', caseSensitive: false);
    while (stopWords.hasMatch(s)) {
      s = s.replaceAll(stopWords, '').trim();
    }

    // Remove leading/trailing punctuation
    s = s.replaceAll(RegExp(r'^[\s.,:;/-]+|[\s.,:;/-]+$'), '');

    if (s.isEmpty) return s;

    // Capitalize words nicely
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.length <= 4 && word == word.toUpperCase()) return word; // Keep acronyms like PVR, KFC, ZARA
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static bool _isBoilerplateWord(String word) {
    final lower = word.toLowerCase().trim();
    const boilerplate = {
      'your account', 'your a/c', 'account', 'bank', 'upi', 'branch',
      'card', 'atm', 'pos', 'imps', 'neft', 'rtgs', 'transfer', 'inr', 'rs'
    };
    return boilerplate.contains(lower);
  }
}
