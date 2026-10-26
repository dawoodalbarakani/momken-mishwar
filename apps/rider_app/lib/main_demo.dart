import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/mock/demo_repositories.dart';
import 'main.dart';

/// Demo entry point: runs the real app against the in-memory demo back end.
///
/// Launch with:
///   flutter run -t lib/main_demo.dart
///
/// Demo login: phone +967771234567, OTP 123456.
void main() {
  runApp(ProviderScope(overrides: demoOverrides, child: const RiderApp()));
}
