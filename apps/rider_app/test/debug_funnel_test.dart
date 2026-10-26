import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rider_app/core/app_constants.dart';
import 'package:rider_app/data/mock/demo_repositories.dart';
import 'package:rider_app/ui/core/app_theme.dart';
import 'package:rider_app/ui/features/home/views/home_screen.dart';

void main() {
  testWidgets('debug funnel state', (tester) async {
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

    debugPrint('VIEWPORT: ${tester.view.physicalSize} dpr=${tester.view.devicePixelRatio}');

    await tester.tap(find.text('الوجهة'));
    await tester.pumpAndSettle();

    final tiles = find.byType(ListTile);
    debugPrint('TILES: ${tiles.evaluate().length}');
    for (final e in tester.widgetList<ListTile>(tiles).take(3).toList().asMap().entries) {
      debugPrint('tile ${e.key}: ${e.value.title} at ${tester.getRect(tiles.at(e.key)).center}');
    }

    await tester.tap(tiles.first);
    await tester.pumpAndSettle();

    debugPrint('SHEET STILL OPEN: ${tester.any(find.byType(TextField))}');
    final coord = find.textContaining(', ');
    debugPrint('COORD TEXTS: ${coord.evaluate().length}');
    for (final w in tester.widgetList<Text>(coord)) {
      debugPrint('coord text: ${w.data}');
    }

    final locBtn = find.byTooltip('استخدم موقعي كنقطة انطلاق');
    debugPrint('LOCATE BTN RECT: ${tester.getRect(locBtn)}');
    final ctaBtn = find.widgetWithText(ElevatedButton, 'عرض الأسعار');
    debugPrint('CTA ENABLED: ${(tester.widget<ElevatedButton>(ctaBtn)).onPressed != null}');

    // Geometry dump: where is everything?
    debugPrint('PICKUP LABEL EXISTS: ${tester.any(find.text('اختر نقطة الانطلاق'))}');
    final icons = find.byType(Icon);
    for (var i = 0; i < tester.widgetList(find.byType(Icon)).length; i++) {
      final w = tester.widget<Icon>(icons.at(i));
      debugPrint('icon $i: ${w.icon} at ${tester.getRect(icons.at(i))}');
    }
    final texts = find.byType(Text);
    for (var i = 0; i < tester.widgetList(find.byType(Text)).length; i++) {
      final w = tester.widget<Text>(texts.at(i));
      debugPrint('text $i: ${w.data} at ${tester.getRect(texts.at(i))}');
    }
    debugPrint('CARD RECTS:');
    final cards = find.byType(Card);
    for (var i = 0; i < tester.widgetList(cards).length; i++) {
      debugPrint('  card ${tester.getRect(cards.at(i))}');
    }
    // Ancestor chain of the booking card.
    final stack = find.ancestor(of: cards.first, matching: find.byType(Stack));
    for (var i = 0; i < tester.widgetList(stack).length; i++) {
      debugPrint('  stack $i ${tester.getRect(stack.at(i))}');
    }
    final aligns = find.ancestor(of: cards.first, matching: find.byType(Align));
    for (var i = 0; i < tester.widgetList(aligns).length; i++) {
      debugPrint('  align $i ${(tester.widget<Align>(aligns.at(i))).alignment} ${tester.getRect(aligns.at(i))}');
    }
    final paddings = find.ancestor(of: cards.first, matching: find.byType(Padding));
    for (var i = 0; i < tester.widgetList(paddings).length; i++) {
      debugPrint('  padding $i ${(tester.widget<Padding>(paddings.at(i))).padding} ${tester.getRect(paddings.at(i))}');
    }
    debugPrint('LOCATION ICON RECT: ${tester.getRect(find.byIcon(Icons.my_location))}');
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pumpAndSettle();
    debugPrint('AFTER LOCATE TAP, PICKUP TILE TEXTS:');
    for (final w in tester.widgetList<Text>(find.textContaining('15.'))) {
      debugPrint('  ${w.data}');
    }
    debugPrint('CTA ENABLED NOW: ${(tester.widget<ElevatedButton>(ctaBtn)).onPressed != null}');
  });
}
