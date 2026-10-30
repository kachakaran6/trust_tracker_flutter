import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trust_tracker_flutter/generated/app_localizations.dart';
import 'package:trust_tracker_flutter/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:trust_tracker_flutter/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:trust_tracker_flutter/features/onboarding/presentation/pages/quick_features_intro_page.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/pages/transactions_page.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:trust_tracker_flutter/features/analytics/presentation/pages/analytics_page.dart';
import 'package:trust_tracker_flutter/features/budget/presentation/pages/budget_page.dart';
import 'package:trust_tracker_flutter/features/subscriptions/presentation/pages/subscription_dashboard_page.dart';
import 'package:trust_tracker_flutter/features/subscriptions/presentation/pages/add_subscription_page.dart';
import 'package:trust_tracker_flutter/features/categories/presentation/pages/categories_page.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/pages/our_apps_page.dart';
import 'package:trust_tracker_flutter/features/analytics/presentation/pages/summary_detail_page.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/security/presentation/pages/lock_screen_page.dart';
import 'package:trust_tracker_flutter/features/security/presentation/pages/set_pin_page.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/core/services/update_service.dart';
import 'package:trust_tracker_flutter/core/services/review_service.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/pages/banking_dashboard_page.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/pages/add_loan_page.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/pages/loan_detail_page.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/pages/loan_calculator_page.dart';
import 'package:trust_tracker_flutter/features/banking/presentation/pages/emi_calendar_page.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/pages/debt_manager_page.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/pages/person_debt_detail_page.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/add_debt_bottom_sheet.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/pages/sms_review_page.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/pages/sms_activity_page.dart';
import 'package:trust_tracker_flutter/core/widgets/liquid_glass_bottom_nav_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Router Notifier — bridges Riverpod state into GoRouter's refreshListenable.
// This ensures the router only rebuilds for security state, NOT theme changes.
// ─────────────────────────────────────────────────────────────────────────────
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    // FIX Issue 3: Use Future.microtask to decouple security updates from the current build frame.
    // This prevents the '!_debugLocked' error that causes the blank screen!
    _ref.listen<SecurityState>(securityProvider, (_, __) {
      if (hasListeners) {
        Future.microtask(() => notifyListeners());
      }
    });

    _ref.listen<SettingsState>(settingsProvider, (_, __) {
      if (hasListeners) {
        Future.microtask(() => notifyListeners());
      }
    });
  }

  final Ref _ref;

  SecurityState get security => _ref.read(securityProvider);
  SettingsState get settings => _ref.read(settingsProvider);
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKeyDashboard =
    GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _shellNavigatorKeyTransactions =
    GlobalKey<NavigatorState>(debugLabel: 'transactions');
final _shellNavigatorKeyDebt =
    GlobalKey<NavigatorState>(debugLabel: 'debt');
final _shellNavigatorKeySubscriptions =
    GlobalKey<NavigatorState>(debugLabel: 'subscriptions');
final _shellNavigatorKeySettings =
    GlobalKey<NavigatorState>(debugLabel: 'settings');
final _shellNavigatorKeys = <GlobalKey<NavigatorState>>[
  _shellNavigatorKeyDashboard,
  _shellNavigatorKeyTransactions,
  _shellNavigatorKeyDebt,
  _shellNavigatorKeySubscriptions,
  _shellNavigatorKeySettings,
];

/// The GoRouter is created ONCE per app lifecycle and is stored on the Provider.
/// Theme changes do NOT recreate the router because [appRouterProvider] is a
/// [Provider] (not a StreamProvider / FutureProvider) and only depends on the
/// [_RouterNotifier] listenable, not the full settings state.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final security = notifier.security;
      final settings = notifier.settings;
      final path = state.uri.path;

      // First run → go to onboarding
      if (settings.isFirstRun) {
        if (path != '/onboarding') return '/onboarding';
        return null;
      }

      if (!settings.hasSeenQuickFeaturesIntro) {
        if (path != '/quick-features-intro') return '/quick-features-intro';
        return null;
      }

      // FIX Issue 4: Only lock when PIN is actually enabled AND locked.
      // When disablePin() is called, both isPinEnabled=false AND isLocked=false
      // are set atomically. The old code only checked isLocked, which meant
      // a brief intermediate state could cause a blank screen.
      final shouldBeLocked = security.isPinEnabled && security.isLocked;

      // Locked → go to lock screen (but never redirect lock→lock)
      if (shouldBeLocked && path != '/lock') return '/lock';

      // Unlocked or PIN disabled and on lock screen → go to dashboard
      if (!shouldBeLocked && path == '/lock') return '/dashboard';

      // Coming from onboarding but first run is done
      if (!settings.isFirstRun && path == '/onboarding') return '/dashboard';
      if (settings.hasSeenQuickFeaturesIntro && path == '/quick-features-intro') return '/dashboard';

      return null;
    },
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/quick-features-intro',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const QuickFeaturesIntroPage(),
      ),
      GoRoute(
        path: '/lock',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LockScreenPage(),
      ),
      GoRoute(
        path: '/set-pin',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SetPinPage(
            isChangingPin: extra?['changing'] == true,
            isDisabling: extra?['disabling'] == true,
            verifyingForBio: extra?['verifyingForBio'],
          );
        },
      ),
      // ── Stateful Shell — preserves tab state across switches ─────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeyDashboard,
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeyTransactions,
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) => const TransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeyDebt,
            routes: [
              GoRoute(
                path: '/debt-manager',
                builder: (context, state) => const DebtManagerPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeySubscriptions,
            routes: [
              GoRoute(
                path: '/subscriptions',
                builder: (context, state) => const SubscriptionDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeySettings,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AnalyticsPage(),
      ),
      GoRoute(
        path: '/add-transaction',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddTransactionPage(
            initialType: extra?['type'],
            editTransaction: extra?['edit'],
            duplicateTransaction: extra?['duplicate'],
          );
        },
      ),
      GoRoute(
        path: '/debt-person-detail',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final personName = extra?['personName'] as String? ?? (state.uri.queryParameters['name'] ?? '');
          return PersonDebtDetailPage(personName: personName);
        },
      ),
      GoRoute(
        path: '/budget',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BudgetPage(),
      ),
      GoRoute(
        path: '/our-apps',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OurAppsPage(),
      ),
      GoRoute(
        path: '/add-subscription',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddSubscriptionPage(
            subscription: extra?['edit'],
          );
        },
      ),
      GoRoute(
        path: '/categories',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: '/summary',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SummaryDetailPage(),
      ),
      GoRoute(
        path: '/banking-dashboard',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BankingDashboardPage(),
      ),
      GoRoute(
        path: '/add-loan',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddLoanPage(),
      ),
      GoRoute(
        path: '/loan-details',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final loan = state.extra as LoanModel;
          return LoanDetailPage(loan: loan);
        },
      ),
      GoRoute(
        path: '/loan-calculator',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoanCalculatorPage(),
      ),
      GoRoute(
        path: '/emi-calendar',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EmiCalendarPage(),
      ),
      GoRoute(
        path: '/sms-review',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SmsReviewPage(),
      ),
      GoRoute(
        path: '/sms-activity',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SmsActivityPage(),
      ),
    ],
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Main Shell — StatefulShellRoute builder with custom bottom nav
// ─────────────────────────────────────────────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
  NavigatorState? get _activeBranchNavigator =>
      _shellNavigatorKeys[widget.navigationShell.currentIndex].currentState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial update check
    _checkForUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    // Wait for everything to settle
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await ref.read(updateServiceProvider).checkForUpdate(context);
      if (!mounted) return;
      await ref.read(reviewServiceProvider).logAppOpen(context);
    }
  }

  void _onTabTapped(int index) {
    widget.navigationShell.goBranch(
      index,
      // Go back to initial location if tapping active tab (like iOS behavior)
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _handleBackPressed() async {
    // Priority 1: Check if the Root Navigator (full-screen sub-pages) can pop.
    final rootNavigator = rootNavigatorKey.currentState;
    if (rootNavigator != null && rootNavigator.canPop()) {
      debugPrint('[Navigation] Pop Request: Root Navigator Popped');
      rootNavigator.pop();
      return;
    }

    // Priority 2: Check if the current tab's branch has internal history.
    final activeNavigator = _activeBranchNavigator;
    if (activeNavigator != null && activeNavigator.canPop()) {
      debugPrint('[Navigation] Pop Request: Branch Navigator Popped');
      activeNavigator.pop();
      return;
    }

    // Priority 3: If not on Home tab (index 0), switch back to Home.
    if (widget.navigationShell.currentIndex != 0) {
      debugPrint('[Navigation] Pop Request: Switching Tab to Home');
      widget.navigationShell.goBranch(0);
      return;
    }

    // Priority 4: From the Home tab root, show the exit confirmation dialog.
    debugPrint('[Navigation] Pop Request: Showing Exit Dialog');
    final shouldExit = await showExitConfirmationDialog(context);
    if (!mounted || shouldExit != true) {
      debugPrint('[Navigation] Pop Request: Exit Cancelled');
      return;
    }

    // Finally, close the application if confirmed.
    debugPrint('[Navigation] Pop Request: System Navigator Pop (Exit App)');
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Navigation] MainShell Build: Current Index = ${widget.navigationShell.currentIndex}');
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedIndex = widget.navigationShell.currentIndex;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        debugPrint('[Navigation] Pop Intercepted via PopScope');
        _handleBackPressed();
      },
      child: Scaffold(
        extendBody: true,
        body: widget.navigationShell,
        floatingActionButton: _FloatingCtaButton(
          currentIndex: selectedIndex,
          onTap: () {
            HapticFeedback.mediumImpact();
            if (selectedIndex == 2) {
              // Debt & Lent Tab -> Open dedicated Add Debt Modal
              AddDebtBottomSheet.show(context);
            } else if (selectedIndex == 3) {
              // Subscriptions Tab -> Open Add Subscription Page
              context.push('/add-subscription');
            } else {
              // Home, Activity, Settings -> Open Add Transaction
              context.push('/add-transaction');
            }
          },
          onLongPress: () {
            _showQuickAddActionSheet(context);
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: LiquidGlassBottomNavBar(
          selectedIndex: selectedIndex,
          onTap: _onTabTapped,
          cs: cs,
          l10n: AppLocalizations.of(context)!,
        ),
      ),
    );
  }
}

Future<bool?> showExitConfirmationDialog(BuildContext context) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final textTheme = theme.textTheme;
  final isDark = theme.brightness == Brightness.dark;
  final l10n = AppLocalizations.of(context)!;

  return showGeneralDialog<bool>(
    context: context,
    barrierLabel: l10n.exitApplication,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.3),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, vale, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 5.0 * vale,
                    sigmaY: 5.0 * vale,
                  ),
                  child: child!,
                );
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: isDark ? 0.96 : 1.0),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.2 : 0.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.4 : 0.1,
                        ),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Iconic Element
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          color: cs.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.exitApplication,
                        style: textTheme.headlineSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.exitConfirmMessage,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                l10n.cancel,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                l10n.exit,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FloatingCtaButton extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FloatingCtaButton({
    required this.currentIndex,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color buttonColor = cs.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: currentIndex == 2
            ? 'Add Debt / Lent Record'
            : (currentIndex == 3 ? 'Add Subscription' : 'Add Transaction'),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  buttonColor,
                  buttonColor.withValues(alpha: 0.90),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: buttonColor.withValues(alpha: isDark ? 0.20 : 0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: RotationTransition(
                        turns: animation.drive(Tween(begin: 0.75, end: 1.0)),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      key: ValueKey<int>(currentIndex),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showQuickAddActionSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    'Choose what you would like to record',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(ctx),
                style: IconButton.styleFrom(
                  backgroundColor: cs.onSurface.withValues(alpha: 0.05),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(34, 34),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickActionTile(
            icon: Icons.receipt_long_rounded,
            color: cs.primary,
            title: 'Add Transaction',
            subtitle: 'Record an income or expense',
            onTap: () {
              Navigator.pop(ctx);
              context.push('/add-transaction');
            },
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.handshake_rounded,
            color: cs.primary,
            title: 'Add Debt & Lent',
            subtitle: 'Record money lent out or borrowed',
            onTap: () {
              Navigator.pop(ctx);
              AddDebtBottomSheet.show(context);
            },
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.event_repeat_rounded,
            color: cs.primary,
            title: 'Add Subscription',
            subtitle: 'Track recurring bill or subscription',
            onTap: () {
              Navigator.pop(ctx);
              context.push('/add-subscription');
            },
          ),
        ],
      ),
    ),
  );
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.onSurface.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
