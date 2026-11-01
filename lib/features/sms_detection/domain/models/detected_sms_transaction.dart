import 'package:trust_tracker_flutter/core/utils/money.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/bank_detector.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';

class DetectedSmsTransaction {
  int? id;
  final String smsFingerprint;
  final String? referenceNumber;
  final String sender;
  double amount;
  final String currency;
  final TransactionType type;
  final int? categoryId;
  final String? categoryName;
  final String? merchant;
  final String? maskedAccount;
  final DateTime date;
  double confidenceScore;
  final SmsConfidenceLevel confidenceLevel;
  String status; // 'pending_review', 'approved', 'rejected', 'ignored'
  final String? rawSnippet;
  int? transactionId;
  final DateTime createdAt;
  final String? rejectionReason;
  final String? bankName;
  final double? availableBalance;
  bool isAmbiguous;
  String? parsingWarning;

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
    String? bankName,
    this.availableBalance,
    this.isAmbiguous = false,
    this.parsingWarning,
  })  : createdAt = createdAt ?? DateTime.now(),
        bankName = bankName ?? BankDetector.detect(sender: sender, body: rawSnippet).name;

  /// Exact monetary representation in paise (1 INR = 100 paise)
  int get amountPaise => (amount * 100.0).round();

  Money get money => Money.fromPaise(amountPaise, currency: currency);

  /// Signed financial model: Negative ledger impact for Expense, Positive for Income
  Money get signedMoney {
    final signedPaise = (type == TransactionType.expense) ? -amountPaise : amountPaise;
    return Money.fromPaise(signedPaise, currency: currency);
  }

  /// Safe display amount with exact Indian notation (e.g. ₹35,931.00).
  /// Never displays '+₹15,000.00' for an Expense.
  String formattedAmount({bool showSymbol = true, bool showSign = false}) {
    if (showSign) {
      final signStr = (type == TransactionType.expense) ? '−' : '+';
      return '$signStr${money.formatIndian(showSymbol: showSymbol, showSign: false)}';
    }
    return money.formatIndian(showSymbol: showSymbol, showSign: false);
  }

  /// Safe display of extracted available account balance (e.g. ₹8,327.22)
  String? formattedBalance({bool showSymbol = true}) {
    if (availableBalance == null) return null;
    final balPaise = (availableBalance! * 100.0).round();
    return Money.fromPaise(balPaise, currency: currency).formatIndian(showSymbol: showSymbol);
  }

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
        'balance': availableBalance,
      };

  factory DetectedSmsTransaction.fromMap(Map<String, dynamic> map) {
    final s = map['sender'] as String? ?? 'Unknown';
    final snip = map['rawSnippet'] as String?;
    return DetectedSmsTransaction(
      id: map['id'] as int?,
      smsFingerprint: map['smsFingerprint'] as String? ?? '',
      referenceNumber: map['referenceNumber'] as String?,
      sender: s,
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
      rawSnippet: snip,
      transactionId: map['transactionId'] as int?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      bankName: BankDetector.detect(sender: s, body: snip).name,
      availableBalance: (map['balance'] as num?)?.toDouble(),
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
    String? bankName,
    double? availableBalance,
    bool? isAmbiguous,
    String? parsingWarning,
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
      bankName: bankName ?? this.bankName,
      availableBalance: availableBalance ?? this.availableBalance,
      isAmbiguous: isAmbiguous ?? this.isAmbiguous,
      parsingWarning: parsingWarning ?? this.parsingWarning,
    );
  }
}
