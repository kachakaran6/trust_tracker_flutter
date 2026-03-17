import 'package:trust_tracker_flutter/core/utils/extensions.dart';

class ExportTransactionRow {
  const ExportTransactionRow({
    required this.timestamp,
    required this.title,
    required this.category,
    required this.typeLabel,
    required this.notes,
    required this.amount,
    required this.isIncome,
  });

  final DateTime timestamp;
  final String title;
  final String category;
  final String typeLabel;
  final String notes;
  final double amount;
  final bool isIncome;

  String get timestampLabel => timestamp.toTimestamp();
  double get signedAmount => isIncome ? amount : -amount;
}
