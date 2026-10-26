import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/core/app_constants.dart';
import 'package:rider_app/data/mock/demo_repositories.dart';
import 'package:rider_app/ui/core/app_theme.dart';
import 'package:rider_app/ui/features/home/views/home_screen.dart';

void main() {
  testWidgets('home booking funnel: search fills endpoints and enables prices CTA',
      (tester) async {
    const viewport = Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    ElevatedButton cta() =>
        tester.widget(find.widgetWithText(ElevatedButton, 'عرض الأسعار'));

    // Nothing selected yet -> the CTA is inert.
    expect(cta().onPressed, isNull);

    // Tapping the destination row opens the place-search sheet, which starts
    // with the full demo place list (recent-places style).
    await tester.tap(find.text('الوجهة'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets);

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    // The placeholder is replaced by the chosen coordinates.
    expect(find.text('الوجهة'), findsNothing);
    expect(cta().onPressed, isNull, reason: 'pickup still missing');

    // The on-map locate button sets the pickup from the demo fix.
    await tester.tap(find.byTooltip('استخدم موقعي كنقطة انطلاق'));
    await tester.pumpAndSettle();
    expect(cta().onPressed, isNotNull, reason: 'both endpoints are set');
  });
}
