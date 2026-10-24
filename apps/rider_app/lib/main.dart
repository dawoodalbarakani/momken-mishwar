library rider_app.main;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'core/app_constants.dart';
import 'ui/core/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: RiderApp()));
}

class RiderApp extends ConsumerWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'مشوار اليمن',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppConstants.supportedLocales,
      locale: AppConstants.defaultLocale,
      localeResolutionCallback: (locale, supported) {
        // Prefer Arabic (RTL default); fall back to English; then first supported.
        if (locale != null && locale.languageCode == 'ar') {
          return const Locale('ar', 'YE');
        }
        if (locale != null && locale.languageCode == 'en') {
          return const Locale('en', 'US');
        }
        return supported.isNotEmpty ? supported.first : AppConstants.defaultLocale;
      },
    );
  }
}
