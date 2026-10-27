/// Renders every driver screen at the three responsive breakpoints
/// (375 / 768 / 1280 logical px) and asserts the layouts settle without any
/// RenderFlex overflow or other layout exception, plus checks for the
/// adaptive navigation shell and the 44px minimum touch targets.
library;

import 'package:driver_app/app_router.dart';
import 'package:driver_app/core/app_constants.dart';
import 'package:driver_app/data/mock/demo_data.dart';
import 'package:driver_app/data/mock/demo_repositories.dart';
import 'package:driver_app/l10n/app_localizations.dart';
import 'package:driver_app/ui/core/app_theme.dart';
import 'package:driver_app/ui/features/auth/views/documents_screen.dart';
import 'package:driver_app/ui/features/auth/views/login_screen.dart';
import 'package:driver_app/ui/features/auth/views/otp_screen.dart';
import 'package:driver_app/ui/features/auth/views/register_screen.dart';
import 'package:driver_app/ui/features/earnings/views/earnings_screen.dart';
import 'package:driver_app/ui/features/earnings/views/payout_request_screen.dart';
import 'package:driver_app/ui/features/home/views/home_screen.dart';
import 'package:driver_app/ui/features/offers/views/offers_screen.dart';
import 'package:driver_app/ui/features/ride_tracking/views/ride_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three widths every layout must survive, with a realistic height for
/// each form factor.
const _viewports = <String, Size>{
  'mobile (375px)': Size(375, 700),
  'tablet (768px)': Size(768, 1024),
  'desktop (1280px)': Size(1280, 800),
};

Future<void> pumpAtViewport(WidgetTester tester, Size size, Widget screen) async {
  // setSurfaceSize alone only changes the layout constraints; the view must be
  // resized too or MediaQuery (and therefore deviceSizeOf) keeps reporting the
  // default 800x600 test window.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: demoOverrides,
      child: MaterialApp(
        locale: AppConstants.defaultLocale,
        supportedLocales: AppConstants.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
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

/// Unmounts the tree and drains the 2s ticks the demo location streams leave
/// behind, so tests end without "A Timer is still pending" noise.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  final screens = <String, Widget Function()>{
    'LoginScreen': () => const LoginScreen(),
    'OtpScreen': () => const OtpScreen(phone: '771234567'),
    'RegisterScreen': () => const RegisterScreen(),
    'DocumentsScreen': () => const DocumentsScreen(),
    'HomeScreen': () => const HomeScreen(),
    'OffersScreen': () => const OffersScreen(),
    'EarningsScreen': () => const EarningsScreen(),
    'PayoutRequestScreen': () => const PayoutRequestScreen(),
    'RideTrackingScreen': () => const RideTrackingScreen(rideId: DemoData.rideId),
  };

  for (final screen in screens.entries) {
    for (final viewport in _viewports.entries) {
      testWidgets('${screen.key} renders without overflow at ${viewport.key}',
          (tester) async {
        await pumpAtViewport(tester, viewport.value, screen.value());
        expect(tester.takeException(), isNull);
        await disposeTree(tester);
      });
    }
  }

  group('adaptive navigation shell', () {
    testWidgets('bottom NavigationBar on mobile', (tester) async {
      await pumpAtViewport(
        tester,
        _viewports['mobile (375px)']!,
        const DriverNavShell(location: '/home', child: HomeScreen()),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('shows all five destinations and selects Documents', (tester) async {
      await pumpAtViewport(
        tester,
        _viewports['mobile (375px)']!,
        const DriverNavShell(
          location: '/documents',
          child: DocumentsScreen(),
        ),
      );

      final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navigation.destinations, hasLength(5));
      expect(navigation.selectedIndex, 3);
      expect(navigation.destinations.map((d) => d.label), contains('المستندات'));
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('compact NavigationRail on tablet', (tester) async {
      await pumpAtViewport(
        tester,
        _viewports['tablet (768px)']!,
        const DriverNavShell(location: '/offers', child: OffersScreen()),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('extended NavigationRail on desktop', (tester) async {
      await pumpAtViewport(
        tester,
        _viewports['desktop (1280px)']!,
        const DriverNavShell(location: '/earnings', child: EarningsScreen()),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  });

  testWidgets('primary buttons meet the 44px minimum touch target on mobile',
      (tester) async {
    await pumpAtViewport(
      tester,
      const Size(375, 700),
      const LoginScreen(),
    );
    final buttons = find.byType(ElevatedButton);
    expect(buttons, findsWidgets);
    for (var i = 0; i < buttons.evaluate().length; i++) {
      expect(
        tester.getRect(buttons.at(i)).height,
        greaterThanOrEqualTo(44),
        reason: 'ElevatedButton #$i is below the 44px touch-target minimum',
      );
    }
    await disposeTree(tester);
  });
}
