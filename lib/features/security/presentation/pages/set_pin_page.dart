import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Multi-step PIN setup/change screen.
///
/// Modes:
///  - [isChangingPin] = false → Set PIN flow: Enter → Confirm → Save
///  - [isChangingPin] = true  → Change PIN flow: Verify Old → Enter New → Confirm New → Save
class SetPinPage extends ConsumerStatefulWidget {
  final bool isChangingPin;
  const SetPinPage({super.key, this.isChangingPin = false});

  @override
  ConsumerState<SetPinPage> createState() => _SetPinPageState();
}

// Steps for the wizard
enum _PinStep { verifyOld, enterNew, confirmNew }

class _SetPinPageState extends ConsumerState<SetPinPage>
    with SingleTickerProviderStateMixin {
  final List<String> _pin = [];
  String? _newPin;
  bool _hasError = false;
  bool _isLoading = false;

  late _PinStep _step;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _step = widget.isChangingPin ? _PinStep.verifyOld : _PinStep.enterNew;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  String get _title {
    switch (_step) {
      case _PinStep.verifyOld:
        return 'Verify Current PIN';
      case _PinStep.enterNew:
        return widget.isChangingPin ? 'Enter New PIN' : 'Set a PIN';
      case _PinStep.confirmNew:
        return 'Confirm PIN';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _PinStep.verifyOld:
        return 'Enter your existing PIN to continue';
      case _PinStep.enterNew:
        return widget.isChangingPin
            ? 'Choose a new 4-digit PIN'
            : 'This protects your financial data';
      case _PinStep.confirmNew:
        return 'Re-enter your PIN to confirm';
    }
  }

  int get _stepNumber {
    if (!widget.isChangingPin) return _step == _PinStep.enterNew ? 1 : 2;
    switch (_step) {
      case _PinStep.verifyOld:
        return 1;
      case _PinStep.enterNew:
        return 2;
      case _PinStep.confirmNew:
        return 3;
    }
  }

  int get _totalSteps => widget.isChangingPin ? 3 : 2;

  void _onKeyTap(String digit) {
    if (_pin.length >= 4 || _isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin.add(digit);
      _hasError = false;
    });
    if (_pin.length == 4) {
      _processPin(_pin.join());
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty || _isLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _pin.removeLast());
  }

  Future<void> _processPin(String enteredPin) async {
    setState(() => _isLoading = true);

    switch (_step) {
      case _PinStep.verifyOld:
        final isValid =
            await ref.read(securityProvider.notifier).verifyOldPin(enteredPin);
        if (isValid) {
          setState(() {
            _pin.clear();
            _step = _PinStep.enterNew;
            _isLoading = false;
          });
        } else {
          await _showError();
        }
        break;

      case _PinStep.enterNew:
        setState(() {
          _newPin = enteredPin;
          _pin.clear();
          _step = _PinStep.confirmNew;
          _isLoading = false;
        });
        break;

      case _PinStep.confirmNew:
        if (enteredPin == _newPin) {
          await ref.read(securityProvider.notifier).setPin(enteredPin);
          setState(() => _isLoading = false);
          if (mounted) {
            // FIX Issue 3: Show the SnackBar FIRST while scaffold is still
            // in tree, then pop. Using a post-frame callback for the pop
            // ensures the snackbar message is queued before navigation.
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  widget.isChangingPin
                      ? '✅ PIN changed successfully'
                      : '✅ PIN set successfully',
                ),
                backgroundColor: AppColors.success500,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
            // Auto-navigate back after a short delay so the user sees the tick
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) context.pop();
          }
        } else {
          // PINs don't match → go back to Enter step
          _newPin = null;
          _shakeController.forward(from: 0);
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) {
            setState(() {
              _hasError = true;
              _pin.clear();
              _isLoading = false;
            });
            await Future.delayed(const Duration(milliseconds: 1000));
            if (mounted) {
              setState(() {
                _hasError = false;
                _step = _PinStep.enterNew;
              });
            }
          }
        }
        break;
    }
  }

  Future<void> _showError() async {
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _hasError = true;
        _pin.clear();
        _isLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _hasError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.gray50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: cs.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _title,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: _StepIndicator(
                  current: _stepNumber, total: _totalSteps),
            ),
            const Spacer(flex: 1),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _hasError
                    ? AppColors.danger50
                    : cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _step == _PinStep.verifyOld
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline_rounded,
                size: 32,
                color: _hasError ? AppColors.danger500 : cs.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _title,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                _hasError
                    ? (_step == _PinStep.verifyOld
                        ? 'Incorrect PIN. Please try again.'
                        : 'PINs don\'t match. Starting over.')
                    : _subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color:
                      _hasError ? AppColors.danger500 : AppColors.gray500,
                  fontWeight:
                      _hasError ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 36),

            // PIN dots
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                final offset = _shakeAnim.value * 10 *
                    ((_shakeAnim.value * 4).round() % 2 == 0 ? 1 : -1);
                return Transform.translate(
                    offset: Offset(offset, 0), child: child);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
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
                    ['', '0', '⌫'],
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
                          if (key.isEmpty) {
                            return const Expanded(child: SizedBox());
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

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 4,
            decoration: BoxDecoration(
              color: active ? cs.primary : cs.onSurface.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
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
              height: 60,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
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
