
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/models/offer.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../view_models/offers_view_model.dart';

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  @override
  void initState() {
    super.initState();
    // Requests are pushed to the driver in the real app; here the inbox is
    // polled once on arrival so the tab is never a dead end. Post-frame, so the
    // notifier isn't written to while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(offersViewModelProvider);
      final hasPending = state.offers.any((o) => o.status == OfferStatus.pending && !o.isExpired);
      if (!state.isLoading && !hasPending) {
        ref.read(offersViewModelProvider.notifier).fetchOffers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(offersViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: vm.isLoading
                ? null
                : () => ref.read(offersViewModelProvider.notifier).fetchOffers(),
          ),
        ],
      ),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.hasActiveRide) ...[
                _ActiveRideNotice(rideId: vm.activeRideId),
                const SizedBox(height: UberSpacing.md),
              ],
              Expanded(
                child: vm.isLoading && vm.offers.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : vm.offers.isEmpty
                    ? const UberEmptyState(
                        icon: Icons.local_offer_outlined,
                        title: 'لا توجد طلبات الآن',
                        message: 'ستظهر الطلبات هنا لحظة وصولها. اسحب لأسفل للتحقق.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.read(offersViewModelProvider.notifier).fetchOffers(),
                        child: _OfferList(
                          offers: vm.offers,
                          hasActiveRide: vm.hasActiveRide,
                          accepting: vm.accepting,
                        ),
                      ),
              ),
              UberErrorText(vm.error),
            ],
          ),
        ),
      ),
    );
  }
}

/// A lock-out with a way out: while a trip is running nothing else can be
/// accepted, so the notice's only job is to take the driver back to that trip.
class _ActiveRideNotice extends StatelessWidget {
  final String? rideId;

  const _ActiveRideNotice({required this.rideId});

  @override
  Widget build(BuildContext context) {
    return UberCard(
      padding: const EdgeInsets.all(UberSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.route, size: 20, color: UberColors.black),
          const SizedBox(width: UberSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رحلة نشطة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: UberColors.black),
                ),
                const SizedBox(height: UberSpacing.xxs),
                Text(
                  'أنهِ الرحلة الحالية قبل قبول طلبات جديدة.',
                  maxLines: 2,
                  style: UberTypography.caption,
                ),
              ],
            ),
          ),
          if (rideId != null) ...[
            const SizedBox(width: UberSpacing.sm),
            ElevatedButton(
              onPressed: () => context.go('/ride-track/$rideId'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: const Text('متابعة'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Requests stack vertically like a queue of decisions, each card sized by its
/// own content — no fixed row height to overflow when type or padding grows.
class _OfferList extends ConsumerWidget {
  final List<Offer> offers;
  final bool hasActiveRide;
  final bool accepting;

  const _OfferList({required this.offers, required this.hasActiveRide, required this.accepting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      // Keeps pull-to-refresh working even when the list fits on screen.
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: UberSpacing.sm),
      itemBuilder: (context, i) => _OfferCard(
        offer: offers[i],
        hasActiveRide: hasActiveRide,
        accepting: accepting,
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  final Offer offer;
  final bool hasActiveRide;
  final bool accepting;

  const _OfferCard({required this.offer, required this.hasActiveRide, required this.accepting});

  bool get _canRespond =>
      offer.status == OfferStatus.pending && !offer.isExpired && !hasActiveRide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UberCard(
      padding: const EdgeInsets.all(UberSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UberRouteLine(pickup: offer.pickup, destination: offer.destination),
                    const SizedBox(height: 6),
                    Text(
                      'مدى الرحلة ${(offer.distanceMeters / 1000).toStringAsFixed(1)} كم',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UberTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: UberSpacing.md),
              // Upfront decision data: what it pays, how far, and how long the
              // driver has to answer.
              UberCountdownRing(expiresAt: offer.expiresAt),
            ],
          ),
          const SizedBox(height: UberSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الأجرة', style: UberTypography.micro),
                    const SizedBox(height: UberSpacing.xxs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          offer.fare.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: UberColors.black,
                          ),
                        ),
                        const SizedBox(width: UberSpacing.xs),
                        const Text(
                          'ريال',
                          style: TextStyle(fontSize: 12, color: UberColors.mutedGray),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_canRespond)
                UberStatusPill(label: _statusLabel(offer), tone: _statusTone(offer)),
            ],
          ),
          if (_canRespond) ...[
            const SizedBox(height: UberSpacing.md),
            Row(
              children: [
                // Accept is the dominant action; decline stays available but
                // never competes with it for the thumb.
                Expanded(
                  child: ElevatedButton(
                    onPressed: accepting ? null : () => _accept(context, ref),
                    child: const Text('قبول'),
                  ),
                ),
                const SizedBox(width: UberSpacing.sm),
                SizedBox(
                  width: 104,
                  child: OutlinedButton(
                    onPressed: accepting
                        ? null
                        : () => ref.read(offersViewModelProvider.notifier).rejectOffer(offer.offerId),
                    child: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _accept(BuildContext context, WidgetRef ref) {
    ref.read(offersViewModelProvider.notifier).acceptOffer(offer.offerId).then((ok) {
      if (!context.mounted) return;
      final error = ref.read(offersViewModelProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'تم قبول الطلب وتوجيهك للرحلة' : error ?? 'فشل القبول')),
      );
      if (ok && context.mounted) context.go('/ride-track/${offer.rideId}');
    });
  }

  String _statusLabel(Offer o) {
    if (o.isExpired && o.status == OfferStatus.pending) return 'انتهت المدة';
    switch (o.status) {
      case OfferStatus.accepted:
        return 'مقبول';
      case OfferStatus.rejected:
        return 'مرفوض';
      case OfferStatus.expired:
        return 'منتهي';
      case OfferStatus.pending:
        return 'قيد الانتظار';
    }
  }

  UberStatusTone _statusTone(Offer o) {
    switch (o.status) {
      case OfferStatus.accepted:
        return UberStatusTone.active;
      case OfferStatus.rejected:
        return UberStatusTone.danger;
      case OfferStatus.expired:
      case OfferStatus.pending:
        return UberStatusTone.neutral;
    }
  }
}
