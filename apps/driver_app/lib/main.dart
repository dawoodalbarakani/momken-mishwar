library driver_app.main;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'core/constants.dart';

void main() {
  runApp(const ProviderScope(child: DriverApp()));
}

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'تطبيق السائق - مشوار اليمن',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5E7F),
        fontFamily: 'Tajawal',
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppConstants.supportedLocales,
      locale: AppConstants.defaultLocale,
      localeResolutionCallback: (locale, supported) {
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
