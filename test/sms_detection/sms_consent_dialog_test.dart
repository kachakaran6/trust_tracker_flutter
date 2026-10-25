import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/features/sms_detection/presentation/widgets/sms_consent_dialog.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => child,
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    );
  }

  testWidgets('SmsConsentDialog displays exact required copy and elements', (tester) async {
    await tester.pumpWidget(createTestWidget(const SmsConsentDialog()));

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Enable SMS Detection'), findsOneWidget);

    // Verify Description
    expect(
      find.text(
        'Import eligible transaction messages to help identify expenses and income automatically. This feature is optional, and you can continue using Trust Tracker without enabling it.',
      ),
      findsOneWidget,
    );

    // Verify Technical on-device disclosures
    expect(find.text('100% On-Device Processing'), findsOneWidget);
    expect(find.text('Data Minimization'), findsOneWidget);

    // Verify Privacy note
    expect(
      find.text(
        'SMS messages may contain sensitive information. Review how messages are processed and stored in our Privacy Policy before continuing.',
      ),
      findsOneWidget,
    );

    // Verify Action buttons
    expect(find.text('Privacy details'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('SmsConsentDialog returns false when "Not now" is tapped', (tester) async {
    bool? dialogResult;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              dialogResult = await showDialog<bool>(
                context: context,
                builder: (_) => const SmsConsentDialog(),
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap "Not now"
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(dialogResult, false);
    expect(find.byType(SmsConsentDialog), findsNothing);
  });

  testWidgets('SmsConsentDialog returns true when "Continue" is tapped', (tester) async {
    bool? dialogResult;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              dialogResult = await showDialog<bool>(
                context: context,
                builder: (_) => const SmsConsentDialog(),
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Tap "Continue"
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(dialogResult, true);
    expect(find.byType(SmsConsentDialog), findsNothing);
  });
}
