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
final _shellNavigatorKeyAnalytics =
    GlobalKey<NavigatorState>(debugLabel: 'analytics');
final _shellNavigatorKeySettings =
    GlobalKey<NavigatorState>(debugLabel: 'settings');
final _shellNavigatorKeys = <GlobalKey<NavigatorState>>[
  _shellNavigatorKeyDashboard,
  _shellNavigatorKeyTransactions,
  _shellNavigatorKeyAnalytics,
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
            navigatorKey: _shellNavigatorKeyAnalytics,
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsPage(),
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
        path: '/subscriptions',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SubscriptionDashboardPage(),
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
        body: widget.navigationShell,
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/add-transaction'),
          backgroundColor: cs.primary,
          elevation: 4,
          shape: const CircleBorder(),
          child: Icon(Icons.add, size: 28, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _BottomNavBar(
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
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      );
    },
  );
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  final ColorScheme cs;
  final AppLocalizations l10n;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.cs,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: l10n.home,
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
                cs: cs,
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: l10n.activity,
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
                cs: cs,
              ),
              // Center spacer for FAB
              const SizedBox(width: 56),
              _NavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: l10n.analytics,
                selected: selectedIndex == 2,
                onTap: () => onTap(2),
                cs: cs,
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: l10n.settings,
                selected: selectedIndex == 3,
                onTap: () => onTap(3),
                cs: cs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                color:
                    selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color:
                    selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
