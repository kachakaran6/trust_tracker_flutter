// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Gujarati (`gu`).
class AppLocalizationsGu extends AppLocalizations {
  AppLocalizationsGu([String locale = 'gu']) : super(locale);

  @override
  String get appName => 'ટ્રસ્ટ ટ્રેકર';

  @override
  String get dashboard => 'ડેશબોર્ડ';

  @override
  String get analytics => 'એનાલિટિક્સ';

  @override
  String get settings => 'સેટિંગ્સ';

  @override
  String get totalBalance => 'કુલ બેલેન્સ';

  @override
  String get income => 'આવક';

  @override
  String get expense => 'ખર્ચ';

  @override
  String get recentTransactions => 'તાજેતરના વ્યવહારો';

  @override
  String get addTransaction => 'વ્યવહાર ઉમેરો';

  @override
  String get editTransaction => 'વ્યવહાર સુધારો';

  @override
  String get deleteTransaction => 'વ્યવહાર કાઢી નાખો';

  @override
  String get categories => 'કેટેગરીઝ';

  @override
  String get manageCategories => 'કેટેગરીઝ મેનેજ કરો';

  @override
  String get language => 'ભાષા';

  @override
  String get english => 'અંગ્રેજી';

  @override
  String get hindi => 'હિન્દી';

  @override
  String get gujarati => 'ગુજરાતી';

  @override
  String goodMorning(Object name) {
    return 'શુભ સવાર, $name';
  }

  @override
  String goodAfternoon(Object name) {
    return 'શુભ બપોર, $name';
  }

  @override
  String goodEvening(Object name) {
    return 'શુભ સાંજ, $name';
  }

  @override
  String get noTransactions => 'કોઈ વ્યવહાર મળ્યા નથી';

  @override
  String get selectCategory => 'કેટેગરી પસંદ કરો';

  @override
  String get amount => 'રકમ';

  @override
  String get date => 'તારીખ';

  @override
  String get note => 'નોંધ';

  @override
  String get save => 'સાચવો';

  @override
  String get cancel => 'રદ કરો';

  @override
  String get delete => 'કાઢી નાખો';

  @override
  String get edit => 'સુધારો';

  @override
  String get welcomeBack => 'સ્વાગત છે';

  @override
  String get seeAll => 'બધું જુઓ';

  @override
  String get netBalance => 'કુલ બેલેન્સ';

  @override
  String get thisMonth => 'આ મહિને';

  @override
  String get expenses => 'ખર્ચાઓ';

  @override
  String get addFirstTransaction => 'પહેલો વ્યવહાર ઉમેરો';

  @override
  String get deleteConfirmationTitle => 'વ્યવહાર કાઢી નાખવો?';

  @override
  String deleteConfirmationMessage(Object description) {
    return 'શું તમે ખરેખર \"$description\" ને કાઢી નાખવા માંગો છો?\nઆ પ્રક્રિયા પાછી ખેંચી શકાશે નહીં.';
  }

  @override
  String get noTransactionsYet => 'હજુ સુધી કોઈ વ્યવહાર નથી';

  @override
  String get uncategorized => 'અવર્ગીકૃત';

  @override
  String get appearance => 'દેખાવ';

  @override
  String get darkMode => 'ડાર્ક મોડ';

  @override
  String get currency => 'ચલણ';

  @override
  String get transactions => 'વ્યવહારો';

  @override
  String get security => 'સુરક્ષા';

  @override
  String get support => 'સપોર્ટ';

  @override
  String get about => 'વિશે';

  @override
  String get data => 'ડેટા';

  @override
  String get expenseBreakdown => 'ખર્ચનું વિવરણ';

  @override
  String get incomeSources => 'આવકના સ્ત્રોતો';

  @override
  String get trend6Month => '6-મહિનાનો ટ્રેન્ડ';

  @override
  String get noTransactionsMonth => 'આ મહિના માટે કોઈ વ્યવહાર મળ્યા નથી.';

  @override
  String noDataFor(Object label) {
    return 'પ્રદર્શિત કરવા માટે કોઈ $label ડેટા નથી';
  }

  @override
  String get newCategory => 'નવી કેટેગરી';

  @override
  String get editCategory => 'કેટેગરી સુધારો';

  @override
  String get categoryName => 'કેટેગરીનું નામ';

  @override
  String get icon => 'આઈકન';

  @override
  String get color => 'રંગ';

  @override
  String get createCategory => 'કેટેગરી બનાવો';

  @override
  String get update => 'અપડેટ કરો';

  @override
  String get defaultLabel => 'ડિફોલ્ટ';

  @override
  String get noCategoriesYet => 'હજુ સુધી કોઈ કેટેગરી નથી.';

  @override
  String get cantDeleteDefault => 'ડિફોલ્ટ કેટેગરીઝ કાઢી શકાતી નથી';

  @override
  String get type => 'પ્રકાર';

  @override
  String get searchTransactions => 'વ્યવહારો શોધો...';

  @override
  String get export => 'નિકાસ કરો';

  @override
  String get add => 'ઉમેરો';

  @override
  String get tapToEdit =>
      'સુધારવા માટે ટેપ કરો • કાઢી નાખવા માટે ✕ આઈકનનો ઉપયોગ કરો';

  @override
  String get swipeToEdit =>
      'સુધારવા અથવા કાઢી નાખવા માટે સ્વાઇપ કરો • ડુપ્લિકેટ કરવા માટે આઈકન ટેપ કરો';

  @override
  String get today => 'આજે';

  @override
  String get transactionDeleted => 'વ્યવહાર કાઢી નાખ્યો';

  @override
  String get noTransactionsExport => 'નિકાસ કરવા માટે કોઈ વ્યવહાર નથી';

  @override
  String get all => 'બધા';

  @override
  String get allCaps => 'તમામ';

  @override
  String get setName => 'તમારું નામ સેટ કરો';

  @override
  String get yourName => 'તમારું નામ';

  @override
  String get transactionActionMode => 'વ્યવહાર એક્શન મોડ';

  @override
  String get tapModeDetails =>
      'સુધારવા માટે ટેપ કરો • કાઢી નાખવાનું આઈકન દેખાશે';

  @override
  String get swipeModeDetails =>
      'કાઢી નાખવા માટે જમણે સ્વાઇપ કરો • સુધારવા માટે ડાબે સ્વાઇપ કરો';

  @override
  String get swipeMode => 'સ્વાઇપ મોડ';

  @override
  String get tapMode => 'ટેપ મોડ';

  @override
  String get setPin => 'પિન લોક સેટ કરો';

  @override
  String get changePin => 'પિન બદલો';

  @override
  String get disablePin => 'પિન લોક અક્ષમ કરો';

  @override
  String get disablePinConfirm => 'પિન અક્ષમ કરો?';

  @override
  String get disablePinDetails =>
      'તમારી એપ્લિકેશન ખોલવા માટે હવે પિનની જરૂર રહેશે નહીં.';

  @override
  String get biometricUnlock => 'બાયોમેટ્રિક અનલોક';

  @override
  String get rateApp => 'એપ્લિકેશનને રેટ કરો';

  @override
  String get shareApp => 'એપ્લિકેશન શેર કરો';

  @override
  String get setMonthlyBudgets => 'માસિક બજેટ સેટ કરો';

  @override
  String get checkForUpdates => 'અપડેટ્સ માટે તપાસો';

  @override
  String get latestVersion => 'તમે પહેલાથી જ નવીનતમ સંસ્કરણ પર છો';

  @override
  String get termsPrivacy => 'શરતો અને ગોપનીયતા';

  @override
  String get offlineNote =>
      'ઓફલાઇન અને ખાનગી — તમારો ડેટા તમારા ઉપકરણ પર રહે છે';

  @override
  String get trustTrackerUser => 'ટ્રસ્ટ ટ્રેકર વપરાશકર્તા';

  @override
  String get enterPinToDisable => 'સુરક્ષા અક્ષમ કરવા માટે તમારો પિન દાખલ કરો';

  @override
  String get incorrectPin => 'ખોટો પિન. કૃપા કરીને ફરી પ્રયાસ કરો.';

  @override
  String get incorrectPinDisable => 'ખોટો પિન. સુરક્ષા અક્ષમ કરવામાં આવી નથી.';

  @override
  String get pinDisabledSuccess => 'સુરક્ષા પિન અક્ષમ કરવામાં આવ્યો';

  @override
  String get verifyCurrentPin => 'વર્તમાન પિન ચકાસો';

  @override
  String get enterExistingPin => 'ચાલુ રાખવા માટે તમારો હાલનો પિન દાખલ કરો';

  @override
  String get enterNewPin => 'નવો પિન દાખલ કરો';

  @override
  String get confirmPin => 'પિન કન્ફર્મ કરો';

  @override
  String get chooseNewPin => 'નવો 4-અંકનો પિન પસંદ કરો';

  @override
  String get protectFinancialData => 'આ તમારા નાણાકીય ડેટાનું રક્ષણ કરે છે';

  @override
  String get reEnterPinToConfirm => 'પુષ્ટિ કરવા માટે તમારો પિન ફરીથી દાખલ કરો';

  @override
  String get pinChangedSuccess => 'પિન સફળતાપૂર્વક બદલાયો';

  @override
  String get pinSetSuccess => 'પિન સફળતાપૂર્વક સેટ થયો';

  @override
  String get pinsDontMatch => 'પિન મેળ ખાતા નથી. ફરીથી શરૂ થાય છે।';

  @override
  String get overview => 'ઝાંખી';

  @override
  String get spending => 'ખર્ચ';

  @override
  String get trends => 'ટ્રેન્ડ્સ';

  @override
  String get savingsRate => 'બચત દર';

  @override
  String get dailySpending => 'દૈનિક ખર્ચ';

  @override
  String get weekdayDistribution => 'સાપ્તાહિક વિતરણ';

  @override
  String get timeOfDay => 'દિવસનો સમય';

  @override
  String get morning => 'સવાર';

  @override
  String get afternoon => 'બપોર';

  @override
  String get evening => 'સાંજ';

  @override
  String get night => 'રાત';

  @override
  String get topSpendingCategories => 'ટોચની ખર્ચ શ્રેણીઓ';

  @override
  String get intensity => 'તીવ્રતા';

  @override
  String get spendingIntensity => 'ખર્ચની તીવ્રતા';

  @override
  String get financialTimeline => 'નાણાકીય સમયરેખા';

  @override
  String get categoryClusters => 'શ્રેણી જૂથો';

  @override
  String get mon => 'સોમ';

  @override
  String get tue => 'મંગળ';

  @override
  String get wed => 'બુધ';

  @override
  String get thu => 'ગુરુ';

  @override
  String get fri => 'શુક્ર';

  @override
  String get sat => 'શનિ';

  @override
  String get sun => 'રવિ';

  @override
  String get incomeVsExpense => 'આવક વિ ખર્ચ';

  @override
  String get netSavings => 'ચોખ્ખી બચત';
}
