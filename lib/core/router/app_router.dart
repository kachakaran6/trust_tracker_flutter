import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:trust_tracker_flutter/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/pages/transactions_page.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:trust_tracker_flutter/features/analytics/presentation/pages/analytics_page.dart';
import 'package:trust_tracker_flutter/features/budget/presentation/pages/budget_page.dart';
import 'package:trust_tracker_flutter/features/categories/presentation/pages/categories_page.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/features/security/presentation/pages/lock_screen_page.dart';
import 'package:trust_tracker_flutter/features/security/presentation/pages/set_pin_page.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Router Notifier — bridges Riverpod state into GoRouter's refreshListenable.
// This ensures the router only rebuilds for security state, NOT theme changes.
// ─────────────────────────────────────────────────────────────────────────────
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<SecurityState>(securityProvider, (_, __) => notifyListeners());
    _ref.listen<SettingsState>(settingsProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  SecurityState get security => _ref.read(securityProvider);
  SettingsState get settings => _ref.read(settingsProvider);
}

final _routerNotifierProvider = Provider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKeyDashboard = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _shellNavigatorKeyTransactions = GlobalKey<NavigatorState>(debugLabel: 'transactions');
final _shellNavigatorKeyAnalytics = GlobalKey<NavigatorState>(debugLabel: 'analytics');
final _shellNavigatorKeySettings = GlobalKey<NavigatorState>(debugLabel: 'settings');

/// The GoRouter is created ONCE per app lifecycle and is stored on the Provider.
/// Theme changes do NOT recreate the router because [appRouterProvider] is a
/// [Provider] (not a StreamProvider / FutureProvider) and only depends on the
/// [_RouterNotifier] listenable, not the full settings state.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
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

      // Locked → go to lock screen (but never redirect lock→lock)
      if (security.isLocked && path != '/lock') return '/lock';

      // Unlocked and on lock screen → go to dashboard
      if (!security.isLocked && path == '/lock') return '/dashboard';

      // Coming from onboarding but first run is done
      if (!settings.isFirstRun && path == '/onboarding') return '/dashboard';

      return null;
    },
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/lock',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LockScreenPage(),
      ),
      GoRoute(
        path: '/set-pin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SetPinPage(isChangingPin: extra?['changing'] == true);
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
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AddTransactionPage(
            initialType: extra?['type'],
            editTransaction: extra?['edit'],
          );
        },
      ),
      GoRoute(
        path: '/budget',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BudgetPage(),
      ),
      GoRoute(
        path: '/categories',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CategoriesPage(),
      ),
    ],
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Main Shell — StatefulShellRoute builder with custom bottom nav
// ─────────────────────────────────────────────────────────────────────────────
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  void _onTabTapped(int index) {
    navigationShell.goBranch(
      index,
      // Go back to initial location if tapping active tab (like iOS behavior)
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
              onPressed: () => context.push('/add-transaction'),
              backgroundColor: cs.primary,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28, color: Colors.white),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: selectedIndex,
        onTap: _onTabTapped,
        cs: cs,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  final ColorScheme cs;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: () => onTap(0),
                cs: cs,
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Transactions',
                selected: selectedIndex == 1,
                onTap: () => onTap(1),
                cs: cs,
              ),
              // Center spacer for FAB
              const SizedBox(width: 56),
              _NavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Analytics',
                selected: selectedIndex == 2,
                onTap: () => onTap(2),
                cs: cs,
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Settings',
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
                color: selected ? cs.primary.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                color: selected ? cs.primary : cs.onSurface.withOpacity(0.5),
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? cs.primary : cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
