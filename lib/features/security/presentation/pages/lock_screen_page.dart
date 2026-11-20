import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';


class LockScreenPage extends ConsumerStatefulWidget {
  const LockScreenPage({super.key});

  @override
  ConsumerState<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends ConsumerState<LockScreenPage>
    with TickerProviderStateMixin {
  final List<String> _pin = [];
  bool _hasError = false;
  String? _validationError;
  String? _statusMessage;
  static const int _pinLength = 4;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;
  late final List<AnimationController> _digitControllers;
  Timer? _cooldownTimer;

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

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final security = ref.read(securityProvider);
        if (security.lockUntil != null) {
          setState(() {}); // Repaint for countdown
        }
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _cooldownTimer?.cancel();
    for (var c in _digitControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final security = ref.read(securityProvider);
    if (!security.isBiometricEnabled) return;
    
    final isLocked = security.lockUntil != null && DateTime.now().isBefore(security.lockUntil!);
    if (isLocked) return;
    
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final success = await ref.read(securityProvider.notifier).authenticateBiometric();
      if (!success && mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _statusMessage = 'Biometric cancelled. Enter PIN to unlock.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Biometric cancelled. Enter PIN to unlock.';
        });
      }
    }
  }

  void _onSubmit() {
    final security = ref.read(securityProvider);
    final isLocked = security.lockUntil != null && DateTime.now().isBefore(security.lockUntil!);
    if (isLocked) return;

    if (_pin.isEmpty) {
      _showValidationError('Please enter your 4-digit PIN');
      return;
    }
    if (_pin.length < _pinLength) {
      _showValidationError('PIN must be 4 digits');
      return;
    }
    _verifyPin();
  }

  Future<void> _showValidationError(String message) async {
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0);
    setState(() {
      _hasError = true;
      _validationError = message;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _hasError = false;
        _validationError = null;
      });
    }
  }

  void _onKeyTap(String digit) {
    final security = ref.read(securityProvider);
    final isLocked = security.lockUntil != null && DateTime.now().isBefore(security.lockUntil!);
    if (isLocked || _pin.length >= _pinLength) return;
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
    final security = ref.read(securityProvider);
    final isLocked = security.lockUntil != null && DateTime.now().isBefore(security.lockUntil!);
    if (isLocked || _pin.isEmpty) return;
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
            
            Builder(
              builder: (context) {
                final isLocked = security.lockUntil != null && DateTime.now().isBefore(security.lockUntil!);
                if (isLocked) {
                  final remaining = security.lockUntil!.difference(DateTime.now()).inSeconds;
                  return Text(
                    'Locked. Try again in $remaining${remaining > 1 ? 's' : 's'}',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }
                if (_validationError != null) {
                  return Text(
                    _validationError!,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }
                if (_hasError) {
                  return Text(
                    'Incorrect PIN (${security.failedAttempts}/5)',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }
                if (_statusMessage != null) {
                  return Text(
                    _statusMessage!,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }
                return Text(
                  'Enter your security PIN',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.4),
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
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
            Builder(
              builder: (context) {
                final isLocked = security.lockUntil != null && DateTime.now().isBefore(security.lockUntil!);
                return Opacity(
                  opacity: isLocked ? 0.3 : 1.0,
                  child: Padding(
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
                                    onTap: isLocked ? () {} : _onBackspace,
                                  );
                                }
                                if (key == 'bio') {
                                  if (security.isBiometricEnabled) {
                                    return _KeypadButton(
                                      child: Icon(Icons.fingerprint_rounded, size: 32, color: cs.primary),
                                      onTap: isLocked ? () {} : _tryBiometric,
                                    );
                                  } else {
                                    return _KeypadButton(
                                      child: Icon(Icons.check_rounded, size: 28, color: cs.primary),
                                      onTap: isLocked ? () {} : _onSubmit,
                                    );
                                  }
                                }
                                return _KeypadButton(
                                  child: Text(key, style: tt.displaySmall?.copyWith(fontSize: 32, fontWeight: FontWeight.w700, color: cs.onSurface)),
                                  onTap: isLocked ? () {} : () => _onKeyTap(key),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Builder(
              builder: (context) {
                final isLocked = security.lockUntil != null && DateTime.now().isBefore(security.lockUntil!);
                return TextButton.icon(
                  onPressed: isLocked ? null : _onSubmit,
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.w700)),
                );
              },
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
