import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';

class DetectedSmsTransaction {
  int? id;
  final String smsFingerprint;
  final String? referenceNumber;
  final String sender;
  final double amount;
  final String currency;
  final TransactionType type;
  final int? categoryId;
  final String? categoryName;
  final String? merchant;
  final String? maskedAccount;
  final DateTime date;
  final double confidenceScore;
  final SmsConfidenceLevel confidenceLevel;
  String status; // 'pending_review', 'approved', 'rejected', 'ignored'
  final String? rawSnippet;
  int? transactionId;
  final DateTime createdAt;
  final String? rejectionReason;

  DetectedSmsTransaction({
    this.id,
    required this.smsFingerprint,
    this.referenceNumber,
    required this.sender,
    required this.amount,
    this.currency = 'INR',
    required this.type,
    this.categoryId,
    this.categoryName,
    this.merchant,
    this.maskedAccount,
    required this.date,
    required this.confidenceScore,
    required this.confidenceLevel,
    this.status = 'pending_review',
    this.rawSnippet,
    this.transactionId,
    DateTime? createdAt,
    this.rejectionReason,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'smsFingerprint': smsFingerprint,
        'referenceNumber': referenceNumber,
        'sender': sender,
        'amount': amount,
        'currency': currency,
        'type': type.index,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'merchant': merchant,
        'maskedAccount': maskedAccount,
        'date': date.toIso8601String(),
        'confidenceScore': confidenceScore,
        'confidenceLevel': confidenceLevel.name,
        'status': status,
        'rawSnippet': rawSnippet,
        'transactionId': transactionId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DetectedSmsTransaction.fromMap(Map<String, dynamic> map) {
    return DetectedSmsTransaction(
      id: map['id'] as int?,
      smsFingerprint: map['smsFingerprint'] as String? ?? '',
      referenceNumber: map['referenceNumber'] as String?,
      sender: map['sender'] as String? ?? 'Unknown',
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'INR',
      type: TransactionType.values[map['type'] as int? ?? 1],
      categoryId: map['categoryId'] as int?,
      categoryName: map['categoryName'] as String?,
      merchant: map['merchant'] as String?,
      maskedAccount: map['maskedAccount'] as String?,
      date: DateTime.parse(map['date'] as String),
      confidenceScore: (map['confidenceScore'] as num? ?? 0.8).toDouble(),
      confidenceLevel: SmsConfidenceLevel.values.firstWhere(
        (e) => e.name == map['confidenceLevel'],
        orElse: () => SmsConfidenceLevel.medium,
      ),
      status: map['status'] as String? ?? 'pending_review',
      rawSnippet: map['rawSnippet'] as String?,
      transactionId: map['transactionId'] as int?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  DetectedSmsTransaction copyWith({
    int? id,
    String? smsFingerprint,
    String? referenceNumber,
    String? sender,
    double? amount,
    String? currency,
    TransactionType? type,
    int? categoryId,
    String? categoryName,
    String? merchant,
    String? maskedAccount,
    DateTime? date,
    double? confidenceScore,
    SmsConfidenceLevel? confidenceLevel,
    String? status,
    String? rawSnippet,
    int? transactionId,
    DateTime? createdAt,
    String? rejectionReason,
  }) {
    return DetectedSmsTransaction(
      id: id ?? this.id,
      smsFingerprint: smsFingerprint ?? this.smsFingerprint,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      sender: sender ?? this.sender,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      merchant: merchant ?? this.merchant,
      maskedAccount: maskedAccount ?? this.maskedAccount,
      date: date ?? this.date,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      status: status ?? this.status,
      rawSnippet: rawSnippet ?? this.rawSnippet,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
