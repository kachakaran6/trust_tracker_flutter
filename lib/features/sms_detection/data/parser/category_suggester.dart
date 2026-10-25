import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';

class CategorySuggester {
  static final Map<String, List<String>> _expenseKeywords = {
    'Food & Dining': [
      'swiggy', 'zomato', 'mcdonald', 'burger', 'pizza', 'domino', 'starbucks',
      'cafe', 'restaurant', 'dine', 'food', 'blinkit', 'zepto', 'instamart',
      'bakery', 'kfc', 'subway', 'chai', 'tea'
    ],
    'Transport': [
      'uber', 'ola', 'rapido', 'metro', 'petrol', 'diesel', 'fuel', 'indian oil',
      'bharat petroleum', 'hpcl', 'shell', 'irctc', 'train', 'flight', 'makemytrip',
      'indigo', 'redbus', 'fastag', 'toll', 'parking'
    ],
    'Shopping': [
      'amazon', 'flipkart', 'myntra', 'meesho', 'ajio', 'zara', 'h&m', 'nykaa',
      'retail', 'store', 'mart', 'dmart', 'reliance', 'croma', 'ikea', 'decathlon',
      'market', 'supermarket', 'mall'
    ],
    'Entertainment': [
      'netflix', 'spotify', 'prime video', 'hotstar', 'pvr', 'inox', 'cinepolis',
      'bookmyshow', 'steam', 'playstation', 'game', 'youtube', 'apple media',
      'disney', 'movie', 'theatre'
    ],
    'Health': [
      'apollo', 'medplus', 'pharmacy', 'hospital', 'clinic', '1mg', 'netmeds',
      'doctor', 'diagnostic', 'pathology', 'medical', 'dental', 'chemist'
    ],
    'Utilities': [
      'electricity', 'bescom', 'tneb', 'msedcl', 'adani', 'water', 'gas',
      'airtel', 'jio', 'vi', 'vodafone', 'broadband', 'act fibernet', 'dth',
      'tatasky', 'recharge', 'bill desk'
    ],
    'Education': [
      'school', 'college', 'university', 'coursera', 'udemy', 'tuition', 'class',
      'fees', 'coaching', 'academy', 'institute'
    ],
    'Rent/Housing': [
      'rent', 'maintenance', 'society', 'landlord', 'housing', 'flat', 'apartment'
    ],
    'EMI Payments': [
      'emi', 'loan', 'bajaj finance', 'home loan', 'car loan', 'personal loan',
      'equitas', 'hdfc credila', 'hdbfs'
    ],
  };

  static final Map<String, List<String>> _incomeKeywords = {
    'Salary': [
      'salary', 'payroll', 'wages', 'stipend', 'employer', 'infosys', 'tcs',
      'wipro', 'google', 'microsoft', 'accenture'
    ],
    'Investment': [
      'dividend', 'groww', 'zerodha', 'upstox', 'mutual fund', 'sip', 'nse',
      'bse', 'sebi', 'interest credited', 'fd interest'
    ],
    'Freelance': [
      'upwork', 'fiverr', 'consulting', 'client payment', 'freelance', 'contract'
    ],
  };

  static String suggestCategory({
    required TransactionType type,
    String? merchant,
    String? body,
  }) {
    final combined = '${merchant ?? ''} ${body ?? ''}'.toLowerCase();

    if (type == TransactionType.income) {
      for (final entry in _incomeKeywords.entries) {
        for (final kw in entry.value) {
          if (combined.contains(kw)) {
            return entry.key;
          }
        }
      }
      return 'Other Income';
    } else {
      for (final entry in _expenseKeywords.entries) {
        for (final kw in entry.value) {
          if (combined.contains(kw)) {
            return entry.key;
          }
        }
      }
      return 'Shopping'; // General default expense category
    }
  }
}
