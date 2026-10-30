import 'package:flutter/material.dart';

class BankInfo {
  final String name;
  final String code;
  final Color brandColor;
  final String initials;

  const BankInfo({
    required this.name,
    required this.code,
    required this.brandColor,
    required this.initials,
  });
}

class BankDetector {
  static const Map<String, BankInfo> _knownBanks = {
    'KOTAK': BankInfo(
      name: 'Kotak Bank',
      code: 'KOTAK',
      brandColor: Color(0xFFED1C24),
      initials: 'KB',
    ),
    'HDFC': BankInfo(
      name: 'HDFC Bank',
      code: 'HDFC',
      brandColor: Color(0xFF004B87),
      initials: 'HD',
    ),
    'SBI': BankInfo(
      name: 'State Bank of India',
      code: 'SBI',
      brandColor: Color(0xFF1B5494),
      initials: 'SBI',
    ),
    'ICICI': BankInfo(
      name: 'ICICI Bank',
      code: 'ICICI',
      brandColor: Color(0xFFF37021),
      initials: 'IC',
    ),
    'AXIS': BankInfo(
      name: 'Axis Bank',
      code: 'AXIS',
      brandColor: Color(0xFF97144D),
      initials: 'AX',
    ),
    'PNB': BankInfo(
      name: 'Punjab National Bank',
      code: 'PNB',
      brandColor: Color(0xFFA20000),
      initials: 'PNB',
    ),
    'BOB': BankInfo(
      name: 'Bank of Baroda',
      code: 'BOB',
      brandColor: Color(0xFFF26522),
      initials: 'BOB',
    ),
    'CANARA': BankInfo(
      name: 'Canara Bank',
      code: 'CANARA',
      brandColor: Color(0xFF0072BC),
      initials: 'CB',
    ),
    'UNION': BankInfo(
      name: 'Union Bank of India',
      code: 'UNION',
      brandColor: Color(0xFF005696),
      initials: 'UB',
    ),
    'IDFC': BankInfo(
      name: 'IDFC FIRST Bank',
      code: 'IDFC',
      brandColor: Color(0xFF9F191E),
      initials: 'IDFC',
    ),
    'YES': BankInfo(
      name: 'Yes Bank',
      code: 'YES',
      brandColor: Color(0xFF003D7A),
      initials: 'YES',
    ),
    'INDUSIND': BankInfo(
      name: 'IndusInd Bank',
      code: 'INDUSIND',
      brandColor: Color(0xFF83181C),
      initials: 'IN',
    ),
    'PAYTM': BankInfo(
      name: 'Paytm Payments Bank',
      code: 'PAYTM',
      brandColor: Color(0xFF00BAF2),
      initials: 'PTM',
    ),
    'FEDERAL': BankInfo(
      name: 'Federal Bank',
      code: 'FEDERAL',
      brandColor: Color(0xFF004380),
      initials: 'FB',
    ),
    'RBL': BankInfo(
      name: 'RBL Bank',
      code: 'RBL',
      brandColor: Color(0xFF0C2074),
      initials: 'RBL',
    ),
  };

  static BankInfo detect({required String sender, String? body}) {
    final cleanSender = sender.toUpperCase().trim();
    final cleanBody = (body ?? '').toUpperCase();

    // 1. Check message body first if explicit bank name is mentioned
    // E.g. "Kotak Bank A/c X1611" or "HDFC Bank a/c"
    if (cleanBody.contains('KOTAK')) return _knownBanks['KOTAK']!;
    if (cleanBody.contains('HDFC')) return _knownBanks['HDFC']!;
    if (cleanBody.contains('STATE BANK') || cleanBody.contains('SBI BANK') || cleanBody.contains('SBI A/C')) {
      return _knownBanks['SBI']!;
    }
    if (cleanBody.contains('ICICI')) return _knownBanks['ICICI']!;
    if (cleanBody.contains('AXIS BANK')) return _knownBanks['AXIS']!;
    if (cleanBody.contains('PUNJAB NATIONAL') || cleanBody.contains('PNB BANK')) return _knownBanks['PNB']!;
    if (cleanBody.contains('BANK OF BARODA') || cleanBody.contains('BOB BANK')) return _knownBanks['BOB']!;
    if (cleanBody.contains('CANARA')) return _knownBanks['CANARA']!;
    if (cleanBody.contains('UNION BANK')) return _knownBanks['UNION']!;
    if (cleanBody.contains('IDFC')) return _knownBanks['IDFC']!;
    if (cleanBody.contains('YES BANK')) return _knownBanks['YES']!;
    if (cleanBody.contains('INDUSIND')) return _knownBanks['INDUSIND']!;
    if (cleanBody.contains('PAYTM')) return _knownBanks['PAYTM']!;
    if (cleanBody.contains('FEDERAL BANK')) return _knownBanks['FEDERAL']!;
    if (cleanBody.contains('RBL BANK')) return _knownBanks['RBL']!;

    // 2. Check SMS Sender header
    // Senders often look like: AX-KOTAKB, VM-HDFCBK, AD-ICICIB, BZ-SBIINB, VK-AXISBK, etc.
    if (cleanSender.contains('KOTAK')) return _knownBanks['KOTAK']!;
    if (cleanSender.contains('HDFC')) return _knownBanks['HDFC']!;
    if (cleanSender.contains('SBI') || cleanSender.contains('STATEBANK')) return _knownBanks['SBI']!;
    if (cleanSender.contains('ICICI')) return _knownBanks['ICICI']!;
    if (cleanSender.contains('AXIS')) return _knownBanks['AXIS']!;
    if (cleanSender.contains('PNB')) return _knownBanks['PNB']!;
    if (cleanSender.contains('BOB') || cleanSender.contains('BARODA')) return _knownBanks['BOB']!;
    if (cleanSender.contains('CANBNK') || cleanSender.contains('CANARA')) return _knownBanks['CANARA']!;
    if (cleanSender.contains('UNIONB') || cleanSender.contains('UBI')) return _knownBanks['UNION']!;
    if (cleanSender.contains('IDFC')) return _knownBanks['IDFC']!;
    if (cleanSender.contains('YESB') || cleanSender.contains('YESBNK')) return _knownBanks['YES']!;
    if (cleanSender.contains('INDUS')) return _knownBanks['INDUSIND']!;
    if (cleanSender.contains('PAYTM')) return _knownBanks['PAYTM']!;
    if (cleanSender.contains('FEDBNK')) return _knownBanks['FEDERAL']!;
    if (cleanSender.contains('RBL')) return _knownBanks['RBL']!;

    // Generic fallback for unidentified banks
    final displayName = _formatSenderFallback(cleanSender);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'B';
    return BankInfo(
      name: displayName,
      code: 'BANK',
      brandColor: const Color(0xFF0F766E), // Elegant teal
      initials: initial,
    );
  }

  static String _formatSenderFallback(String sender) {
    if (sender.isEmpty) return 'Bank';
    // Remove telecom prefix if present (e.g. AX- or VM-)
    final parts = sender.split('-');
    final core = parts.length > 1 ? parts.last : parts.first;
    if (core.length >= 3) {
      return core.toUpperCase();
    }
    return sender;
  }
}

