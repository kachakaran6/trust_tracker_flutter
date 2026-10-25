enum SmsConfidenceLevel {
  high,
  medium,
  low;

  String get displayName {
    switch (this) {
      case SmsConfidenceLevel.high:
        return 'High Confidence';
      case SmsConfidenceLevel.medium:
        return 'Needs Review';
      case SmsConfidenceLevel.low:
        return 'Low Confidence';
    }
  }
}
