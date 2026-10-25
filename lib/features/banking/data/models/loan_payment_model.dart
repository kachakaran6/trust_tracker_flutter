class LoanPaymentModel {
  final int? id;
  final int loanId;
  final double amount;
  final DateTime date;
  final String status; // paid, partial, skipped, delayed
  final String method;
  final String? notes;

  LoanPaymentModel({
    this.id,
    required this.loanId,
    required this.amount,
    required this.date,
    required this.status,
    required this.method,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loanId': loanId,
      'amount': amount,
      'date': date.toIso8601String(),
      'status': status,
      'method': method,
      'notes': notes,
    };
  }

  factory LoanPaymentModel.fromMap(Map<String, dynamic> map) {
    return LoanPaymentModel(
      id: map['id']?.toInt(),
      loanId: map['loanId']?.toInt() ?? 0,
      amount: map['amount']?.toDouble() ?? 0.0,
      date: DateTime.parse(map['date']),
      status: map['status'] ?? 'paid',
      method: map['method'] ?? '',
      notes: map['notes'],
    );
  }

  LoanPaymentModel copyWith({
    int? id,
    int? loanId,
    double? amount,
    DateTime? date,
    String? status,
    String? method,
    String? notes,
  }) {
    return LoanPaymentModel(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      status: status ?? this.status,
      method: method ?? this.method,
      notes: notes ?? this.notes,
    );
  }
}
