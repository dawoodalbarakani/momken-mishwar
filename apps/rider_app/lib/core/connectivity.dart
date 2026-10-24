library rider_app.core.connectivity;

import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus { online, offline, unknown }

/// Wrapper around connectivity_plus to detect internet outages.
class ConnectivityService {
  ConnectivityService._();
  static final Connectivity _connectivity = Connectivity();

  /// Stream of connectivity status changes.
  static Stream<ConnectionStatus> watch() async* {
    yield await check();
    await for (final results in _connectivity.onConnectivityChanged) {
      yield _map(results);
    }
  }

  /// One-shot connectivity check.
  static Future<ConnectionStatus> check() async {
    final results = await _connectivity.checkConnectivity();
    return _map(results);
  }

  static ConnectionStatus _map(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return ConnectionStatus.offline;
    }
    if (results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.mobile || r == ConnectivityResult.ethernet)) {
      return ConnectionStatus.online;
    }
    return ConnectionStatus.unknown;
  }
}
