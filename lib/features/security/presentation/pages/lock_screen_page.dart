import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium fintech lock screen.
///
/// On [initState], if biometric is enabled → immediately triggers biometric
/// prompt (NO PIN shown first). If biometric fails or is not enabled, the PIN
/// keypad is shown.
class LockScreenPage extends ConsumerStatefulWidget {
  const LockScreenPage({super.key});

  @override
  ConsumerState<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends ConsumerState<LockScreenPage>
    with SingleTickerProviderStateMixin {
  final List<String> _pin = [];
  bool _hasError = false;
  static const int _pinLength = 4;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_shakeController);

    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final security = ref.read(securityProvider);
    if (!security.isBiometricEnabled) return;
    final success =
        await ref.read(securityProvider.notifier).authenticateBiometric();
    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  void _onKeyTap(String digit) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin.add(digit);
      _hasError = false;
    });
    if (_pin.length == _pinLength) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _pin.removeLast());
  }

  Future<void> _verifyPin() async {
    final success = await ref
        .read(securityProvider.notifier)
        .verifyPin(_pin.join());
    if (success && mounted) {
      context.go('/dashboard');
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _hasError = true;
          _pin.clear();
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) setState(() => _hasError = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.gray50,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // App icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary600, AppColors.primary400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary500.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Trust Tracker',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasError
                  ? 'Incorrect PIN. Try again.'
                  : 'Enter your PIN',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _hasError ? AppColors.danger500 : AppColors.gray500,
                fontWeight: _hasError ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            // PIN dots
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                final offset = _shakeAnim.value * 10 *
                    ((_shakeAnim.value * 4).round() % 2 == 0 ? 1 : -1);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: filled ? 18 : 16,
                    height: filled ? 18 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError
                          ? AppColors.danger500
                          : filled
                              ? cs.primary
                              : (isDark
                                  ? const Color(0xFF2D3748)
                                  : AppColors.gray300),
                      boxShadow: filled && !_hasError
                          ? [
                              BoxShadow(
                                color: cs.primary.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),
            const Spacer(flex: 1),
            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['bio', '0', '⌫'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: row.map((key) {
                          if (key == '⌫') {
                            return _KeypadButton(
                              child: Icon(Icons.backspace_outlined,
                                  size: 22, color: cs.onSurface),
                              onTap: _onBackspace,
                              isDark: isDark,
                            );
                          }
                          if (key == 'bio') {
                            return security.isBiometricEnabled
                                ? _KeypadButton(
                                    child: Icon(Icons.fingerprint,
                                        size: 28, color: cs.primary),
                                    onTap: _tryBiometric,
                                    isDark: isDark,
                                  )
                                : const Expanded(child: SizedBox());
                          }
                          return _KeypadButton(
                            child: Text(
                              key,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            onTap: () => _onKeyTap(key),
                            isDark: isDark,
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const _KeypadButton({
    required this.child,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1F2937)
                    : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
