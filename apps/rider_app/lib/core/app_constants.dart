import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static String _env(String key, String fallback) {
    if (kIsWeb) return fallback;
    try {
      return Platform.environment[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String get apiBaseUrl {
    return _env('MISHWAR_API_BASE_URL', 'http://10.0.2.2:4000');
  }

  static String get wsBaseUrl {
    return _env('MISHWAR_WS_BASE_URL', 'ws://10.0.2.2:4000');
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
    return _env('MISHWAR_MAP_API_KEY', '');
  }
}
