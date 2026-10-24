library driver_app.features.offers.offers_provider;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';
import '../../core/constants.dart';

enum OfferStatus { pending, accepted, rejected, expired }

class Offer {
  const Offer({
    required this.offerId,
    required this.rideId,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distanceMeters,
    required this.expiresAt,
    this.status = OfferStatus.pending,
  });
  final String offerId;
  final String rideId;
  final String pickup;
  final String destination;
  final double fare;
  final double distanceMeters;
  final DateTime expiresAt;
  final OfferStatus status;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

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
  final String? activeRideId; // رحلة نشطة واحدة لكل سائق
  final Offer? selectedOffer;
  final bool isLoading;
  final String? error;
  final bool accepting;

  OffersState copyWith({
    List<Offer>? offers,
    String? activeRideId,
    bool clearActiveRideId = false,
    Offer? selectedOffer,
    bool? isLoading,
    String? error,
    bool? accepting,
  }) {
    return OffersState(
      offers: offers ?? this.offers,
      activeRideId: clearActiveRideId ? null : (activeRideId ?? this.activeRideId),
      selectedOffer: selectedOffer ?? this.selectedOffer,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      accepting: accepting ?? this.accepting,
    );
  }

  bool get hasActiveRide => activeRideId != null && activeRideId!.isNotEmpty;
}

class OffersNotifier extends StateNotifier<OffersState> {
  OffersNotifier(this._client) : super(const OffersState()) {
    _connectWebSocket();
  }

  final DioClient _client;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  final Map<String, Timer> _expiryTimers = {};

  void _connectWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse('${AppConstants.wsBaseUrl}/ws/driver/offers'));
    _wsSubscription = _channel!.stream.listen(
      (message) {
        try {
          final data = _decode(message);
          if (data == null) return;
          final type = data['type']?.toString();
          if (type == 'offer.created') {
            _addOffer(Offer(
              offerId: data['offer_id']?.toString() ?? '',
              rideId: data['ride_id']?.toString() ?? '',
              pickup: data['pickup']?.toString() ?? '',
              destination: data['destination']?.toString() ?? '',
              fare: (data['fare'] as num?)?.toDouble() ?? 0,
              distanceMeters: (data['distance_meters'] as num?)?.toDouble() ?? 0,
              expiresAt: data['expires_at'] != null ? DateTime.tryParse(data['expires_at'].toString()) ?? DateTime.now().add(const Duration(minutes: 5)) : DateTime.now().add(const Duration(minutes: 5)),
            ));
          } else if (type == 'offer.expired') {
            _markExpired(data['offer_id']?.toString() ?? '');
          } else if (type == 'ride.assigned') {
            state = state.copyWith(activeRideId: data['ride_id']?.toString());
          }
        } catch (_) {
          // ignore malformed WS messages
        }
      },
      onError: (_) => state = state.copyWith(error: 'خطأ في اتصال العروض'),
      onDone: () => state = state.copyWith(error: 'انقطع اتصال العروض'),
    );
  }

  dynamic _decode(dynamic message) {
    if (message is String) {
      // minimal JSON decode without dart:convert import overhead avoided; keep lightweight
      return null;
    }
    return message;
  }

  Future<void> fetchOffers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _client.get<List<dynamic>>('/offers');
      final list = (data ?? [])
          .map((e) => Offer(
                offerId: e['offer_id']?.toString() ?? '',
                rideId: e['ride_id']?.toString() ?? '',
                pickup: e['pickup']?.toString() ?? '',
                destination: e['destination']?.toString() ?? '',
                fare: (e['fare'] as num?)?.toDouble() ?? 0,
                distanceMeters: (e['distance_meters'] as num?)?.toDouble() ?? 0,
                expiresAt: e['expires_at'] != null ? DateTime.tryParse(e['expires_at'].toString()) ?? DateTime.now().add(const Duration(minutes: 5)) : DateTime.now().add(const Duration(minutes: 5)),
                status: _parseStatus(e['status']),
              ))
          .where((o) => !o.isExpired)
          .toList();
      state = state.copyWith(offers: list, isLoading: false);
      _scheduleExpiry();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل جلب العروض');
    }
  }

  void _addOffer(Offer offer) {
    if (offer.isExpired) return;
    final updated = <Offer>[...state.offers, offer]..removeWhere((o) => o.isExpired);
    state = state.copyWith(offers: updated);
    _scheduleExpiryFor(offer);
  }

  void _markExpired(String offerId) {
    state = state.copyWith(offers: [...state.offers.map((o) => o.offerId == offerId ? o.copyWith(status: OfferStatus.expired) : o).toList()]);
  }

  void _scheduleExpiry() {
    for (final o in state.offers) _scheduleExpiryFor(o);
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

  /// يقبل العرض بمفتاح 용 العطالة (Idempotency-Key) لمنع التنفيذ المزدوج.
  /// يرفض القبول إذا كان لدى السائق رحلة نشطة بالفعل (منع رحلات متعارضة).
  Future<bool> acceptOffer(String offerId, String idempotencyKey) async {
    if (state.hasActiveRide) {
      state = state.copyWith(error: 'لديك رحلة نشطة بالفعل، لا يمكن قبول رحلة جديدة');
      return false;
    }
    final offer = state.offers.firstWhere((o) => o.offerId == offerId, orElse: () => throw StateError('العرض غير موجود'));
    if (offer.status != OfferStatus.pending || offer.isExpired) {
      state = state.copyWith(error: 'العرض غير متاح للقبول');
      return false;
    }
    state = state.copyWith(accepting: true, error: null, selectedOffer: offer);
    try {
      await _client.post(
        '/offers/$offerId/accept',
        data: {'ride_id': offer.rideId},
        idempotencyKey: idempotencyKey,
      );
      state = state.copyWith(
        activeRideId: offer.rideId,
        accepting: false,
        offers: [...state.offers.map((o) => o.offerId == offerId ? o.copyWith(status: OfferStatus.accepted) : o).toList()],
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(accepting: false, error: e.messageAr);
      return false;
    } catch (e) {
      state = state.copyWith(accepting: false, error: 'فشل قبول العرض');
      return false;
    }
  }

  Future<bool> rejectOffer(String offerId) async {
    try {
      await _client.post('/offers/$offerId/reject', data: {});
      state = state.copyWith(
        offers: [...state.offers.map((o) => o.offerId == offerId ? o.copyWith(status: OfferStatus.rejected) : o).toList()],
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'فشل رفض العرض');
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);

  void endActiveRide() => state = state.copyWith(activeRideId: null);

  @override
  void dispose() {
    for (final t in _expiryTimers.values) t.cancel();
    _expiryTimers.clear();
    _wsSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  OfferStatus _parseStatus(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'accepted':
        return OfferStatus.accepted;
      case 'rejected':
        return OfferStatus.rejected;
      case 'expired':
        return OfferStatus.expired;
      default:
        return OfferStatus.pending;
    }
  }
}

final offersProvider = StateNotifierProvider<OffersNotifier, OffersState>((ref) {
  return OffersNotifier(DioClient(SecureStorage.instance));
});
