class CategoryUtils {
  static const Map<String, String> _iconToEmoji = {
    'briefcase': '💰',
    'laptop': '💻',
    'trending_up': '📈',
    'restaurant': '🥗',
    'car': '🚋',
    'shopping_bag': '🛒',
    'movie': '🎬',
    'heart': '💊',
    'bolt': '⚡',
    'school': '📚',
    'home': '🏠',
    'category': '📦',
  };

  /// Returns the emoji for a given icon name. 
  /// If the iconName is already an emoji, it returns it as is.
  static String getEmoji(String iconName) {
    if (_iconToEmoji.containsKey(iconName)) {
      return _iconToEmoji[iconName]!;
    }
    // If it's already an emoji (saved by user), return it. 
    // Basic check: emojis are often multi-byte or outside standard ASCII.
    return iconName;
  }
}
