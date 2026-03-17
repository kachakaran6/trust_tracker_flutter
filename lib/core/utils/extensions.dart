import 'package:intl/intl.dart';

extension CurrencyFormat on double {
  String toCurrency(String currencyCode) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: _getSymbol(currencyCode),
      decimalDigits: 2,
    );
    return formatter.format(this);
  }

  String toCurrencyCompact(String currencyCode) {
    if (this >= 1000000) {
      return '${_getSymbol(currencyCode)}${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${_getSymbol(currencyCode)}${(this / 1000).toStringAsFixed(1)}K';
    }
    return toCurrency(currencyCode);
  }

  static String _getSymbol(String code) {
    try {
      return NumberFormat.simpleCurrency(name: code).currencySymbol;
    } catch (_) {
      return code;
    }
  }
}

extension DateFormatExt on DateTime {
  String toMonthYear() => DateFormat('MMMM yyyy').format(this);
  String toMonthKey() => DateFormat('yyyy-MM').format(this);
  String toDisplayShort() => DateFormat('MMM d, yyyy').format(this);
  String toDisplayFull() => DateFormat('EEEE, MMMM d, yyyy').format(this);
  String toTimestamp() => DateFormat('dd MMM yyyy - hh:mm a').format(this);
  String toTimeOnly() => DateFormat('hh:mm a').format(this);
  bool isSameMonth(DateTime other) =>
      year == other.year && month == other.month;
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

extension StringColorToHex on String {
  int toColorInt() {
    final hex = replaceAll('#', '');
    return int.parse('FF$hex', radix: 16);
  }
}
