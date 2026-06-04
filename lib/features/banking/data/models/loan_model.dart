import 'package:trust_tracker_flutter/features/banking/data/models/loan_payment_model.dart';

class LoanModel {
  final int? id;
  final String name;
  final String type;
  final String bankName;
  final double amount;
  final double interestRate;
  final DateTime startDate;
  final DateTime endDate;
  final int tenureMonths;
  final double emiAmount;
  final int emiDueDay;
  final String? accountNumber;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final bool autoRecordExpense;
  final DateTime? takenDate;

  // Transient fields for UI
  final List<LoanPaymentModel>? payments;

  LoanModel({
    this.id,
    required this.name,
    required this.type,
    required this.bankName,
    required this.amount,
    required this.interestRate,
    required this.startDate,
    required this.endDate,
    required this.tenureMonths,
    required this.emiAmount,
    required this.emiDueDay,
    this.accountNumber,
    this.notes,
    required this.status,
    required this.createdAt,
    this.autoRecordExpense = false,
    this.takenDate,
    this.payments,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'bankName': bankName,
      'amount': amount,
      'interestRate': interestRate,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'tenureMonths': tenureMonths,
      'emiAmount': emiAmount,
      'emiDueDay': emiDueDay,
      'accountNumber': accountNumber,
      'notes': notes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'autoRecordExpense': autoRecordExpense ? 1 : 0,
      'takenDate': takenDate?.toIso8601String(),
    };
  }

  factory LoanModel.fromMap(Map<String, dynamic> map, {List<LoanPaymentModel>? payments}) {
    return LoanModel(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      bankName: map['bankName'] ?? '',
      amount: map['amount']?.toDouble() ?? 0.0,
      interestRate: map['interestRate']?.toDouble() ?? 0.0,
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      tenureMonths: map['tenureMonths']?.toInt() ?? 0,
      emiAmount: map['emiAmount']?.toDouble() ?? 0.0,
      emiDueDay: map['emiDueDay']?.toInt() ?? 1,
      accountNumber: map['accountNumber'],
      notes: map['notes'],
      status: map['status'] ?? 'active',
      createdAt: DateTime.parse(map['createdAt']),
      autoRecordExpense: (map['autoRecordExpense'] ?? 0) == 1,
      takenDate: map['takenDate'] != null ? DateTime.parse(map['takenDate']) : null,
      payments: payments,
    );
  }

  LoanModel copyWith({
    int? id,
    String? name,
    String? type,
    String? bankName,
    double? amount,
    double? interestRate,
    DateTime? startDate,
    DateTime? endDate,
    int? tenureMonths,
    double? emiAmount,
    int? emiDueDay,
    String? accountNumber,
    String? notes,
    String? status,
    DateTime? createdAt,
    bool? autoRecordExpense,
    DateTime? takenDate,
    List<LoanPaymentModel>? payments,
  }) {
    return LoanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      bankName: bankName ?? this.bankName,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      emiAmount: emiAmount ?? this.emiAmount,
      emiDueDay: emiDueDay ?? this.emiDueDay,
      accountNumber: accountNumber ?? this.accountNumber,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      autoRecordExpense: autoRecordExpense ?? this.autoRecordExpense,
      takenDate: takenDate ?? this.takenDate,
      payments: payments ?? this.payments,
    );
  }
}
