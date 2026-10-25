import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/currency_detector.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _nameController = TextEditingController();
  String _selectedCurrency = CurrencyDetector.detectSupported();
  int _currentPage = 0;
  final _pageController = PageController();

  // New settings state
  bool _carryForward = false;
  int _monthStartDay = 1;
  String _selectedLanguageCode = 'en';
  TransactionActionMode _actionMode = TransactionActionMode.swipe;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_currentPage < 6) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      // If name is empty, jump back to name page
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 400), curve: Curves.ease);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    
    final settingsNotifier = ref.read(settingsProvider.notifier);
    
    // Save all onboarding settings
    await settingsNotifier.completeOnboarding(name, _selectedCurrency);
    await settingsNotifier.setCarryForwardEnabled(_carryForward);
    await settingsNotifier.setMonthStartDay(_monthStartDay);
    await settingsNotifier.setLanguage(_selectedLanguageCode);
    await settingsNotifier.setTransactionActionMode(_actionMode);

    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 32 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(5),
                  ),
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(tt),
                  _buildNamePage(tt),
                  _buildCurrencyPage(tt),
                  _buildActionsPage(tt),
                  _buildLanguagePage(tt),
                  _buildMonthlyControlPage(tt),
                  _buildFinalPage(tt),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: cs.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _currentPage == 6 ? l10n.startTracking : l10n.continueLabel,
                      style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                    ),
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(TextTheme tt) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  size: 60, color: Colors.white),
            ),
            const SizedBox(height: 40),
            Text(l10n.appName,
                style: tt.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text(
              l10n.welcomeTagline,
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 48),
            _featureRow(Icons.lock_outline_rounded,
                l10n.lockPrivate, tt),
            const SizedBox(height: 16),
            _featureRow(Icons.bar_chart_rounded,
                l10n.smartAnalytics, tt),
            const SizedBox(height: 16),
            _featureRow(Icons.bolt_rounded,
                l10n.blazingFast, tt),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text, TextTheme tt) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Text(text,
            style: tt.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _buildNamePage(TextTheme tt) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 32),
          Text(l10n.whatsYourName,
              style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(l10n.personalizeExperience,
              style: tt.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.85))),
          const SizedBox(height: 40),
          TextField(
            controller: _nameController,
            style: tt.bodyLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: l10n.alexHint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCurrencyPage(TextTheme tt) {
    final cs = Theme.of(context).colorScheme;
    final detectedCode = CurrencyDetector.detectSupported();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.currency_exchange_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 32),
          Text(l10n.chooseCurrency,
              style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.detectedChangeSettings(detectedCode),
                style: tt.labelLarge?.copyWith(color: Colors.white.withOpacity(0.8)),
              ),
            ),
          ]),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: AppConstants.currencies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final c = AppConstants.currencies[i];
                final isSelected = _selectedCurrency == c['code'];
                final isDetected = c['code'] == detectedCode;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCurrency = c['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                    ),
                    child: Row(children: [
                      Text(c['symbol']!,
                          style: tt.titleLarge?.copyWith(
                              fontSize: 20,
                              color: isSelected ? cs.primary : Colors.white)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(c['code']!,
                                  style: tt.titleMedium?.copyWith(
                                      color: isSelected ? cs.primary : Colors.white,
                                      fontWeight: FontWeight.w800)),
                              if (isDetected && !isSelected) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('DETECTED',
                                      style: tt.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
                                ),
                              ],
                            ]),
                            Text(c['name']!,
                                style: tt.labelLarge?.copyWith(
                                    color: isSelected ? cs.onSurfaceVariant : Colors.white.withOpacity(0.7))),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: cs.primary, size: 24),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsPage(TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.touch_app_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 32),
          Text(l10n.quickEasyActions,
              style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(l10n.manageRecordsGestures,
              style: tt.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.85))),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                // Demo Transaction Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_bag_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Groceries", style: tt.titleMedium?.copyWith(color: Colors.white)),
                            Text("Apple Store", style: tt.bodySmall?.copyWith(color: Colors.white70)),
                          ],
                        ),
                      ),
                      Text("-\$42.00", style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Swipe Animation Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swipe_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.swipeLeftRightAction, style: tt.labelLarge?.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 20),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          _featureRow(Icons.edit_rounded, l10n.swipeEditDelete, tt),
          const SizedBox(height: 16),
          _featureRow(Icons.ads_click_rounded, l10n.tapViewDetails, tt),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLanguagePage(TextTheme tt) {
    final languages = [
      {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
      {'code': 'gu', 'name': 'ગુજરાતી', 'flag': '🇮🇳'},
      {'code': 'hi', 'name': 'हिन्दी', 'flag': '🇮🇳'},
    ];

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.public_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 32),
          Text(l10n.preferredLanguage,
              style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(l10n.homeLanguage,
              style: tt.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.85))),
          const SizedBox(height: 48),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isSelected = _selectedLanguageCode == lang['code'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedLanguageCode = lang['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 8),
                        Text(
                          lang['name']!,
                          style: tt.titleSmall?.copyWith(
                            color: isSelected ? const Color(0xFF0D6EFD) : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Text(
            l10n.languageSupportNote,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyControlPage(TextTheme tt) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 32),
          Text(l10n.smartMonthlyTracking,
              style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(l10n.trackFinancesWay,
              style: tt.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.85))),
          const SizedBox(height: 40),
          
          // Carry Forward Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.carryForward, style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    Switch.adaptive(
                      value: _carryForward,
                      onChanged: (val) => setState(() => _carryForward = val),
                      activeColor: Colors.white,
                    ),
                  ],
                ),
                Text(
                  _carryForward 
                    ? l10n.carryForwardEnabledDesc 
                    : l10n.carryForwardDisabledDesc,
                  style: tt.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Month Start Date Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.monthStartDay, style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 31,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final isSelected = _monthStartDay == day;
                      return GestureDetector(
                        onTap: () => setState(() => _monthStartDay = day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 50,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "$day",
                            style: tt.titleMedium?.copyWith(
                              color: isSelected ? cs.primary : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.customStartDateDesc,
                  style: tt.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPage(TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text("🚀", style: TextStyle(fontSize: 64)),
            ),
          ),
          const SizedBox(height: 48),
          Text(l10n.readyTitle,
              style: tt.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 24),
          Text(
            l10n.readyDesc,
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _summaryRow(Icons.check_circle_outline_rounded, l10n.personalizedProfile),
                const SizedBox(height: 12),
                _summaryRow(Icons.check_circle_outline_rounded, l10n.globalCurrency),
                const SizedBox(height: 12),
                _summaryRow(Icons.check_circle_outline_rounded, l10n.smartMonthlyControls),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
