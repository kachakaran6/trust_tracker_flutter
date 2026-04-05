import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
    Locale('hi')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Trust Tracker'**
  String get appName;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get addTransaction;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// No description provided for @deleteTransaction.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction'**
  String get deleteTransaction;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategories;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @gujarati.
  ///
  /// In en, this message translates to:
  /// **'Gujarati'**
  String get gujarati;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning, {name}'**
  String goodMorning(Object name);

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon, {name}'**
  String goodAfternoon(Object name);

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening, {name}'**
  String goodEvening(Object name);

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get noTransactions;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @netBalance.
  ///
  /// In en, this message translates to:
  /// **'Net Balance'**
  String get netBalance;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @addFirstTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add First Transaction'**
  String get addFirstTransaction;

  /// No description provided for @deleteConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction?'**
  String get deleteConfirmationTitle;

  /// No description provided for @deleteConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{description}\"?\nThis action cannot be undone.'**
  String deleteConfirmationMessage(Object description);

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @expenseBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Expense Breakdown'**
  String get expenseBreakdown;

  /// No description provided for @incomeSources.
  ///
  /// In en, this message translates to:
  /// **'Income Sources'**
  String get incomeSources;

  /// No description provided for @trend6Month.
  ///
  /// In en, this message translates to:
  /// **'6-Month Trend'**
  String get trend6Month;

  /// No description provided for @noTransactionsMonth.
  ///
  /// In en, this message translates to:
  /// **'No transactions found for this month.'**
  String get noTransactionsMonth;

  /// No description provided for @noDataFor.
  ///
  /// In en, this message translates to:
  /// **'No {label} data to display'**
  String noDataFor(Object label);

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @createCategory.
  ///
  /// In en, this message translates to:
  /// **'Create Category'**
  String get createCategory;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet.'**
  String get noCategoriesYet;

  /// No description provided for @cantDeleteDefault.
  ///
  /// In en, this message translates to:
  /// **'Can\'t delete default categories'**
  String get cantDeleteDefault;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @searchTransactions.
  ///
  /// In en, this message translates to:
  /// **'Search transactions...'**
  String get searchTransactions;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @tapToEdit.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit  •  Use ✕ icon to delete'**
  String get tapToEdit;

  /// No description provided for @swipeToEdit.
  ///
  /// In en, this message translates to:
  /// **'Swipe for Edit or Delete • Tap icon to Duplicate'**
  String get swipeToEdit;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted'**
  String get transactionDeleted;

  /// No description provided for @noTransactionsExport.
  ///
  /// In en, this message translates to:
  /// **'No transactions to export'**
  String get noTransactionsExport;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allCaps.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get allCaps;

  /// No description provided for @setName.
  ///
  /// In en, this message translates to:
  /// **'Set your name'**
  String get setName;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @transactionActionMode.
  ///
  /// In en, this message translates to:
  /// **'Transaction Action Mode'**
  String get transactionActionMode;

  /// No description provided for @tapModeDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit • Delete icon visible'**
  String get tapModeDetails;

  /// No description provided for @swipeModeDetails.
  ///
  /// In en, this message translates to:
  /// **'Swipe right to delete • Swipe left to edit'**
  String get swipeModeDetails;

  /// No description provided for @swipeMode.
  ///
  /// In en, this message translates to:
  /// **'Swipe Mode'**
  String get swipeMode;

  /// No description provided for @tapMode.
  ///
  /// In en, this message translates to:
  /// **'Tap Mode'**
  String get tapMode;

  /// No description provided for @setPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get setPin;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @disablePin.
  ///
  /// In en, this message translates to:
  /// **'Disable PIN'**
  String get disablePin;

  /// No description provided for @disablePinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Disable PIN?'**
  String get disablePinConfirm;

  /// No description provided for @disablePinDetails.
  ///
  /// In en, this message translates to:
  /// **'Your app will no longer be protected by a PIN.'**
  String get disablePinDetails;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Biometric Unlock'**
  String get biometricUnlock;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// No description provided for @setMonthlyBudgets.
  ///
  /// In en, this message translates to:
  /// **'Set Monthly Budgets'**
  String get setMonthlyBudgets;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @latestVersion.
  ///
  /// In en, this message translates to:
  /// **'You are already on the latest version'**
  String get latestVersion;

  /// No description provided for @termsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Terms & Privacy'**
  String get termsPrivacy;

  /// No description provided for @offlineNote.
  ///
  /// In en, this message translates to:
  /// **'Offline & Private — Your data stays on your device'**
  String get offlineNote;

  /// No description provided for @trustTrackerUser.
  ///
  /// In en, this message translates to:
  /// **'Trust Tracker User'**
  String get trustTrackerUser;

  /// No description provided for @enterPinToDisable.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to disable security'**
  String get enterPinToDisable;

  /// No description provided for @incorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. Please try again.'**
  String get incorrectPin;

  /// No description provided for @incorrectPinDisable.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. Security not disabled.'**
  String get incorrectPinDisable;

  /// No description provided for @pinDisabledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Security PIN disabled'**
  String get pinDisabledSuccess;

  /// No description provided for @verifyCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Verify Current PIN'**
  String get verifyCurrentPin;

  /// No description provided for @enterExistingPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your existing PIN to continue'**
  String get enterExistingPin;

  /// No description provided for @enterNewPin.
  ///
  /// In en, this message translates to:
  /// **'Enter New PIN'**
  String get enterNewPin;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get confirmPin;

  /// No description provided for @chooseNewPin.
  ///
  /// In en, this message translates to:
  /// **'Choose a new 4-digit PIN'**
  String get chooseNewPin;

  /// No description provided for @protectFinancialData.
  ///
  /// In en, this message translates to:
  /// **'This protects your financial data'**
  String get protectFinancialData;

  /// No description provided for @reEnterPinToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your PIN to confirm'**
  String get reEnterPinToConfirm;

  /// No description provided for @pinChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN changed successfully'**
  String get pinChangedSuccess;

  /// No description provided for @pinSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN set successfully'**
  String get pinSetSuccess;

  /// No description provided for @pinsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match. Starting over.'**
  String get pinsDontMatch;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @spending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get spending;

  /// No description provided for @trends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get trends;

  /// No description provided for @savingsRate.
  ///
  /// In en, this message translates to:
  /// **'Savings Rate'**
  String get savingsRate;

  /// No description provided for @dailySpending.
  ///
  /// In en, this message translates to:
  /// **'Daily Spending'**
  String get dailySpending;

  /// No description provided for @weekdayDistribution.
  ///
  /// In en, this message translates to:
  /// **'Weekday Distribution'**
  String get weekdayDistribution;

  /// No description provided for @timeOfDay.
  ///
  /// In en, this message translates to:
  /// **'Time of Day'**
  String get timeOfDay;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get night;

  /// No description provided for @topSpendingCategories.
  ///
  /// In en, this message translates to:
  /// **'Top Spending Categories'**
  String get topSpendingCategories;

  /// No description provided for @intensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get intensity;

  /// No description provided for @spendingIntensity.
  ///
  /// In en, this message translates to:
  /// **'Spending Intensity'**
  String get spendingIntensity;

  /// No description provided for @financialTimeline.
  ///
  /// In en, this message translates to:
  /// **'Financial Timeline'**
  String get financialTimeline;

  /// No description provided for @categoryClusters.
  ///
  /// In en, this message translates to:
  /// **'Category Clusters'**
  String get categoryClusters;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @incomeVsExpense.
  ///
  /// In en, this message translates to:
  /// **'Income vs Expense'**
  String get incomeVsExpense;

  /// No description provided for @netSavings.
  ///
  /// In en, this message translates to:
  /// **'Net Savings'**
  String get netSavings;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @exitApplication.
  ///
  /// In en, this message translates to:
  /// **'Exit Application'**
  String get exitApplication;

  /// No description provided for @exitConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to close the application? Any unsaved changes might be lost.'**
  String get exitConfirmMessage;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @builtWithLove.
  ///
  /// In en, this message translates to:
  /// **'Built with ❤️ by {name}'**
  String builtWithLove(Object name);

  /// No description provided for @budgetFor.
  ///
  /// In en, this message translates to:
  /// **'Budget for {name}'**
  String budgetFor(Object name);

  /// No description provided for @monthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit'**
  String get monthlyLimit;

  /// No description provided for @removeBudget.
  ///
  /// In en, this message translates to:
  /// **'Remove budget'**
  String get removeBudget;

  /// No description provided for @setBudget.
  ///
  /// In en, this message translates to:
  /// **'Set Budget'**
  String get setBudget;

  /// No description provided for @updateBudget.
  ///
  /// In en, this message translates to:
  /// **'Update Budget'**
  String get updateBudget;

  /// No description provided for @tapToSetBudget.
  ///
  /// In en, this message translates to:
  /// **'Tap any category below to set a monthly budget limit.'**
  String get tapToSetBudget;

  /// No description provided for @monthlyBudgetOverview.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY BUDGET OVERVIEW'**
  String get monthlyBudgetOverview;

  /// No description provided for @ofAmount.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String ofAmount(Object amount);

  /// No description provided for @overBudgetBy.
  ///
  /// In en, this message translates to:
  /// **'🚨 Over budget by {amount}'**
  String overBudgetBy(Object amount);

  /// No description provided for @remainingAmount.
  ///
  /// In en, this message translates to:
  /// **'✅ {amount} remaining'**
  String remainingAmount(Object amount);

  /// No description provided for @over.
  ///
  /// In en, this message translates to:
  /// **'OVER'**
  String get over;

  /// No description provided for @spentAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} spent'**
  String spentAmount(Object amount);

  /// No description provided for @noBudgetSet.
  ///
  /// In en, this message translates to:
  /// **'No budget set — tap \"SET\" to add a limit'**
  String get noBudgetSet;

  /// No description provided for @filterTransactions.
  ///
  /// In en, this message translates to:
  /// **'Filter Transactions'**
  String get filterTransactions;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @selectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get selectDateRange;

  /// No description provided for @errorLoadingCategories.
  ///
  /// In en, this message translates to:
  /// **'Error loading categories'**
  String get errorLoadingCategories;

  /// No description provided for @applyFilter.
  ///
  /// In en, this message translates to:
  /// **'Apply Filter'**
  String get applyFilter;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @whatWasThisFor.
  ///
  /// In en, this message translates to:
  /// **'What was this for?'**
  String get whatWasThisFor;

  /// No description provided for @enterDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a description'**
  String get enterDescription;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @budgetLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetLabel;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @exportDataJson.
  ///
  /// In en, this message translates to:
  /// **'Export Data (JSON)'**
  String get exportDataJson;

  /// No description provided for @importDataJson.
  ///
  /// In en, this message translates to:
  /// **'Import Data (JSON)'**
  String get importDataJson;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// No description provided for @setPinBeforeBiometric.
  ///
  /// In en, this message translates to:
  /// **'Please set a PIN before enabling biometric security'**
  String get setPinBeforeBiometric;

  /// No description provided for @shareSubject.
  ///
  /// In en, this message translates to:
  /// **'Trust Tracker – Smart Expense Tracker'**
  String get shareSubject;

  /// No description provided for @shareMessage.
  ///
  /// In en, this message translates to:
  /// **'Take control of your personal finances with Trust Tracker.\n\nTrust Tracker is a private, offline-first expense tracker designed to help you manage your income, expenses, and budgets with ease.\n\nKey Features:\n• Simple expense and income tracking\n• Budget management and financial insights\n• Secure PIN and biometric protection\n• Completely offline and privacy focused\n• Clean and easy-to-use interface\n\nDownload the app from the Google Play Store:\nhttps://play.google.com/store/apps/details?id=com.trusttracker.trust_tracker_flutter\n\nYour feedback and support would mean a lot.'**
  String get shareMessage;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appTheme;

  /// No description provided for @selectAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Select Accent Color'**
  String get selectAccentColor;

  /// No description provided for @selectFormat.
  ///
  /// In en, this message translates to:
  /// **'SELECT FORMAT'**
  String get selectFormat;

  /// No description provided for @pdfReport.
  ///
  /// In en, this message translates to:
  /// **'PDF Report'**
  String get pdfReport;

  /// No description provided for @pdfReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Formatted financial report'**
  String get pdfReportDesc;

  /// No description provided for @excelExport.
  ///
  /// In en, this message translates to:
  /// **'Excel Export'**
  String get excelExport;

  /// No description provided for @excelExportDesc.
  ///
  /// In en, this message translates to:
  /// **'For spreadsheet analysis'**
  String get excelExportDesc;

  /// No description provided for @dateRangeCaps.
  ///
  /// In en, this message translates to:
  /// **'DATE RANGE'**
  String get dateRangeCaps;

  /// No description provided for @generateExport.
  ///
  /// In en, this message translates to:
  /// **'Generate Export'**
  String get generateExport;

  /// No description provided for @exportTransactions.
  ///
  /// In en, this message translates to:
  /// **'Export Transactions'**
  String get exportTransactions;

  /// No description provided for @exportDesc.
  ///
  /// In en, this message translates to:
  /// **'Save or share your financial data'**
  String get exportDesc;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get lastMonth;

  /// No description provided for @threeMonths.
  ///
  /// In en, this message translates to:
  /// **'3 Months'**
  String get threeMonths;

  /// No description provided for @allHistory.
  ///
  /// In en, this message translates to:
  /// **'All History'**
  String get allHistory;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @pleaseSelectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Please select a date range'**
  String get pleaseSelectDateRange;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get user;

  /// No description provided for @categoriesCaps.
  ///
  /// In en, this message translates to:
  /// **'CATEGORIES'**
  String get categoriesCaps;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose Avatar'**
  String get chooseAvatar;

  /// No description provided for @resetAvatar.
  ///
  /// In en, this message translates to:
  /// **'Reset Avatar'**
  String get resetAvatar;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
