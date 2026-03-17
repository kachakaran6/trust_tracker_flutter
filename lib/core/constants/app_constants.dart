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
      'icon': 'briefcase'
    },
    {
      'name': 'Freelance',
      'type': 'income',
      'color': '#3B82F6',
      'icon': 'laptop'
    },
    {
      'name': 'Investment',
      'type': 'income',
      'color': '#8B5CF6',
      'icon': 'trending_up'
    },
    {
      'name': 'Food & Dining',
      'type': 'expense',
      'color': '#F97316',
      'icon': 'restaurant'
    },
    {'name': 'Transport', 'type': 'expense', 'color': '#06B6D4', 'icon': 'car'},
    {
      'name': 'Shopping',
      'type': 'expense',
      'color': '#EC4899',
      'icon': 'shopping_bag'
    },
    {
      'name': 'Entertainment',
      'type': 'expense',
      'color': '#8B5CF6',
      'icon': 'movie'
    },
    {'name': 'Health', 'type': 'expense', 'color': '#EF4444', 'icon': 'heart'},
    {
      'name': 'Utilities',
      'type': 'expense',
      'color': '#6366F1',
      'icon': 'bolt'
    },
    {
      'name': 'Education',
      'type': 'expense',
      'color': '#F59E0B',
      'icon': 'school'
    },
    {
      'name': 'Rent/Housing',
      'type': 'expense',
      'color': '#14B8A6',
      'icon': 'home'
    },
    {
      'name': 'Other',
      'type': 'expense',
      'color': '#6B7280',
      'icon': 'category'
    },
  ];

  // SharedPreferences Keys
  static const String prefCurrency = 'pref_currency';
  static const String prefTheme = 'pref_theme';
  static const String prefUserName = 'pref_user_name';
  static const String prefIsFirstRun = 'pref_is_first_run';
}
