class AccountMasker {
  static final RegExp _accountPattern = RegExp(
    r'(?:a\/c|acct|account|card)\s*(?:no\.?|number)?\s*(?:ending\s*(?:with|in)?\s*)?([xX*•\.]*\d{3,18})',
    caseSensitive: false,
  );

  static final RegExp _vpaPattern = RegExp(
    r'\b([a-zA-Z0-9.\-_]{2,25}@[a-zA-Z0-9]{2,15})\b',
    caseSensitive: false,
  );

  static String? extractMaskedAccount(String body) {
    if (body.isEmpty) return null;

    final match = _accountPattern.firstMatch(body);
    if (match != null) {
      final rawNum = match.group(1);
      if (rawNum != null && rawNum.isNotEmpty) {
        final digits = rawNum.replaceAll(RegExp(r'\D'), '');
        if (digits.length >= 4) {
          final last4 = digits.substring(digits.length - 4);
          return '••$last4';
        } else if (digits.isNotEmpty) {
          return '••$digits';
        }
        return '••${rawNum.substring(rawNum.length - 4)}';
      }
    }

    final vpaMatch = _vpaPattern.firstMatch(body);
    if (vpaMatch != null) {
      final vpa = vpaMatch.group(1);
      if (vpa != null) {
        final parts = vpa.split('@');
        if (parts.length == 2 && parts[0].length > 3) {
          final prefix = parts[0].substring(0, 2);
          return '$prefix•••@${parts[1]}';
        }
        return vpa;
      }
    }

    return null;
  }
}
