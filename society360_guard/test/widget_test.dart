// Basic Flutter widget test for Society360 Guard App

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:society360_guard/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: Society360GuardApp(),
      ),
    );

    // Verify that the login screen is shown
    await tester.pumpAndSettle();

    // The app should start on the login screen
    expect(find.text('Society360'), findsOneWidget);
  });
}
