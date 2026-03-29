// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'ट्रस्ट ट्रैकर';

  @override
  String get dashboard => 'डैशबोर्ड';

  @override
  String get analytics => 'एनालिटिक्स';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get totalBalance => 'कुल शेष';

  @override
  String get income => 'आय';

  @override
  String get expense => 'खर्च';

  @override
  String get recentTransactions => 'हाल के लेनदेन';

  @override
  String get addTransaction => 'लेनदेन जोड़ें';

  @override
  String get editTransaction => 'लेनदेन संपादित करें';

  @override
  String get deleteTransaction => 'लेनदेन हटाएं';

  @override
  String get categories => 'श्रेणियाँ';

  @override
  String get manageCategories => 'श्रेणियों का प्रबंधन करें';

  @override
  String get language => 'भाषा';

  @override
  String get english => 'अंग्रेज़ी';

  @override
  String get hindi => 'हिन्दी';

  @override
  String get gujarati => 'गुजराती';

  @override
  String goodMorning(Object name) {
    return 'शुभ प्रभात, $name';
  }

  @override
  String goodAfternoon(Object name) {
    return 'नमस्कार, $name';
  }

  @override
  String goodEvening(Object name) {
    return 'शुभ संध्या, $name';
  }

  @override
  String get noTransactions => 'कोई लेनदेन नहीं मिला';

  @override
  String get selectCategory => 'श्रेणी चुनें';

  @override
  String get amount => 'राशि';

  @override
  String get date => 'तारीख';

  @override
  String get note => 'नोट';

  @override
  String get save => 'सहेजें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएं';

  @override
  String get edit => 'संपादित करें';

  @override
  String get welcomeBack => 'वापसी पर स्वागत है';

  @override
  String get seeAll => 'सभी देखें';

  @override
  String get netBalance => 'कुल शेष';

  @override
  String get thisMonth => 'इस महीने';

  @override
  String get expenses => 'खर्चे';

  @override
  String get addFirstTransaction => 'पहला लेनदेन जोड़ें';

  @override
  String get deleteConfirmationTitle => 'लेनदेन हटाएं?';

  @override
  String deleteConfirmationMessage(Object description) {
    return 'क्या आप वाकई \"$description\" को हटाना चाहते हैं?\nयह क्रिया पूर्ववत नहीं की जा सकती।';
  }

  @override
  String get noTransactionsYet => 'अभी तक कोई लेनदेन नहीं';

  @override
  String get uncategorized => 'अवर्गीकृत';

  @override
  String get appearance => 'दिखावट';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get currency => 'मुद्रा';

  @override
  String get transactions => 'लेनदेन';

  @override
  String get security => 'सुरक्षा';

  @override
  String get support => 'सहायता';

  @override
  String get about => 'विवरण';

  @override
  String get data => 'डेटा';

  @override
  String get expenseBreakdown => 'व्यय विवरण';

  @override
  String get incomeSources => 'आय के स्रोत';

  @override
  String get trend6Month => '6 महीने का रुझान';

  @override
  String get noTransactionsMonth => 'इस महीने के लिए कोई लेनदेन नहीं मिला।';

  @override
  String noDataFor(Object label) {
    return 'दिखाने के लिए कोई $label डेटा नहीं है';
  }

  @override
  String get newCategory => 'नई श्रेणी';

  @override
  String get editCategory => 'श्रेणी संपादित करें';

  @override
  String get categoryName => 'श्रेणी का नाम';

  @override
  String get icon => 'आइकन';

  @override
  String get color => 'रंग';

  @override
  String get createCategory => 'श्रेणी बनाएं';

  @override
  String get update => 'अपडेट करें';

  @override
  String get defaultLabel => 'डिफ़ॉल्ट';

  @override
  String get noCategoriesYet => 'अभी तक कोई श्रेणियां नहीं हैं।';

  @override
  String get cantDeleteDefault => 'डिफ़ॉल्ट श्रेणियों को हटाया नहीं जा सकता';

  @override
  String get type => 'प्रकार';

  @override
  String get searchTransactions => 'लेनदेन खोजें...';

  @override
  String get export => 'निर्यात करें';

  @override
  String get add => 'जोड़ें';

  @override
  String get tapToEdit =>
      'संपादित करने के लिए टैप करें • हटाने के लिए ✕ आइकन का उपयोग करें';

  @override
  String get swipeToEdit =>
      'संपादित करने या हटाने के लिए स्वाइप करें • डुप्लिकेट करने के लिए आइकन टैप करें';

  @override
  String get today => 'आज';

  @override
  String get transactionDeleted => 'लेनदेन हटा दिया गया';

  @override
  String get noTransactionsExport => 'निर्यात करने के लिए कोई लेनदेन नहीं';

  @override
  String get all => 'सभी';

  @override
  String get allCaps => 'सब';

  @override
  String get setName => 'अपना नाम सेट करें';

  @override
  String get yourName => 'आपका नाम';

  @override
  String get transactionActionMode => 'लेनदेन एक्शन मोड';

  @override
  String get tapModeDetails =>
      'संपादित करने के लिए टैप करें • हटाए जाने वाला आइकन दिखाई देगा';

  @override
  String get swipeModeDetails =>
      'हटाने के लिए दाएं स्वाइप करें • संपादित करने के लिए बाएं स्वाइप करें';

  @override
  String get swipeMode => 'स्वाइप मोड';

  @override
  String get tapMode => 'टैप मोड';

  @override
  String get setPin => 'पिन सेट करें';

  @override
  String get changePin => 'पिन बदलें';

  @override
  String get disablePin => 'पिन अक्षम करें';

  @override
  String get disablePinConfirm => 'पिन अक्षम करें?';

  @override
  String get disablePinDetails => 'आपका ऐप अब पिन द्वारा सुरक्षित नहीं रहेगा।';

  @override
  String get biometricUnlock => 'बायोमेट्रिक अनलॉक';

  @override
  String get rateApp => 'ऐप को रेट करें';

  @override
  String get shareApp => 'एप्लिकेशन साझा करें';

  @override
  String get setMonthlyBudgets => 'मासिक बजट सेट करें';

  @override
  String get checkForUpdates => 'अपडेट की जांच करें';

  @override
  String get latestVersion => 'आप पहले से ही नवीनतम संस्करण पर हैं';

  @override
  String get termsPrivacy => 'नियम और गोपनीयता';

  @override
  String get offlineNote => 'ऑफलाइन और निजी — आपका डेटा आपके डिवाइस पर रहता है';

  @override
  String get trustTrackerUser => 'ट्रस्ट ट्रैकर उपयोगकर्ता';

  @override
  String get enterPinToDisable => 'सुरक्षा बंद करने के लिए अपना पिन दर्ज करें';

  @override
  String get incorrectPin => 'गलत पिन। कृपया पुन: प्रयास करें।';

  @override
  String get incorrectPinDisable => 'गलत पिन। सुरक्षा बंद नहीं की गई।';

  @override
  String get pinDisabledSuccess => 'सुरक्षा पिन बंद कर दिया गया';

  @override
  String get verifyCurrentPin => 'वर्तमान पिन सत्यापित करें';

  @override
  String get enterExistingPin => 'जारी रखने के लिए अपना मौजूदा पिन दर्ज करें';

  @override
  String get enterNewPin => 'नया पिन दर्ज करें';

  @override
  String get confirmPin => 'पिन की पुष्टि करें';

  @override
  String get chooseNewPin => 'एक नया 4-अंकीय पिन चुनें';

  @override
  String get protectFinancialData => 'यह आपके वित्तीय डेटा की सुरक्षा करता है';

  @override
  String get reEnterPinToConfirm =>
      'पुष्टि करने के लिए अपना पिन पुनः दर्ज करें';

  @override
  String get pinChangedSuccess => 'पिन सफलतापूर्वक बदल गया';

  @override
  String get pinSetSuccess => 'पिन सफलतापूर्वक सेट हो गया';

  @override
  String get pinsDontMatch => 'पिन मेल नहीं खाते। फिर से शुरू हो रहा है।';

  @override
  String get overview => 'अवलोकन';

  @override
  String get spending => 'खर्च';

  @override
  String get trends => 'रुझान';

  @override
  String get savingsRate => 'बचत दर';

  @override
  String get dailySpending => 'दैनिक खर्च';

  @override
  String get weekdayDistribution => 'साप्ताहिक वितरण';

  @override
  String get timeOfDay => 'दिन का समय';

  @override
  String get morning => 'सुबह';

  @override
  String get afternoon => 'दोपहर';

  @override
  String get evening => 'शाम';

  @override
  String get night => 'रात';

  @override
  String get topSpendingCategories => 'शीर्ष खर्च श्रेणियाँ';

  @override
  String get intensity => 'तीव्रता';

  @override
  String get spendingIntensity => 'खर्च की तीव्रता';

  @override
  String get financialTimeline => 'वित्तीय समयरेखा';

  @override
  String get categoryClusters => 'श्रेणी समूह';

  @override
  String get mon => 'सोम';

  @override
  String get tue => 'मंगल';

  @override
  String get wed => 'बुध';

  @override
  String get thu => 'गुरु';

  @override
  String get fri => 'शुक्र';

  @override
  String get sat => 'शनि';

  @override
  String get sun => 'रवि';

  @override
  String get incomeVsExpense => 'आय बनाम खर्च';

  @override
  String get netSavings => 'शुद्ध बचत';

  @override
  String get activity => 'गतिविधि';

  @override
  String get home => 'होम';

  @override
  String get exitApplication => 'ऐप से बाहर निकलें';

  @override
  String get exitConfirmMessage =>
      'क्या आप वाकई ऐप बंद करना चाहते हैं? कोई भी बिना सहेजा गया डेटा खो सकता है।';

  @override
  String get exit => 'बाहर निकलें';

  @override
  String builtWithLove(Object name) {
    return '$name द्वारा ❤️ के साथ बनाया गया';
  }

  @override
  String budgetFor(Object name) {
    return '$name के लिए बजट';
  }

  @override
  String get monthlyLimit => 'मासिक सीमा';

  @override
  String get removeBudget => 'बजट हटाएं';

  @override
  String get setBudget => 'बजट सेट करें';

  @override
  String get updateBudget => 'बजट अपडेट करें';

  @override
  String get tapToSetBudget =>
      'मासिक बजट सीमा सेट करने के लिए नीचे किसी भी श्रेणी पर टैप करें।';

  @override
  String get monthlyBudgetOverview => 'मासिक बजट अवलोकन';

  @override
  String ofAmount(Object amount) {
    return '$amount में से';
  }

  @override
  String overBudgetBy(Object amount) {
    return '🚨 बजट से $amount अधिक';
  }

  @override
  String remainingAmount(Object amount) {
    return '✅ $amount शेष है';
  }

  @override
  String get over => 'ज्यादा';

  @override
  String spentAmount(Object amount) {
    return '$amount खर्च';
  }

  @override
  String get noBudgetSet =>
      'कोई बजट सेट नहीं है — सीमा जोड़ने के लिए \"SET\" पर टैप करें';

  @override
  String get filterTransactions => 'लेनदेन फ़िल्टर करें';

  @override
  String get reset => 'रीसेट';

  @override
  String get sortBy => 'इसके अनुसार क्रमबद्ध करें';

  @override
  String get ascending => 'बढ़ते क्रम';

  @override
  String get descending => 'घटते क्रम';

  @override
  String get selectDateRange => 'तिथि सीमा चुनें';

  @override
  String get errorLoadingCategories => 'श्रेणियां लोड करने में त्रुटि';

  @override
  String get applyFilter => 'फ़िल्टर लागू करें';

  @override
  String get description => 'विवरण';

  @override
  String get whatWasThisFor => 'यह किस लिए था?';

  @override
  String get enterDescription => 'विवरण दर्ज करें';

  @override
  String get noResultsFound => 'कोई परिणाम नहीं मिला';

  @override
  String get error => 'त्रुटि';

  @override
  String get budgetLabel => 'बजट';

  @override
  String get dataManagement => 'डेटा प्रबंधन';

  @override
  String get exportDataJson => 'डेटा निर्यात करें (JSON)';

  @override
  String get importDataJson => 'डेटा आयात करें (JSON)';

  @override
  String get on => 'चालू';

  @override
  String get off => 'बंद';

  @override
  String get setPinBeforeBiometric =>
      'बायोमेट्रिक सुरक्षा सक्षम करने से पहले कृपया एक पिन सेट करें';

  @override
  String get shareSubject => 'ट्रस्ट ट्रैकर - स्मार्ट मनी मैनेजर';

  @override
  String get shareMessage =>
      'ट्रस्ट ट्रैकर के साथ अपने व्यक्तिगत वित्त का नियंत्रण लें।\n\nट्रस्ट ट्रैकर एक निजी, ऑफलाइन-प्रथम व्यय ट्रैकर है जिसे आपकी आय, व्यय और बजट को आसानी से प्रबंधित करने में मदद करने के लिए डिज़ाइन किया गया है।\n\nमुख्य विशेषताएं:\n• सरल व्यय और आय ट्रैकिंग\n• बजट प्रबंधन और वित्तीय अंतर्दृष्टि\n• सुरक्षित पिन और बायोमेट्रिक सुरक्षा\n• पूरी तरह से ऑफलाइन और गोपनीयता आधारित\n• साफ और उपयोग में आसान इंटरफेस\n\nGoogle Play Store से ऐप डाउनलोड करें:\nhttps://play.google.com/store/apps/details?id=com.trusttracker.trust_tracker_flutter\n\nआपकी प्रतिक्रिया और समर्थन बहुत मायने रखता है।';

  @override
  String get appTheme => 'ऐप थीम';

  @override
  String get selectAccentColor => 'एक्सेंट रंग चुनें';

  @override
  String get selectFormat => 'फॉर्मेट चुनें';

  @override
  String get pdfReport => 'PDF रिपोर्ट';

  @override
  String get pdfReportDesc => 'वित्तीय रिपोर्ट';

  @override
  String get excelExport => 'Excel निर्यात';

  @override
  String get excelExportDesc => 'स्प्रेडशीट विश्लेषण के लिए';

  @override
  String get dateRangeCaps => 'तिथि सीमा';

  @override
  String get generateExport => 'निर्यात करें';

  @override
  String get exportTransactions => 'लेनदेन निर्यात करें';

  @override
  String get exportDesc => 'अपना डेटा साझा करें';

  @override
  String get lastMonth => 'पिछले महीने';

  @override
  String get threeMonths => '3 महीने';

  @override
  String get allHistory => 'सारा इतिहास';

  @override
  String get custom => 'कस्टम';

  @override
  String get pleaseSelectDateRange => 'कृपया तिथि सीमा चुनें';

  @override
  String get user => 'वहाँ';

  @override
  String get categoriesCaps => 'श्रेणियाँ';

  @override
  String get chooseAvatar => 'अवतार चुनें';

  @override
  String get resetAvatar => 'अवतार रीसेट करें';
}
