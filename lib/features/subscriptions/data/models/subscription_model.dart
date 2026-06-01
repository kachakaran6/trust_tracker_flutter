enum BillingCycle { daily, weekly, monthly, quarterly, yearly, custom, halfYearly }

class SubscriptionModel {
  int? id;
  late String name;
  late double amount;
  int? categoryId;
  late BillingCycle billingCycle;
  int? customDays;
  late DateTime startDate;
  late DateTime nextDueDate;
  late bool autoDeduct;
  late bool autoAddExpense;
  late bool repeatEnabled;
  late int notifyBeforeDays;
  String? icon;
  String? notes;
  String? subscriptionType; // e.g. OTT, Mobile Recharge, DTH, etc.
  late bool isPaused;
  DateTime? lastProcessedDate;
  late DateTime createdAt;
  late DateTime updatedAt;

  SubscriptionModel();

  SubscriptionModel.create({
    required this.name,
    required this.amount,
    this.categoryId,
    required this.billingCycle,
    this.customDays,
    required this.startDate,
    required this.nextDueDate,
    this.autoDeduct = false,
    this.autoAddExpense = false,
    this.repeatEnabled = true,
    this.notifyBeforeDays = 0,
    this.icon,
    this.notes,
    this.subscriptionType,
    this.isPaused = false,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'categoryId': categoryId,
        'billingCycle': billingCycle.index,
        'customDays': customDays,
        'startDate': startDate.toIso8601String(),
        'nextDueDate': nextDueDate.toIso8601String(),
        'autoDeduct': autoDeduct ? 1 : 0,
        'autoAddExpense': autoAddExpense ? 1 : 0,
        'repeatEnabled': repeatEnabled ? 1 : 0,
        'notifyBeforeDays': notifyBeforeDays,
        'icon': icon,
        'notes': notes,
        'subscriptionType': subscriptionType,
        'isPaused': isPaused ? 1 : 0,
        'lastProcessedDate': lastProcessedDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    final s = SubscriptionModel();
    s.id = map['id'];
    s.name = map['name'];
    s.amount = (map['amount'] as num).toDouble();
    s.categoryId = map['categoryId'];
    final cycleIndex = map['billingCycle'] as int;
    s.billingCycle = cycleIndex < BillingCycle.values.length
        ? BillingCycle.values[cycleIndex]
        : BillingCycle.monthly;
    s.customDays = map['customDays'];
    s.startDate = DateTime.parse(map['startDate']);
    s.nextDueDate = DateTime.parse(map['nextDueDate']);
    s.autoDeduct = (map['autoDeduct'] as int) == 1;
    s.autoAddExpense = (map['autoAddExpense'] as int) == 1;
    s.repeatEnabled = (map['repeatEnabled'] as int) == 1;
    s.notifyBeforeDays = map['notifyBeforeDays'] as int;
    s.icon = map['icon'];
    s.notes = map['notes'];
    s.subscriptionType = map['subscriptionType'];
    s.isPaused = (map['isPaused'] as int) == 1;
    s.lastProcessedDate = map['lastProcessedDate'] != null ? DateTime.parse(map['lastProcessedDate']) : null;
    s.createdAt = DateTime.parse(map['createdAt']);
    s.updatedAt = DateTime.parse(map['updatedAt']);
    return s;
  }

  Map<String, dynamic> toJson() => toMap();
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => SubscriptionModel.fromMap(json);
}
