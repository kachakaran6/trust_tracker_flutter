import 'dart:ui' show PlatformDispatcher;

/// Derives the user's default currency from the device locale without
/// requiring any additional packages (just dart:ui which is always available).
///
/// Strategy:
/// 1. Read the system locale list from [PlatformDispatcher.instance.locales].
/// 2. Extract the ISO 3166-1 alpha-2 country code from the locale's
///    `countryCode` field (e.g. "IN", "GB", "JP").
/// 3. Map that country code → ISO 4217 currency code.
/// 4. Return "USD" if the country is unknown or no locale is available.
class CurrencyDetector {
  CurrencyDetector._();

  // ── Country → Currency map ────────────────────────────────────────────────
  // Covers the 80+ most common locales worldwide.
  static const Map<String, String> _countryToCurrency = {
    // Americas
    'US': 'USD', 'PR': 'USD', 'GU': 'USD', 'VI': 'USD', 'AS': 'USD',
    'CA': 'CAD',
    'MX': 'MXN',
    'BR': 'BRL',
    'AR': 'ARS',
    'CL': 'CLP',
    'CO': 'COP',
    'PE': 'PEN',
    'VE': 'VES',
    'UY': 'UYU',
    'PY': 'PYG',
    'BO': 'BOB',
    'EC': 'USD',
    'CR': 'CRC',
    'GT': 'GTQ',
    'CU': 'CUP',
    'DO': 'DOP',
    'HN': 'HNL',
    'NI': 'NIO',
    'PA': 'PAB',
    'TT': 'TTD',
    'JM': 'JMD',

    // Europe
    'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'ES': 'EUR', 'PT': 'EUR',
    'NL': 'EUR', 'BE': 'EUR', 'AT': 'EUR', 'IE': 'EUR', 'FI': 'EUR',
    'GR': 'EUR', 'SK': 'EUR', 'SI': 'EUR', 'LV': 'EUR', 'LT': 'EUR',
    'EE': 'EUR', 'LU': 'EUR', 'CY': 'EUR', 'MT': 'EUR',
    'GB': 'GBP',
    'CH': 'CHF',
    'NO': 'NOK',
    'SE': 'SEK',
    'DK': 'DKK',
    'PL': 'PLN',
    'CZ': 'CZK',
    'HU': 'HUF',
    'RO': 'RON',
    'BG': 'BGN',
    'HR': 'EUR',
    'RS': 'RSD',
    'TR': 'TRY',
    'RU': 'RUB',
    'UA': 'UAH',
    'IS': 'ISK',

    // Asia-Pacific
    'IN': 'INR',
    'JP': 'JPY',
    'CN': 'CNY',
    'KR': 'KRW',
    'HK': 'HKD',
    'TW': 'TWD',
    'SG': 'SGD',
    'MY': 'MYR',
    'TH': 'THB',
    'ID': 'IDR',
    'PH': 'PHP',
    'VN': 'VND',
    'MM': 'MMK',
    'KH': 'KHR',
    'LA': 'LAK',
    'BD': 'BDT',
    'PK': 'PKR',
    'LK': 'LKR',
    'NP': 'NPR',
    'AU': 'AUD',
    'NZ': 'NZD',
    'FJ': 'FJD',
    'PG': 'PGK',

    // Middle East
    'AE': 'AED',
    'SA': 'SAR',
    'QA': 'QAR',
    'KW': 'KWD',
    'BH': 'BHD',
    'OM': 'OMR',
    'JO': 'JOD',
    'IL': 'ILS',
    'IR': 'IRR',
    'IQ': 'IQD',

    // Africa
    'ZA': 'ZAR',
    'NG': 'NGN',
    'KE': 'KES',
    'GH': 'GHS',
    'EG': 'EGP',
    'MA': 'MAD',
    'TN': 'TND',
    'ET': 'ETB',
    'TZ': 'TZS',
    'UG': 'UGX',
    'DZ': 'DZD',
    'SD': 'SDG',
    'MZ': 'MZN',
    'AO': 'AOA',
    'CM': 'XAF',
    'CI': 'XOF',
    'SN': 'XOF',
  };

  /// Returns the ISO 4217 code for the device locale's country.
  /// Falls back to [fallback] (defaults to "USD") if undetectable.
  static String detect({String fallback = 'USD'}) {
    try {
      final locales = PlatformDispatcher.instance.locales;
      for (final locale in locales) {
        final country = locale.countryCode?.toUpperCase();
        if (country != null && _countryToCurrency.containsKey(country)) {
          return _countryToCurrency[country]!;
        }
      }
    } catch (_) {
      // Swallow any platform errors silently
    }
    return fallback;
  }

  /// Returns true if [currencyCode] is in the supported list
  /// (i.e. it appears in AppConstants.currencies).
  static bool isSupported(String currencyCode) {
    return _supportedCodes.contains(currencyCode);
  }

  /// The set of currencies exposed in the app's Settings picker.
  /// If a detected currency is not in this list we fall back to USD so the
  /// Settings dropdown always has a valid selection.
  static const Set<String> _supportedCodes = {
    'USD', 'EUR', 'GBP', 'INR', 'JPY', 'CAD', 'AUD', 'BRL', 'CNY',
    'CHF', 'KRW', 'MXN',
  };

  /// Detects the locale currency and also validates it against the
  /// supported picker list, falling back to USD if unsupported.
  static String detectSupported() {
    final detected = detect();
    return isSupported(detected) ? detected : 'USD';
  }
}
