library rider_app.features.quote.quote_provider;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class Quote {
  const Quote({
    required this.id,
    required this.estimatedAmount,
    required this.currency,
    required this.ruleVersion,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.extraFees,
  });
  final String id;
  /// Estimated amount as a decimal string from the server (never trust client-side price).
  final String estimatedAmount;
  final String currency;
  final String ruleVersion;
  final double distanceMeters;
  final int durationSeconds;
  final String extraFees;
}

class QuoteState {
  const QuoteState({this.quote, this.isLoading = false, this.error});
  final Quote? quote;
  final bool isLoading;
  final String? error;
}

class QuoteNotifier extends StateNotifier<QuoteState> {
  QuoteNotifier(this._client) : super(const QuoteState());
  final DioClient _client;

  Future<bool> fetchQuote({required String pickup, required String destination}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _client.post<Map<String, dynamic>>(
        '/quotes',
        data: {'pickup': pickup, 'destination': destination},
      );
      final q = Quote(
        id: data?['id']?.toString() ?? '',
        estimatedAmount: data?['estimated_amount']?.toString() ?? '0.00',
        currency: data?['currency']?.toString() ?? 'YER',
        ruleVersion: data?['rule_version']?.toString() ?? '',
        distanceMeters: _toDouble(data?['distance_meters']),
        durationSeconds: _toInt(data?['duration_seconds']),
        extraFees: data?['extra_fees']?.toString() ?? '0.00',
      );
      state = state.copyWith(isLoading: false, quote: q);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب تقدير الأجرة');
      return false;
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

final quoteProvider = StateNotifierProvider<QuoteNotifier, QuoteState>((ref) {
  return QuoteNotifier(DioClient(SecureStorage.instance)); // TODO: inject shared DioClient
});
