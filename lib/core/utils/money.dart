import 'package:intl/intl.dart';

/// Exact financial representation using integer paise (1 Rupee = 100 paise).
/// Avoids IEEE 754 binary floating-point representation and rounding issues.
class Money implements Comparable<Money> {
  final int paise;
  final String currency;

  const Money.fromPaise(this.paise, {this.currency = 'INR'});

  /// Construct from double/num rupees by safely converting to exact paise.
  factory Money.fromRupees(num rupees, {String currency = 'INR'}) {
    // Avoid float precision drift by rounding to nearest integer paise
    final p = (rupees * 100.0).round();
    return Money.fromPaise(p, currency: currency);
  }

  /// Parse string representations such as:
  /// - "Rs.10.00", "Rs 10", "INR 35931", "₹1,250.50", "53.35", "INR 1,25,000.00"
  static Money? tryParse(String? raw, {String defaultCurrency = 'INR'}) {
    if (raw == null || raw.trim().isEmpty) return null;

    var s = raw.trim();

    // Detect currency if explicitly present
    String currency = defaultCurrency;
    final upper = s.toUpperCase();
    if (upper.contains('USD') || upper.contains('\$')) {
      currency = 'USD';
    } else if (upper.contains('EUR') || upper.contains('€')) {
      currency = 'EUR';
    } else if (upper.contains('GBP') || upper.contains('£')) {
      currency = 'GBP';
    } else if (upper.contains('INR') || upper.contains('RS') || upper.contains('₹')) {
      currency = 'INR';
    }

    // Strip currency symbols, codes, slashes, whitespace
    s = s.replaceAll(RegExp(r'(?:inr|rs\.?|₹|\$|€|£|/-)', caseSensitive: false), '');
    s = s.replaceAll(',', '').trim();

    if (s.isEmpty) return null;

    final parts = s.split('.');
    if (parts.length > 2) return null;

    final intPartStr = parts[0].replaceAll(RegExp(r'[^\d-]'), '');
    if (intPartStr.isEmpty && parts.length == 1) return null;

    final intPart = int.tryParse(intPartStr.isEmpty ? '0' : intPartStr);
    if (intPart == null) return null;

    int paisePart = 0;
    if (parts.length == 2) {
      var decStr = parts[1].replaceAll(RegExp(r'[^\d]'), '');
      if (decStr.length > 2) {
        decStr = decStr.substring(0, 2);
      } else if (decStr.length == 1) {
        decStr = '${decStr}0';
      }
      paisePart = int.tryParse(decStr) ?? 0;
    }

    final isNegative = intPart < 0 || parts[0].startsWith('-');
    final totalPaise = isNegative
        ? -((intPart.abs() * 100) + paisePart)
        : (intPart * 100) + paisePart;

    return Money.fromPaise(totalPaise, currency: currency);
  }

  static Money zero([String currency = 'INR']) => Money.fromPaise(0, currency: currency);

  double toRupeesDouble() => paise / 100.0;

  bool get isZero => paise == 0;
  bool get isPositive => paise > 0;
  bool get isNegative => paise < 0;

  Money operator +(Money other) {
    assert(currency == other.currency, 'Cannot add different currencies ($currency != ${other.currency})');
    return Money.fromPaise(paise + other.paise, currency: currency);
  }

  Money operator -(Money other) {
    assert(currency == other.currency, 'Cannot subtract different currencies ($currency != ${other.currency})');
    return Money.fromPaise(paise - other.paise, currency: currency);
  }

  Money operator -() => Money.fromPaise(-paise, currency: currency);

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money && runtimeType == other.runtimeType && paise == other.paise && currency == other.currency;

  @override
  int get hashCode => paise.hashCode ^ currency.hashCode;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  /// Formats according to the Indian grouping system (lakhs & crores) with exact paise.
  /// Example: 1000 paise -> ₹10.00
  /// Example: 5335 paise -> ₹53.35
  /// Example: 3593100 paise -> ₹35,931.00
  /// Example: 12500050 paise -> ₹1,25,000.50
  String formatIndian({bool showSymbol = true, bool showSign = false}) {
    final absPaise = paise.abs();
    final rupees = absPaise ~/ 100;
    final dec = absPaise % 100;
    final decStr = '.${dec.toString().padLeft(2, '0')}';

    final groupedRupees = _formatIndianGrouping(rupees);
    final signStr = showSign ? (paise < 0 ? '−' : '+') : (paise < 0 ? '−' : '');

    final symbol = _getSymbol(currency);
    if (showSymbol) {
      return '$signStr$symbol$groupedRupees$decStr';
    } else {
      return '$signStr$currency $groupedRupees$decStr';
    }
  }

  static String _formatIndianGrouping(int rupees) {
    final s = rupees.toString();
    if (s.length <= 3) return s;

    final lastThree = s.substring(s.length - 3);
    final remaining = s.substring(0, s.length - 3);

    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      buffer.write(remaining[i]);
      final distFromEnd = remaining.length - 1 - i;
      if (distFromEnd > 0 && distFromEnd % 2 == 0) {
        buffer.write(',');
      }
    }
    buffer.write(',');
    buffer.write(lastThree);
    return buffer.toString();
  }

  static String _getSymbol(String code) {
    switch (code.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$code ';
    }
  }

  @override
  String toString() => formatIndian();
}

