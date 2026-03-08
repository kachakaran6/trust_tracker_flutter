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
}
