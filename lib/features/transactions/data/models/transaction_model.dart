enum TransactionType { income, expense }

class TransactionModel {
  int? id;
  late double amount;
  late String description;
  late DateTime date;
  late TransactionType type;
  int? categoryId;
  String? note;
  late String monthKey;
  late DateTime createdAt;

  // Debt & Udhar tracking fields
  bool isDebt = false;
  String? debtType; // 'given' (money lent out / Udhar Aapyu) or 'taken' (money borrowed / Udhar Lidhu)
  String? personName;
  DateTime? dueDate;
  bool isSettled = false;
  DateTime? settledAt;

  TransactionModel();

  TransactionModel.create({
    required this.amount,
    required this.description,
    required this.date,
    required this.type,
    this.categoryId,
    this.note,
    this.isDebt = false,
    this.debtType,
    this.personName,
    this.dueDate,
    this.isSettled = false,
    this.settledAt,
  }) {
    monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    createdAt = date;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String(),
        'type': type.index,
        'categoryId': categoryId,
        'note': note,
        'monthKey': monthKey,
        'createdAt': createdAt.toIso8601String(),
        'isDebt': isDebt ? 1 : 0,
        'debtType': debtType,
        'personName': personName,
        'dueDate': dueDate?.toIso8601String(),
        'isSettled': isSettled ? 1 : 0,
        'settledAt': settledAt?.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final t = TransactionModel();
    t.id = map['id'];
    t.amount = (map['amount'] as num).toDouble();
    t.description = map['description'];
    t.date = DateTime.parse(map['date']);
    t.type = TransactionType.values[map['type'] as int];
    t.categoryId = map['categoryId'];
    t.note = map['note'];
    t.monthKey = map['monthKey'];
    t.createdAt = DateTime.parse(map['createdAt']);
    t.isDebt = (map['isDebt'] as int? ?? 0) == 1;
    t.debtType = map['debtType'] as String?;
    t.personName = map['personName'] as String?;
    t.dueDate = map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null;
    t.isSettled = (map['isSettled'] as int? ?? 0) == 1;
    t.settledAt = map['settledAt'] != null ? DateTime.parse(map['settledAt']) : null;
    return t;
  }

  // Keep compatibility if needed
  Map<String, dynamic> toJson() => toMap();
  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel.fromMap(json);
}
