import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/core/app_constants.dart';
import 'package:rider_app/data/mock/demo_data.dart';
import 'package:rider_app/data/mock/demo_repositories.dart';
import 'package:rider_app/ui/core/app_theme.dart';
import 'package:rider_app/ui/features/quote/views/quote_screen.dart';
import 'package:rider_app/ui/features/ride_completion/views/ride_completion_screen.dart';

Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: demoOverrides,
      child: MaterialApp(
        locale: AppConstants.defaultLocale,
        supportedLocales: AppConstants.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: appTheme(),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('QuoteScreen fetches on entry and lists the ride tiers',
      (tester) async {
    await pumpScreen(tester, const QuoteScreen());

    // Auto-fetch fixed the old dead funnel: the placeholder is gone and the
    // server quote is now rendered as a selectable product list.
    expect(find.text('لا يوجد تقدير'), findsNothing);
    expect(find.text('اختر نوع الرحلة'), findsOneWidget);
    expect(find.text('ميشوار'), findsOneWidget);
    expect(find.text('Comfort'), findsOneWidget);
    expect(find.text('ميشوار XL'), findsOneWidget);
    expect(find.text('اقتصادية'), findsOneWidget);
    expect(find.text('تأكيد الطلب'), findsOneWidget);
  });

  testWidgets('QuoteScreen selecting a tier moves the active (black) fill',
      (tester) async {
    await pumpScreen(tester, const QuoteScreen());

    Color fillOf(String tierName) {
      final container = tester.widget<Container>(find
          .ancestor(of: find.text(tierName), matching: find.byType(Container))
          .first);
      return (container.decoration as BoxDecoration).color!;
    }

    // Default selection is mishwar (black-filled), XL is chip gray.
    expect(fillOf('ميشوار'), UberColors.black);
    expect(fillOf('ميشوار XL'), UberColors.chipGray);

    await tester.tap(find.text('ميشوار XL'));
    await tester.pumpAndSettle();

    // After tapping, XL becomes active and mishwar returns to chip gray.
    expect(fillOf('ميشوار XL'), UberColors.black);
    expect(fillOf('ميشوار'), UberColors.chipGray);
  });

  testWidgets('RideCompletionScreen rating updates on tap', (tester) async {
    await pumpScreen(
        tester, const RideCompletionScreen(rideId: DemoData.preexistingRideId));

    expect(find.text('تقييم السائق'), findsOneWidget);

    // Tap the 4th star (all start as outline icons at rating 0).
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pumpAndSettle();

    expect(find.text('تقييمك: 4 من 5'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(4));
    expect(find.text('العودة إلى الرئيسية'), findsOneWidget);
  });
}
