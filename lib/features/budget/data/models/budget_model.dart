import 'package:isar/isar.dart';

part 'budget_model.g.dart';

@collection
class BudgetModel {
  Id id = Isar.autoIncrement;

  late int categoryId;
  late double amount;

  @Index(composite: [CompositeIndex('categoryId')])
  late String monthKey; // Format: "yyyy-MM"

  late DateTime createdAt;

  BudgetModel();

  BudgetModel.create({
    required this.categoryId,
    required this.amount,
    required this.monthKey,
  }) {
    createdAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'id': id == Isar.autoIncrement ? null : id,
        'categoryId': categoryId,
        'amount': amount,
        'monthKey': monthKey,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    final b = BudgetModel();
    if (json['id'] != null) b.id = json['id'];
    b.categoryId = json['categoryId'];
    b.amount = (json['amount'] as num).toDouble();
    b.monthKey = json['monthKey'];
    b.createdAt = DateTime.parse(json['createdAt']);
    return b;
  }
}
