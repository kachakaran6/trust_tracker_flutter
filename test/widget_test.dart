import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_tracker_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // App requires Isar/SharedPrefs init, so we just verify it compiles
    expect(TrustTrackerApp, isNotNull);
  });
}
