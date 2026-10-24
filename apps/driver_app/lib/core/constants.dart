library driver_app.core.constants;

import 'dart:io';

class AppConstants {
  AppConstants._();

  static String get apiBaseUrl {
    return Platform.environment['MISHWAR_API_BASE_URL'] ?? 'http://10.0.2.2:4000';
  }

  static String get wsBaseUrl {
    return Platform.environment['MISHWAR_WS_BASE_URL'] ?? 'ws://10.0.2.2:4000';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  static const int maxRetries = 3;
  static const Duration retryBaseDelay = Duration(seconds: 2);

  static const List<Locale> supportedLocales = [Locale('ar', 'YE'), Locale('en', 'US')];
  static const Locale defaultLocale = Locale('ar', 'YE');

  static const String yemenCountryCode = '+967';
  static const int otpLength = 6;

  static String get mapApiKey {
    return Platform.environment['MISHWAR_MAP_API_KEY'] ?? '';
  }
}
