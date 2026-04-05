class BudgetModel {
  int? id;
  late int categoryId;
  late double amount;
  late String monthKey;
  late DateTime createdAt;

  BudgetModel();

  BudgetModel.create({
    required this.categoryId,
    required this.amount,
    required this.monthKey,
  }) {
    createdAt = DateTime.now();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'categoryId': categoryId,
        'amount': amount,
        'monthKey': monthKey,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    final b = BudgetModel();
    b.id = map['id'];
    b.categoryId = map['categoryId'];
    b.amount = (map['amount'] as num).toDouble();
    b.monthKey = map['monthKey'];
    b.createdAt = DateTime.parse(map['createdAt']);
    return b;
  }

  // Keep compatibility if needed
  Map<String, dynamic> toJson() => toMap();
  factory BudgetModel.fromJson(Map<String, dynamic> json) => BudgetModel.fromMap(json);
}
