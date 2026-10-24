library driver_app.ui.features.offers.view_models.offers_view_model;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/offers_repository.dart';
import '../../../../domain/models/offer.dart';

class OffersViewModel extends ChangeNotifier {
  OffersViewModel({required OffersRepository offersRepository}) : _offersRepository = offersRepository {
    _scheduleExpiry();
  }

  final OffersRepository _offersRepository;
  final Map<String, Timer> _expiryTimers = {};

  List<Offer> _offers = const [];
  List<Offer> get offers => _offers;

  String? _activeRideId;
  String? get activeRideId => _activeRideId;

  Offer? _selectedOffer;
  Offer? get selectedOffer => _selectedOffer;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _accepting = false;
  bool get accepting => _accepting;

  bool get hasActiveRide => _activeRideId != null && _activeRideId!.isNotEmpty;

  String _generateIdempotencyKey() {
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    final random = Random.secure().nextInt(900000) + 100000;
    return 'ride_${ms}_$random';
  }

  Future<void> fetchOffers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _offers = await _offersRepository.fetchOffers();
      _scheduleExpiry();
    } catch (e) {
      _error = 'فشل جلب العروض';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _scheduleExpiry() {
    for (final o in _offers) _scheduleExpiryFor(o);
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
    _offers = [..._offers.map((o) => o.offerId == offerId
        ? Offer(offerId: o.offerId, rideId: o.rideId, pickup: o.pickup, destination: o.destination, fare: o.fare, distanceMeters: o.distanceMeters, expiresAt: o.expiresAt, status: OfferStatus.expired)
        : o)].toList();
    notifyListeners();
  }

  void setActiveRideId(String? rideId) {
    _activeRideId = rideId;
    notifyListeners();
  }

  Future<bool> acceptOffer(String offerId) async {
    if (hasActiveRide) {
      _error = 'لديك رحلة نشطة بالفعل، لا يمكن قبول رحلة جديدة';
      notifyListeners();
      return false;
    }
    final offer = _offers.firstWhere((o) => o.offerId == offerId, orElse: () => throw StateError('العرض غير موجود'));
    if (offer.status != OfferStatus.pending || offer.isExpired) {
      _error = 'العرض غير متاح للقبول';
      notifyListeners();
      return false;
    }
    _accepting = true;
    _error = null;
    _selectedOffer = offer;
    notifyListeners();
    try {
      final key = _generateIdempotencyKey();
      final ok = await _offersRepository.acceptOffer(offerId, rideId: offer.rideId, idempotencyKey: key);
      if (ok) {
        _activeRideId = offer.rideId;
        _offers = [..._offers.map((o) => o.offerId == offerId
            ? Offer(offerId: o.offerId, rideId: o.rideId, pickup: o.pickup, destination: o.destination, fare: o.fare, distanceMeters: o.distanceMeters, expiresAt: o.expiresAt, status: OfferStatus.accepted)
            : o)].toList();
      }
      _accepting = false;
      notifyListeners();
      return ok;
    } catch (e) {
      _accepting = false;
      _error = 'فشل قبول العرض';
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectOffer(String offerId) async {
    try {
      final ok = await _offersRepository.rejectOffer(offerId);
      if (ok) {
        _offers = [..._offers.map((o) => o.offerId == offerId
            ? Offer(offerId: o.offerId, rideId: o.rideId, pickup: o.pickup, destination: o.destination, fare: o.fare, distanceMeters: o.distanceMeters, expiresAt: o.expiresAt, status: OfferStatus.rejected)
            : o)].toList();
        notifyListeners();
      }
      return ok;
    } catch (e) {
      _error = 'فشل رفض العرض';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void endActiveRide() {
    _activeRideId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _expiryTimers.values) t.cancel();
    _expiryTimers.clear();
    super.dispose();
  }
}

final offersViewModelProvider = ChangeNotifierProvider(
  (ref) => OffersViewModel(offersRepository: ref.read(offersRepositoryProvider)),
);
