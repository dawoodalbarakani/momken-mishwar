
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/models/offer.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../view_models/offers_view_model.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                _ActiveRideNotice(
                  rideId: vm.activeRideId,
                  onDismiss: () => ref.read(offersViewModelProvider.notifier).clearError(),
                ),
                const SizedBox(height: UberSpacing.lg),
              ],
              Expanded(
                child: vm.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : vm.offers.isEmpty
                    ? const UberEmptyState(
                        icon: Icons.local_offer_outlined,
                        title: 'لا توجد عروض حالية',
                        message: 'اسحب لأسفل أو اضغط تحديث للتحقق من العروض الجديدة.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.read(offersViewModelProvider.notifier).fetchOffers(),
                        child: _OfferGrid(
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

/// Flat, unshadowed notice: a lock-out, not a card the driver acts on.
class _ActiveRideNotice extends StatelessWidget {
  final String? rideId;
  final VoidCallback onDismiss;

  const _ActiveRideNotice({required this.rideId, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return UberCard(
      background: UberColors.chipGray,
      elevated: false,
      padding: const EdgeInsets.symmetric(horizontal: UberSpacing.lg, vertical: UberSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: UberColors.black),
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
                  'معرف الرحلة: ${rideId ?? '—'} · أنهِ الرحلة الحالية قبل قبول عروض جديدة.',
                  style: UberTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: UberSpacing.sm),
          TextButton(onPressed: onDismiss, child: const Text('حسناً')),
        ],
      ),
    );
  }
}

class _OfferGrid extends ConsumerWidget {
  final List<Offer> offers;
  final bool hasActiveRide;
  final bool accepting;

  const _OfferGrid({required this.offers, required this.hasActiveRide, required this.accepting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = responsiveColumnCount(context);
    return GridView.builder(
      // Keeps pull-to-refresh working even when the grid fits on screen.
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: UberSpacing.sm,
        crossAxisSpacing: UberSpacing.sm,
        // Fixed row height instead of an aspect ratio: the card owns its
        // content height, so it cannot overflow as the viewport narrows.
        mainAxisExtent: 140,
      ),
      itemCount: offers.length,
      itemBuilder: (context, i) {
        final o = offers[i];
        final canRespond = o.status == OfferStatus.pending && !hasActiveRide;
        return UberCard(
          padding: const EdgeInsets.all(UberSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UberRouteLine(pickup: o.pickup, destination: o.destination),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${(o.distanceMeters / 1000).toStringAsFixed(1)} كم · تنتهي بعد ${o.expiresAt.difference(DateTime.now()).inMinutes} دقيقة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UberTypography.caption,
                    ),
                  ),
                  const SizedBox(width: UberSpacing.sm),
                  Text(
                    '${o.fare.toStringAsFixed(0)} ريال',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, color: UberColors.black),
                  ),
                ],
              ),
              const SizedBox(height: UberSpacing.md),
              if (canRespond)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: accepting ? null : () => _accept(context, ref, o),
                        child: const Text('قبول'),
                      ),
                    ),
                    const SizedBox(width: UberSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: accepting
                            ? null
                            : () => ref.read(offersViewModelProvider.notifier).rejectOffer(o.offerId),
                        child: const Text('رفض'),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: UberStatusPill(label: _statusLabel(o.status), tone: _statusTone(o.status)),
                ),
            ],
          ),
        );
      },
    );
  }

  void _accept(BuildContext context, WidgetRef ref, Offer o) {
    ref.read(offersViewModelProvider.notifier).acceptOffer(o.offerId).then((ok) {
      if (!context.mounted) return;
      final error = ref.read(offersViewModelProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'تم قبول العرض وتوجيهك للرحلة' : error ?? 'فشل القبول')),
      );
      if (ok && context.mounted) context.go('/ride-track/${o.rideId}');
    });
  }

  String _statusLabel(OfferStatus s) {
    switch (s) {
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

  UberStatusTone _statusTone(OfferStatus s) {
    switch (s) {
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
