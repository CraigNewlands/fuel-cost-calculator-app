// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fuel_cost_calculator/main.dart';

void main() {
  testWidgets('Fuel Cost Calculator smoke test', (WidgetTester tester) async {
    // Mock MobileAds initialization
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_mobile_ads'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'MobileAds#initialize') {
          return <String, dynamic>{
            'adapterStatuses': <String, dynamic>{},
            'initializationStatus': <String, dynamic>{
              'adapterStatuses': <String, dynamic>{},
            },
          };
        }
        return null;
      },
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        home: FuelCostCalculator(),
      ),
    );

    // Verify that the app title is displayed.
    expect(find.text('Fuel Cost Calculator'), findsOneWidget);
  });
}
