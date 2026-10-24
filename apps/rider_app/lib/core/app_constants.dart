library rider_app.core.app_constants;

import 'dart:io';

class AppConstants {
  AppConstants._();

  /// Base URL of the v1 API. Read from MISHWAR_API_BASE_URL env var; falls back
  /// to the Android emulator localhost for development. Never commit real URLs.
  static String get apiBaseUrl {
    return Platform.environment['MISHWAR_API_BASE_URL'] ?? 'http://10.0.2.2:4000';
  }

  /// WebSocket URL for live ride events.
  static String get wsBaseUrl {
    return Platform.environment['MISHWAR_WS_BASE_URL'] ?? 'ws://10.0.2.2:4000';
  }

  /// HTTP connect / receive timeouts.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Max retry attempts for idempotent/write requests under flaky connectivity.
  static const int maxRetries = 3;

  /// Base retry backoff delay (exponential backoff builds on this).
  static const Duration retryBaseDelay = Duration(seconds: 2);

  /// Supported app locales. Arabic first (RTL default).
  static const List<Locale> supportedLocales = [Locale('ar', 'YE'), Locale('en', 'US')];
  static const Locale defaultLocale = Locale('ar', 'YE');

  /// Yemen phone country code.
  static const String yemenCountryCode = '+967';

  /// OTP length in digits.
  static const int otpLength = 6;

  /// Map provider API key placeholder. Must come from the provider console
  /// (Google Cloud / Mapbox) via env var and MUST never be committed.
  static String get mapApiKey {
    return Platform.environment['MISHWAR_MAP_API_KEY'] ?? '';
  }
}
