import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trust_tracker_flutter/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:trust_tracker_flutter/core/router/app_router.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/core/di/providers.dart';
import 'package:trust_tracker_flutter/core/security/security_provider.dart';
import 'package:trust_tracker_flutter/features/settings/presentation/providers/settings_provider.dart';
import 'package:trust_tracker_flutter/core/services/update_service.dart';
import 'package:trust_tracker_flutter/core/services/background_service.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:quick_actions/quick_actions.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/presentation/widgets/quick_add_bottom_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Firebase.initializeApp();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Database
  final dbHelper = DatabaseHelper.instance;
  await dbHelper.database; // Ensure it's initialized

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Background Tasks
  await BackgroundService.init();

  // Initialize Local Notifications
  try {
    final notifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('tt_stat_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.id == 100 || response.id == 999) {
          rootNavigatorKey.currentState?.context.push('/summary');
        }
      },
    );

    // Create Notification Channel for Android
    await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'summary_channel', 'Financial Summaries',
          description: 'Periodic financial activity summaries',
          importance: Importance.high,
        ));
  } catch (e) {
    debugPrint("Notification initialization failed: $e");
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseHelperProvider.overrideWithValue(dbHelper),
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(prefs),
        ),
        securityProvider.overrideWith(
          (ref) => SecurityNotifier(ref.watch(localAuthProvider), prefs),
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
  
  static const _channel = MethodChannel('com.trusttracker/quick_action');
  final QuickActions quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initQuickActions();
    _initMethodChannel();
  }

  void _initQuickActions() {
    quickActions.initialize((String shortcutType) {
      _handleQuickAction(shortcutType);
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'add_expense', localizedTitle: 'Add Expense'),
      const ShortcutItem(type: 'add_income', localizedTitle: 'Add Income'),
      const ShortcutItem(type: 'add_subscription', localizedTitle: 'Add Subscription'),
      const ShortcutItem(type: 'open_analytics', localizedTitle: 'Open Analytics'),
    ]);
  }

  void _initMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'quickAddExpense') {
        _handleQuickAction('add_expense');
      }
    });
  }

  void _handleQuickAction(String type) async {
    // Wait for navigator to be available if app was just launched
    await Future.delayed(const Duration(milliseconds: 600));
    final context = rootNavigatorKey.currentState?.context;
    if (context == null || !context.mounted) return;

    if (type == 'add_expense') {
      QuickAddBottomSheet.show(context, TransactionType.expense);
    } else if (type == 'add_income') {
      QuickAddBottomSheet.show(context, TransactionType.income);
    } else if (type == 'add_subscription') {
      context.push('/add-subscription');
    } else if (type == 'open_analytics') {
      context.push('/analytics');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final securityNotifier = ref.read(securityProvider.notifier);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      securityNotifier.lock();
      securityNotifier.setVisibility(false);
    } else if (state == AppLifecycleState.resumed) {
      securityNotifier.setVisibility(true);
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
