import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:trust_tracker_flutter/core/utils/money.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/bank_detector.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/detected_sms_transaction.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_confidence.dart';
import 'package:trust_tracker_flutter/features/sms_detection/domain/models/sms_parse_result.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/sms_classifier.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/amount_extractor.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/direction_detector.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/account_masker.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/merchant_extractor.dart';
import 'package:trust_tracker_flutter/features/sms_detection/data/parser/category_suggester.dart';

class SmsTransactionParser {
  // Regex to extract transaction dates from SMS (e.g. 22-10-26, 22/10/2026, 22-Oct-26)
  static final RegExp _datePattern = RegExp(
    r'\b(\d{1,2})[-/.](\d{1,2}|[a-zA-Z]{3})[-/.](\d{2,4})\b',
  );

  static SmsParseResult parse({
    required String body,
    required String sender,
    DateTime? smsReceivedTime,
  }) {
    final cleanBody = body.trim();
    final cleanSender = sender.trim().toUpperCase();

    // Step 1: Classification Gate (OTP, Promos, Limits, Failed, Balance-only)
    final classification = SmsClassifier.classify(cleanBody, cleanSender);
    if (!classification.isEligible) {
      return SmsParseResult.nonTransaction(
        classification.rejectionReason ?? 'Non-transaction message',
      );
    }

    // Step 2: Amount Extraction with Context Awareness & Precision
    final amountResult = AmountExtractor.extract(cleanBody);
    if (amountResult == null || amountResult.money.paise <= 0) {
      return SmsParseResult.rejected('No valid transaction amount identified');
    }

    // Step 3: Direction Detection
    final directionResult = DirectionDetector.detect(cleanBody);
    if (directionResult.category == SmsTransactionCategory.unknown && directionResult.confidence < 0.5) {
      return SmsParseResult.rejected('Ambiguous or unrecognized transaction direction');
    }

    // Step 4: Account Masking
    final maskedAccount = AccountMasker.extractMaskedAccount(cleanBody);

    // Step 5: Bank Detection
    final bankInfo = BankDetector.detect(sender: cleanSender, body: cleanBody);

    // Step 6: Merchant / Counterparty & Reference Number Extraction
    final merchant = MerchantExtractor.extractMerchant(cleanBody);
    final refNumber = MerchantExtractor.extractReferenceNumber(cleanBody);

    // Step 7: Transaction Date Extraction
    final txnDate = _extractDate(cleanBody) ?? smsReceivedTime ?? DateTime.now();

    // Step 8: Category Suggestion
    final suggestedCategory = CategorySuggester.suggestCategory(
      type: directionResult.type,
      merchant: merchant,
      body: cleanBody,
    );

    // Step 9: Confidence Scoring & Ambiguity Handling
    double confidenceScore = 0.4;
    if (amountResult.money.paise > 0) confidenceScore += 0.2;
    if (directionResult.confidence >= 0.9) confidenceScore += 0.2;
    if (maskedAccount != null) confidenceScore += 0.1;
    if (merchant != null) confidenceScore += 0.05;
    if (refNumber != null) confidenceScore += 0.1;
    if (amountResult.isAmbiguous) confidenceScore -= 0.3;

    confidenceScore = confidenceScore.clamp(0.0, 1.0);

    final hasStrongIdentifier = maskedAccount != null || refNumber != null;

    SmsConfidenceLevel confidenceLevel;
    if (!amountResult.isAmbiguous &&
        confidenceScore >= 0.80 &&
        directionResult.confidence >= 0.85 &&
        hasStrongIdentifier) {
      confidenceLevel = SmsConfidenceLevel.high;
    } else if (confidenceScore >= 0.50 && !amountResult.isAmbiguous) {
      confidenceLevel = SmsConfidenceLevel.medium;
    } else {
      confidenceLevel = SmsConfidenceLevel.low;
    }

    // Step 10: Deduplication Fingerprint
    final fingerprint = _generateFingerprint(
      sender: cleanSender,
      amount: amountResult.amount,
      type: directionResult.type.index,
      refNumber: refNumber,
      maskedAccount: maskedAccount,
      date: txnDate,
    );

    // Step 11: Privacy-Preserving Sanitized Snippet
    final safeSnippet = _sanitizeMessageForDisplay(cleanBody);

    final transaction = DetectedSmsTransaction(
      smsFingerprint: fingerprint,
      referenceNumber: refNumber,
      sender: cleanSender,
      amount: amountResult.amount,
      currency: amountResult.currency,
      type: directionResult.type,
      categoryId: null,
      categoryName: suggestedCategory,
      merchant: merchant,
      maskedAccount: maskedAccount,
      date: txnDate,
      confidenceScore: confidenceScore,
      confidenceLevel: confidenceLevel,
      status: 'pending_review',
      rawSnippet: safeSnippet,
      createdAt: DateTime.now(),
      bankName: bankInfo.name,
      isAmbiguous: amountResult.isAmbiguous,
      parsingWarning: amountResult.warning,
    );

    return SmsParseResult.success(transaction);
  }

  static String _generateFingerprint({
    required String sender,
    required double amount,
    required int type,
    String? refNumber,
    String? maskedAccount,
    required DateTime date,
  }) {
    // If bank reference number exists, it is the primary stable identifier
    if (refNumber != null && refNumber.isNotEmpty) {
      final input = 'ref_${refNumber.toUpperCase()}';
      return sha256.convert(utf8.encode(input)).toString();
    }

    // Fallback: Composite fingerprint bounded by minute bucket to allow distinct transactions
    final minuteBucket = '${date.year}_${date.month}_${date.day}_${date.hour}_${date.minute}';
    final rawComposite = '${sender}_${type}_${amount.toStringAsFixed(2)}_${maskedAccount ?? 'none'}_$minuteBucket';
    return sha256.convert(utf8.encode(rawComposite)).toString();
  }

  static DateTime? _extractDate(String body) {
    final match = _datePattern.firstMatch(body);
    if (match == null) return null;

    final dayStr = match.group(1);
    final monthStr = match.group(2);
    final yearStr = match.group(3);

    if (dayStr == null || monthStr == null || yearStr == null) return null;

    final day = int.tryParse(dayStr);
    if (day == null || day < 1 || day > 31) return null;

    int? month;
    final parsedMonthInt = int.tryParse(monthStr);
    if (parsedMonthInt != null && parsedMonthInt >= 1 && parsedMonthInt <= 12) {
      month = parsedMonthInt;
    } else {
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      month = months[monthStr.toLowerCase()];
    }
    if (month == null) return null;

    int? year = int.tryParse(yearStr);
    if (year == null) return null;
    if (year < 100) {
      year += 2000;
    }

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Sanitizes SMS body for privacy while preserving the original message readable text.
  /// Masks full unmasked account numbers, removes OTPs and balance numbers.
  static String _sanitizeMessageForDisplay(String raw) {
    var s = raw.trim();

    // 1. Mask any full card/account numbers (>6 digits)
    s = s.replaceAllMapped(RegExp(r'\b\d{6,18}\b'), (m) {
      final digits = m.group(0)!;
      return '••${digits.substring(digits.length - 4)}';
    });

    // 2. Remove OTP or security code clauses completely
    s = s.replaceAll(
      RegExp(r'\b(?:secret\s*otp|otp|one\s*time\s*password|pin)\s*(?:is)?\s*[:\s-]*\d+\.?', caseSensitive: false),
      '',
    );

    // 3. Remove Balance clause numbers so privacy is preserved
    s = s.replaceAll(
      RegExp(r'\b(?:bal(?:ance)?|avl\s*bal|avail(?:able)?\s*bal(?:ance)?)\s*(?:is|:)?\s*(?:inr|rs\.?|₹)?\s*[0-9,]+(?:\.[0-9]{1,2})?\.?', caseSensitive: false),
      '',
    );

    // Clean up double spaces or dangling punctuation
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r'\s+\.'), '.');
    return s;
  }
}
