class AppConstants {
  static const String appName = 'Trust Tracker';
  static const String dbName = 'trust_tracker.isar';

  // Currencies
  static const List<Map<String, String>> currencies = [
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'BRL', 'symbol': 'R\$', 'name': 'Brazilian Real'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'KRW', 'symbol': '₩', 'name': 'South Korean Won'},
    {'code': 'MXN', 'symbol': '\$', 'name': 'Mexican Peso'},
  ];

  static const List<String> categoryIcons = [
    '💰', '💸', '🥗', '🚋', '🛒', '📚', '💊', '🏠', '💻', '📈', '🎬', '⚡', '📦',
    '🍔', '☕', '🚗', '🛠️', '🎁', '✈️', '🎮', '🕹️', '👗', '🏋️', '🐱', '🐶', '🍕',
    '🚲', '⛽', '🍿', '💡', '🧼', '🍼', '🍎', '🍰', '🏟️', '🏖️'
  ];

  // Default category color options
  static const List<String> categoryColors = [
    '#3B82F6', // Blue
    '#10B981', // Green
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#84CC16', // Lime
    '#F97316', // Orange
    '#14B8A6', // Teal
    '#6366F1', // Indigo
    '#D946EF', // Fuchsia
  ];

  // Default categories (seeded on first run)
  static const List<Map<String, dynamic>> defaultCategories = [
    {
      'name': 'Salary',
      'type': 'income',
      'color': '#10B981',
      'icon': '💰'
    },
    {
      'name': 'Freelance',
      'type': 'income',
      'color': '#3B82F6',
      'icon': '💻'
    },
    {
      'name': 'Investment',
      'type': 'income',
      'color': '#8B5CF6',
      'icon': '📈'
    },
    {
      'name': 'Food & Dining',
      'type': 'expense',
      'color': '#F97316',
      'icon': '🥗'
    },
    {'name': 'Transport', 'type': 'expense', 'color': '#06B6D4', 'icon': '🚋'},
    {
      'name': 'Shopping',
      'type': 'expense',
      'color': '#EC4899',
      'icon': '🛒'
    },
    {
      'name': 'Entertainment',
      'type': 'expense',
      'color': '#8B5CF6',
      'icon': '🎬'
    },
    {'name': 'Health', 'type': 'expense', 'color': '#EF4444', 'icon': '💊'},
    {
      'name': 'Utilities',
      'type': 'expense',
      'color': '#6366F1',
      'icon': '⚡'
    },
    {
      'name': 'Education',
      'type': 'expense',
      'color': '#F59E0B',
      'icon': '📚'
    },
    {
      'name': 'Rent/Housing',
      'type': 'expense',
      'color': '#14B8A6',
      'icon': '🏠'
    },
    {
      'name': 'Other',
      'type': 'expense',
      'color': '#6B7280',
      'icon': '📦'
    },
  ];

  // SharedPreferences Keys
  static const String prefCurrency = 'pref_currency';
  static const String prefTheme = 'pref_theme';
  static const String prefLanguage = 'pref_language';
  static const String prefUserName = 'pref_user_name';
  static const String prefIsFirstRun = 'pref_is_first_run';
  static const String prefAccentColor = 'pref_accent_color';
}
