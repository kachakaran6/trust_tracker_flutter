// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Trust Tracker';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get analytics => 'Analytics';

  @override
  String get settings => 'Settings';

  @override
  String get totalBalance => 'Total Balance';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get addTransaction => 'Add Transaction';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get deleteTransaction => 'Delete Transaction';

  @override
  String get categories => 'Categories';

  @override
  String get manageCategories => 'Manage Categories';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi';

  @override
  String get gujarati => 'Gujarati';

  @override
  String goodMorning(Object name) {
    return 'Good Morning, $name';
  }

  @override
  String goodAfternoon(Object name) {
    return 'Good Afternoon, $name';
  }

  @override
  String goodEvening(Object name) {
    return 'Good Evening, $name';
  }

  @override
  String get noTransactions => 'No transactions found';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get amount => 'Amount';

  @override
  String get date => 'Date';

  @override
  String get note => 'Note';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get seeAll => 'See all';

  @override
  String get netBalance => 'Net Balance';

  @override
  String get thisMonth => 'This month';

  @override
  String get expenses => 'Expenses';

  @override
  String get addFirstTransaction => 'Add First Transaction';

  @override
  String get deleteConfirmationTitle => 'Delete Transaction?';

  @override
  String deleteConfirmationMessage(Object description) {
    return 'Are you sure you want to delete \"$description\"?\nThis action cannot be undone.';
  }

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get currency => 'Currency';

  @override
  String get transactions => 'Transactions';

  @override
  String get security => 'Security';

  @override
  String get support => 'Support';

  @override
  String get about => 'About';

  @override
  String get data => 'Data';

  @override
  String get expenseBreakdown => 'Expense Breakdown';

  @override
  String get incomeSources => 'Income Sources';

  @override
  String get trend6Month => '6-Month Trend';

  @override
  String get noTransactionsMonth => 'No transactions found for this month.';

  @override
  String noDataFor(Object label) {
    return 'No $label data to display';
  }

  @override
  String get newCategory => 'New Category';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get categoryName => 'Category name';

  @override
  String get icon => 'Icon';

  @override
  String get color => 'Color';

  @override
  String get createCategory => 'Create Category';

  @override
  String get update => 'Update';

  @override
  String get defaultLabel => 'Default';

  @override
  String get noCategoriesYet => 'No categories yet.';

  @override
  String get cantDeleteDefault => 'Can\'t delete default categories';

  @override
  String get type => 'Type';

  @override
  String get searchTransactions => 'Search transactions...';

  @override
  String get export => 'Export';

  @override
  String get add => 'Add';

  @override
  String get tapToEdit => 'Tap to edit  •  Use ✕ icon to delete';

  @override
  String get swipeToEdit => 'Swipe for Edit or Delete • Tap icon to Duplicate';

  @override
  String get today => 'Today';

  @override
  String get transactionDeleted => 'Transaction deleted';

  @override
  String get noTransactionsExport => 'No transactions to export';

  @override
  String get all => 'All';

  @override
  String get allCaps => 'ALL';

  @override
  String get setName => 'Set your name';

  @override
  String get yourName => 'Your name';

  @override
  String get transactionActionMode => 'Transaction Action Mode';

  @override
  String get tapModeDetails => 'Tap to edit • Delete icon visible';

  @override
  String get swipeModeDetails => 'Swipe right to delete • Swipe left to edit';

  @override
  String get swipeMode => 'Swipe Mode';

  @override
  String get tapMode => 'Tap Mode';

  @override
  String get setPin => 'Set PIN Lock';

  @override
  String get changePin => 'Change PIN';

  @override
  String get disablePin => 'Disable PIN Lock';

  @override
  String get disablePinConfirm => 'Disable PIN?';

  @override
  String get disablePinDetails =>
      'Your app will no longer require a PIN to open.';

  @override
  String get biometricUnlock => 'Biometric Unlock';

  @override
  String get rateApp => 'Rate App';

  @override
  String get shareApp => 'Share App';

  @override
  String get setMonthlyBudgets => 'Set Monthly Budgets';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get latestVersion => 'You are already on the latest version';

  @override
  String get termsPrivacy => 'Terms & Privacy';

  @override
  String get offlineNote =>
      'Offline & Private — Your data stays on your device';

  @override
  String get trustTrackerUser => 'Trust Tracker User';

  @override
  String get enterPinToDisable => 'Enter your PIN to disable security';

  @override
  String get incorrectPin => 'Incorrect PIN. Please try again.';

  @override
  String get incorrectPinDisable => 'Incorrect PIN. Security not disabled.';

  @override
  String get pinDisabledSuccess => 'Security PIN disabled';

  @override
  String get verifyCurrentPin => 'Verify Current PIN';

  @override
  String get enterExistingPin => 'Enter your existing PIN to continue';

  @override
  String get enterNewPin => 'Enter New PIN';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get chooseNewPin => 'Choose a new 4-digit PIN';

  @override
  String get protectFinancialData => 'This protects your financial data';

  @override
  String get reEnterPinToConfirm => 'Re-enter your PIN to confirm';

  @override
  String get pinChangedSuccess => 'PIN changed successfully';

  @override
  String get pinSetSuccess => 'PIN set successfully';

  @override
  String get pinsDontMatch => 'PINs don\'t match. Starting over.';

  @override
  String get overview => 'Overview';

  @override
  String get spending => 'Spending';

  @override
  String get trends => 'Trends';

  @override
  String get savingsRate => 'Savings Rate';

  @override
  String get dailySpending => 'Daily Spending';

  @override
  String get weekdayDistribution => 'Weekday Distribution';

  @override
  String get timeOfDay => 'Time of Day';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get evening => 'Evening';

  @override
  String get night => 'Night';

  @override
  String get topSpendingCategories => 'Top Spending Categories';

  @override
  String get intensity => 'Intensity';

  @override
  String get spendingIntensity => 'Spending Intensity';

  @override
  String get financialTimeline => 'Financial Timeline';

  @override
  String get categoryClusters => 'Category Clusters';

  @override
  String get mon => 'Mon';

  @override
  String get tue => 'Tue';

  @override
  String get wed => 'Wed';

  @override
  String get thu => 'Thu';

  @override
  String get fri => 'Fri';

  @override
  String get sat => 'Sat';

  @override
  String get sun => 'Sun';

  @override
  String get incomeVsExpense => 'Income vs Expense';

  @override
  String get netSavings => 'Net Savings';
}
