import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/core/widgets/liquid_glass_bottom_nav_bar.dart';
import 'package:trust_tracker_flutter/generated/app_localizations.dart';

void main() {
  Widget buildTestWidget({
    required int selectedIndex,
    required void Function(int) onTap,
    ThemeMode themeMode = ThemeMode.light,
    VoidCallback? onAddTap,
  }) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            body: const Center(child: Text('Test Content')),
            bottomNavigationBar: LiquidGlassBottomNavBar(
              selectedIndex: selectedIndex,
              onTap: onTap,
              cs: cs,
              l10n: l10n,
              onAddTap: onAddTap,
            ),
          );
        },
      ),
    );
  }

  testWidgets('renders all five navigation destinations', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        selectedIndex: 0,
        onTap: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Debt / Lent'), findsWidgets);
    expect(find.text('Subs'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('tapping destination fires onTap callback with correct index', (tester) async {
    int tappedIndex = -1;
    await tester.pumpWidget(
      buildTestWidget(
        selectedIndex: 0,
        onTap: (index) => tappedIndex = index,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();
    expect(tappedIndex, equals(1));

    await tester.tap(find.text('Debt / Lent').first);
    await tester.pumpAndSettle();
    expect(tappedIndex, equals(2));

    await tester.tap(find.text('Subs').first);
    await tester.pumpAndSettle();
    expect(tappedIndex, equals(3));

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(tappedIndex, equals(4));

    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    expect(tappedIndex, equals(0));
  });

  testWidgets('renders properly in dark mode without crashing', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        selectedIndex: 2,
        onTap: (_) {},
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Debt / Lent'), findsWidgets);
    expect(find.byType(LiquidGlassBottomNavBar), findsOneWidget);
  });

  testWidgets('extra action button triggers onAddTap callback', (tester) async {
    bool addTapped = false;
    await tester.pumpWidget(
      buildTestWidget(
        selectedIndex: 0,
        onTap: (_) {},
        onAddTap: () => addTapped = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(addTapped, isTrue);
  });
}
