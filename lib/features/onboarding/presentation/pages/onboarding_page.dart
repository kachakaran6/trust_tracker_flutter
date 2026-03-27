import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/currency_detector.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    await ref.read(settingsProvider.notifier).completeOnboarding(name, _selectedCurrency);
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
                children: List.generate(3, (i) => AnimatedContainer(
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
                    _currentPage == 2 ? 'Get Started 🚀' : 'Continue',
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
    return Padding(
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
          Text('Trust Tracker',
              style: tt.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Text(
            'Your private, offline-first\nfinancial companion',
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.9), height: 1.6, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 48),
          _featureRow(Icons.lock_outline_rounded, 'Completely Private — no cloud, no servers', tt),
          const SizedBox(height: 16),
          _featureRow(Icons.bar_chart_rounded, 'Smart analytics & budget tracking', tt),
          const SizedBox(height: 16),
          _featureRow(Icons.bolt_rounded, 'Blazing fast — all data lives on your phone', tt),
        ],
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 32),
          Text("What's your name?",
              style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text("We'll use this to personalize your experience.",
              style: tt.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.85))),
          const SizedBox(height: 40),
          TextField(
            controller: _nameController,
            style: tt.bodyLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'e.g., Alex',
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
          Text("Choose your currency",
              style: tt.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$detectedCode detected · change anytime in Settings',
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
}
