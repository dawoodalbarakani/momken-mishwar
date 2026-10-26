
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/quote.dart';

class QuoteState {
  const QuoteState({this.quote, this.isLoading = false, this.error});

  final Quote? quote;
  final bool isLoading;
  final String? error;

  QuoteState copyWith({
    Quote? quote,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return QuoteState(
      quote: quote ?? this.quote,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuoteState &&
      other.quote == quote &&
      other.isLoading == isLoading &&
      other.error == error;

  @override
  int get hashCode => Object.hash(quote, isLoading, error);
}

/// Notifier for the fare quote screen.
class QuoteNotifier extends Notifier<QuoteState> {
  @override
  QuoteState build() => const QuoteState();

  RideRepository get _rideRepository => ref.read(rideRepositoryProvider);

  Future<bool> fetchQuote({required String pickup, required String destination}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final quote = await _rideRepository.fetchQuote(pickup: pickup, destination: destination);
      state = state.copyWith(quote: quote, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب تقدير الأجرة');
      return false;
    }
  }
}

final quoteViewModelProvider = NotifierProvider<QuoteNotifier, QuoteState>(QuoteNotifier.new);
