import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/mock/demo_repositories.dart';
import 'main.dart';

/// Demo entry point: runs the real driver app against the in-memory demo
/// back end (approved driver, live offers, full ride state machine).
///
/// Launch with:
///   flutter run -t lib/main_demo.dart
///
/// Demo login: phone +967770000001, OTP 123456. Ride start code: 4821.
void main() {
  runApp(ProviderScope(overrides: demoOverrides, child: const DriverApp()));
}
