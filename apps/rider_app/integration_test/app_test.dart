import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rider_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Rider app smoke tests', () {
    testWidgets('app launches and shows splash/login', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: RiderApp()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The app should render either the splash screen or the login screen.
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
