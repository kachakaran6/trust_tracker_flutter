import 'package:isar/isar.dart';

part 'transaction_model.g.dart';

enum TransactionType { income, expense }

@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  late double amount;
  late String description;

  /// The user-selected transaction date+time (full timestamp).
  /// e.g. DateTime(2026, 3, 8, 14, 30) for March 8 2026 at 2:30 PM
  late DateTime date;

  @enumerated
  late TransactionType type;

  int? categoryId;
  String? note;

  @Index()
  late String monthKey; // Format: "yyyy-MM" for quick monthly queries

  /// The record creation time (when addTransaction was called)
  late DateTime createdAt;

  TransactionModel();

  TransactionModel.create({
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    this.categoryId,
    this.note,
  }) {
    monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    createdAt = date; // createdAt = the user-chosen timestamp for display
  }

  Map<String, dynamic> toJson() => {
        'id': id == Isar.autoIncrement ? null : id,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String(),
        'type': type.index,
        'categoryId': categoryId,
        'note': note,
        'monthKey': monthKey,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final t = TransactionModel();
    if (json['id'] != null) t.id = json['id'];
    t.amount = (json['amount'] as num).toDouble();
    t.description = json['description'];
    t.date = DateTime.parse(json['date']);
    t.type = TransactionType.values[json['type'] as int];
    t.categoryId = json['categoryId'];
    t.note = json['note'];
    t.monthKey = json['monthKey'];
    t.createdAt = DateTime.parse(json['createdAt']);
    return t;
  }
}
