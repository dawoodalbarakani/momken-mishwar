
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/offers_repository.dart';
import '../../../../domain/models/offer.dart';

class OffersState {
  const OffersState({
    this.offers = const [],
    this.activeRideId,
    this.selectedOffer,
    this.isLoading = false,
    this.error,
    this.accepting = false,
  });

  final List<Offer> offers;
  final String? activeRideId;
  final Offer? selectedOffer;
  final bool isLoading;
  final String? error;
  final bool accepting;

  bool get hasActiveRide => activeRideId != null && activeRideId!.isNotEmpty;

  OffersState copyWith({
    List<Offer>? offers,
    String? activeRideId,
    Offer? selectedOffer,
    bool? isLoading,
    String? error,
    bool? accepting,
    bool clearActiveRide = false,
    bool clearError = false,
  }) {
    return OffersState(
      offers: offers ?? this.offers,
      activeRideId: clearActiveRide ? null : (activeRideId ?? this.activeRideId),
      selectedOffer: selectedOffer ?? this.selectedOffer,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      accepting: accepting ?? this.accepting,
    );
  }
}

class OffersNotifier extends Notifier<OffersState> {
  final Map<String, Timer> _expiryTimers = {};

  @override
  OffersState build() {
    ref.onDispose(() {
      for (final timer in _expiryTimers.values) {
        timer.cancel();
      }
      _expiryTimers.clear();
    });
    return const OffersState();
  }

  OffersRepository get _offersRepository => ref.read(offersRepositoryProvider);

  String _generateIdempotencyKey() {
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random.secure().nextInt(900000) + 100000;
    return 'ride_${ms}_$random';
  }

  Future<void> fetchOffers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final offers = await _offersRepository.fetchOffers();
      state = state.copyWith(offers: offers, isLoading: false);
      _scheduleExpiry();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب العروض');
    }
  }

  void _scheduleExpiry() {
    for (final offer in state.offers) {
      _scheduleExpiryFor(offer);
    }
  }

  void _scheduleExpiryFor(Offer offer) {
    _expiryTimers[offer.offerId]?.cancel();
    final delay = offer.expiresAt.difference(DateTime.now());
    if (delay.isNegative) return;
    _expiryTimers[offer.offerId] = Timer(delay, () {
      _markExpired(offer.offerId);
      _expiryTimers.remove(offer.offerId);
    });
  }

  void _markExpired(String offerId) {
    state = state.copyWith(
      offers: [
        for (final o in state.offers)
          if (o.offerId == offerId) o.copyWith(status: OfferStatus.expired) else o,
      ],
    );
  }

  void setActiveRideId(String? rideId) {
    state = rideId == null
        ? state.copyWith(clearActiveRide: true)
        : state.copyWith(activeRideId: rideId);
  }

  Future<bool> acceptOffer(String offerId) async {
    if (state.hasActiveRide) {
      state = state.copyWith(error: 'لديك رحلة نشطة بالفعل، لا يمكن قبول رحلة جديدة');
      return false;
    }
    final offer = state.offers.firstWhere(
      (o) => o.offerId == offerId,
      orElse: () => throw StateError('العرض غير موجود'),
    );
    if (offer.status != OfferStatus.pending || offer.isExpired) {
      state = state.copyWith(error: 'العرض غير متاح للقبول');
      return false;
    }
    state = state.copyWith(accepting: true, selectedOffer: offer, clearError: true);
    try {
      final key = _generateIdempotencyKey();
      final ok = await _offersRepository.acceptOffer(offerId, rideId: offer.rideId, idempotencyKey: key);
      if (ok) {
        state = state.copyWith(
          accepting: false,
          activeRideId: offer.rideId,
          offers: [
            for (final o in state.offers)
              if (o.offerId == offerId) o.copyWith(status: OfferStatus.accepted) else o,
          ],
        );
      } else {
        state = state.copyWith(accepting: false);
      }
      return ok;
    } catch (e) {
      state = state.copyWith(accepting: false, error: 'فشل قبول العرض');
      return false;
    }
  }

  Future<bool> rejectOffer(String offerId) async {
    try {
      final ok = await _offersRepository.rejectOffer(offerId);
      if (ok) {
        state = state.copyWith(
          offers: [
            for (final o in state.offers)
              if (o.offerId == offerId) o.copyWith(status: OfferStatus.rejected) else o,
          ],
        );
      }
      return ok;
    } catch (e) {
      state = state.copyWith(error: 'فشل رفض العرض');
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void endActiveRide() {
    state = state.copyWith(clearActiveRide: true);
  }
}

final offersViewModelProvider = NotifierProvider<OffersNotifier, OffersState>(OffersNotifier.new);
