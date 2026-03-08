import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/constants/app_constants.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/utils/currency_detector.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _nameController = TextEditingController();
  // Auto-detect locale currency; user can still override on the currency page.
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
    return Scaffold(
      backgroundColor: AppColors.primary500,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildNamePage(),
                  _buildCurrencyPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _currentPage == 2 ? 'Get Started 🚀' : 'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.account_balance_wallet,
                size: 56, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text('Trust Tracker',
              style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 12),
          Text(
            'Your private, offline-first\nfinancial companion',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white.withOpacity(0.85),
                height: 1.6),
          ),
          const SizedBox(height: 40),
          _featureRow(Icons.lock_outline, 'Completely Private — no cloud, no server'),
          const SizedBox(height: 12),
          _featureRow(Icons.bar_chart, 'Smart analytics & budget tracking'),
          const SizedBox(height: 12),
          _featureRow(Icons.bolt, 'Blazing fast — all data lives on your phone'),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text,
            style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.waving_hand, color: Colors.white, size: 48),
          const SizedBox(height: 24),
          Text("What's your name?",
              style: GoogleFonts.inter(
                  fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text("We'll use this to personalize your experience.",
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.8), fontSize: 15)),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: GoogleFonts.inter(
                color: AppColors.gray900, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'e.g., Alex',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPage() {
    final detectedCode = CurrencyDetector.detectSupported();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.currency_exchange, color: Colors.white, size: 48),
          const SizedBox(height: 24),
          Text("Choose your currency",
              style: GoogleFonts.inter(
                  fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          // Show which currency was detected and from where
          Row(children: [
            const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$detectedCode detected from your region · change anytime in Settings',
                style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: AppConstants.currencies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = AppConstants.currencies[i];
                final isSelected = _selectedCurrency == c['code'];
                final isDetected = c['code'] == detectedCode;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCurrency = c['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(children: [
                      Text(c['symbol']!,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: isSelected
                                  ? AppColors.primary600
                                  : Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(c['code']!,
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primary700
                                          : Colors.white)),
                              if (isDetected && !isSelected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Detected',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ),
                              ],
                            ]),
                            Text(c['name']!,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isSelected
                                        ? AppColors.gray500
                                        : Colors.white.withOpacity(0.7))),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary600),
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
