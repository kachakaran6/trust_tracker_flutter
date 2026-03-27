import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';

class LockScreenPage extends ConsumerStatefulWidget {
  const LockScreenPage({super.key});

  @override
  ConsumerState<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends ConsumerState<LockScreenPage>
    with TickerProviderStateMixin {
  final List<String> _pin = [];
  bool _hasError = false;
  static const int _pinLength = 4;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;
  late final List<AnimationController> _digitControllers;

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

    _digitControllers = List.generate(_pinLength, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    ));

    // Feature 6: Auto-authentication attempt on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _shakeController.dispose();
    for (var c in _digitControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final security = ref.read(securityProvider);
    if (!security.isBiometricEnabled) return;
    
    // Feature 7: Handle biometric gracefully
    await Future.delayed(const Duration(milliseconds: 400));
    final success = await ref.read(securityProvider.notifier).authenticateBiometric();
    
    if (!success && mounted) {
      // Haptic feedback for failure
      HapticFeedback.lightImpact();
    }
  }

  void _onKeyTap(String digit) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin.add(digit);
      _hasError = false;
    });
    _digitControllers[_pin.length - 1].forward(from: 0);

    if (_pin.length == _pinLength) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    _digitControllers[_pin.length - 1].reverse();
    setState(() => _pin.removeLast());
  }

  Future<void> _verifyPin() async {
    final success = await ref
        .read(securityProvider.notifier)
        .verifyPin(_pin.join());
        
    if (!success) {
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
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // --- 8pt Spacing Scale ---
    const double spTight = 8.0;
    const double spStd = 16.0;
    const double spSect = 24.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // --- Iconic App Header ---
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/images/2.png',
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: spSect),
            
            Text('Trust Tracker', style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.0)),
            const SizedBox(height: spTight),
            
            Text(
              _hasError ? 'Incorrect PIN. Try again.' : 'Enter your security PIN',
              style: tt.bodyMedium?.copyWith(
                color: _hasError ? cs.error : cs.onSurface.withOpacity(0.4),
                fontWeight: _hasError ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),

            // --- Dots Visualization (Micro-animations) ---
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                final offset = _shakeAnim.value * 12 * ((_shakeAnim.value * 4).round() % 2 == 0 ? 1 : -1);
                return Transform.translate(offset: Offset(offset, 0), child: child);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  final scaleAnim = _digitControllers[i];

                  return ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: scaleAnim, curve: Curves.easeOutBack)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasError ? cs.error : filled ? cs.primary : cs.surfaceVariant,
                        boxShadow: filled && !_hasError
                            ? [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                            : null,
                        border: !filled ? Border.all(color: cs.outline.withOpacity(0.1), width: 1.5) : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            const Spacer(flex: 1),

            // --- Secure Keypad ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  for (final row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['bio', '0', '⌫']])
                    Padding(
                      padding: const EdgeInsets.only(bottom: spStd),
                      child: Row(
                        children: row.map((key) {
                          if (key == '⌫') {
                            return _KeypadButton(
                              child: Icon(Icons.backspace_rounded, size: 24, color: cs.onSurface),
                              onTap: _onBackspace,
                            );
                          }
                          if (key == 'bio') {
                            return security.isBiometricEnabled
                                ? _KeypadButton(
                                    child: Icon(Icons.fingerprint_rounded, size: 32, color: cs.primary),
                                    onTap: _tryBiometric,
                                  )
                                : const Expanded(child: SizedBox());
                          }
                          return _KeypadButton(
                            child: Text(key, style: tt.displaySmall?.copyWith(fontSize: 32, fontWeight: FontWeight.w700, color: cs.onSurface)),
                            onTap: () => _onKeyTap(key),
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

  const _KeypadButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(100),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
