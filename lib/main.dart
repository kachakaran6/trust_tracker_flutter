import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:trust_tracker_flutter/core/router/app_router.dart';
import 'package:trust_tracker_flutter/core/storage/isar_service.dart';
import 'package:trust_tracker_flutter/core/di/providers.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/core/services/update_service.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Isar
  final isarService = IsarService();
  await isarService.init();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        isarServiceProvider.overrideWithValue(isarService),
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(prefs),
        ),
      ],
      child: const TrustTrackerApp(),
    ),
  );
}

class TrustTrackerApp extends ConsumerStatefulWidget {
  const TrustTrackerApp({super.key});

  @override
  ConsumerState<TrustTrackerApp> createState() => _TrustTrackerAppState();
}

class _TrustTrackerAppState extends ConsumerState<TrustTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await ref.read(updateServiceProvider).checkForUpdate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Feature 5 & 6: App Lock and Recents Security
    final securityNotifier = ref.read(securityProvider.notifier);
    
    // inactive = partially visible (like Recents list)
    // paused = totally in background
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      securityNotifier.lock();
      securityNotifier.setVisibility(false);
    } else if (state == AppLifecycleState.resumed) {
      securityNotifier.setVisibility(true);
      _checkForUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(appRouterProvider);

    final accentColor = AppAccentColors.fromHex(settings.accentColorHex).color;

    return MaterialApp.router(
      title: 'Trust Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(accentColor, Brightness.light),
      darkTheme: AppTheme.getTheme(accentColor, Brightness.dark),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(settings.languageCode),
      // --- Feature 5 Wrapper: Protect sensitive UI in recents tray ---
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final security = ref.watch(securityProvider);
            if (!security.isAppVisible && security.isPinEnabled) {
              return _SecureAppOverlay(theme: Theme.of(context));
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _SecureAppOverlay extends StatelessWidget {
  final ThemeData theme;
  const _SecureAppOverlay({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.security_rounded, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Trust Tracker is Secured',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
