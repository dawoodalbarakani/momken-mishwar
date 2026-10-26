import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is wired to the in-memory demo back end.
///
/// Defaults to false for the real entry point (main.dart); `demoOverrides`
/// from data/mock/demo_repositories.dart flips it to true for main_demo.dart
/// and widget tests. Auth screens use it to prefill the demo credentials.
final demoModeProvider = Provider<bool>((_) => false);
