
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/ride_repository.dart';
import '../../../../domain/models/product_option.dart';
import '../../../../domain/models/quote.dart';

/// The ride products offered at the review step, mirroring Uber's tier list.
/// Names and positioning are localised for the Yemen market; prices are shown
/// relative to the server [Quote] via [ProductOption.pricedFrom].
const List<ProductOption> kProductTiers = [
  ProductOption(
    id: 'economy',
    name: 'اقتصادية',
    description: 'رحلات بتكلفة أقل، وقت انتظار أطول',
    seats: 4,
    multiplier: 0.85,
    etaMinutes: 7,
  ),
  ProductOption(
    id: 'mishwar',
    name: 'ميشوار',
    description: 'رحلات اقتصادية، لك وحدك',
    seats: 4,
    multiplier: 1.0,
    etaMinutes: 4,
  ),
  ProductOption(
    id: 'comfort',
    name: 'Comfort',
    description: 'سيارات أحدث بمساحة أرجل أكبر',
    seats: 4,
    multiplier: 1.3,
    etaMinutes: 6,
  ),
  ProductOption(
    id: 'xl',
    name: 'ميشوار XL',
    description: 'رحلات لمجموعات حتى 6',
    seats: 6,
    multiplier: 1.6,
    etaMinutes: 9,
  ),
];

/// The tier pre-selected when the quote loads (the standard UberX-equivalent).
const String kDefaultTierId = 'mishwar';

class QuoteState {
  const QuoteState({
    this.quote,
    this.options = kProductTiers,
    this.selectedTierId,
    this.isLoading = false,
    this.error,
  });

  final Quote? quote;
  final List<ProductOption> options;
  final String? selectedTierId;
  final bool isLoading;
  final String? error;

  /// The currently chosen ride product, if a quote has loaded.
  ProductOption? get selectedOption {
    final id = selectedTierId;
    if (id == null) return null;
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  /// Estimated amount for the selected tier, or null until a quote is present.
  int? get selectedPrice {
    final quote = this.quote;
    final option = selectedOption;
    if (quote == null || option == null) return null;
    return option.pricedFrom(quote.estimatedAmount);
  }

  QuoteState copyWith({
    Quote? quote,
    List<ProductOption>? options,
    String? selectedTierId,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return QuoteState(
      quote: quote ?? this.quote,
      options: options ?? this.options,
      selectedTierId: selectedTierId ?? this.selectedTierId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuoteState &&
      other.quote == quote &&
      other.selectedTierId == selectedTierId &&
      other.isLoading == isLoading &&
      other.error == error;

  @override
  int get hashCode => Object.hash(quote, selectedTierId, isLoading, error);
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
      // Land on the default tier as soon as the estimate is in, so the review
      // step always shows a selectable, priced product list.
      state = state.copyWith(
        quote: quote,
        isLoading: false,
        options: kProductTiers,
        selectedTierId: kDefaultTierId,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب تقدير الأجرة');
      return false;
    }
  }

  /// Switches the chosen ride product. Ignored for unknown tier ids.
  void selectTier(String tierId) {
    if (!state.options.any((o) => o.id == tierId)) return;
    state = state.copyWith(selectedTierId: tierId);
  }
}

final quoteViewModelProvider = NotifierProvider<QuoteNotifier, QuoteState>(QuoteNotifier.new);
