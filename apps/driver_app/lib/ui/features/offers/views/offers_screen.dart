
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/models/offer.dart';
import '../../../core/responsive.dart';
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
              if (vm.hasActiveRide)
                Card(
                  color: Colors.amber.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.info, color: Colors.amber),
                    title: const Text('رحلة نشطة'),
                    subtitle: Text('معرف الرحلة: ${vm.activeRideId} — لا يمكن قبول عروض جديدة حتى تنتهي الرحلة الحالية.'),
                    trailing: TextButton(
                      onPressed: () => ref.read(offersViewModelProvider.notifier).clearError(),
                      child: const Text('حسناً'),
                    ),
                  ),
                ),
              if (vm.hasActiveRide) const SizedBox(height: 12),
              Expanded(
                child: vm.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : vm.offers.isEmpty
                    ? const Center(child: Text('لا توجد عروض حالية'))
                    : RefreshIndicator(
                        onRefresh: () async => ref.read(offersViewModelProvider.notifier).fetchOffers(),
                        child: _OfferGrid(offers: vm.offers, hasActiveRide: vm.hasActiveRide, accepting: vm.accepting),
                      ),
              ),
              if (vm.error != null) ...[
                const SizedBox(height: 8),
                Text(vm.error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
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
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: columns == 1 ? 2.6 : 2.2,
      ),
      itemCount: offers.length,
      itemBuilder: (context, i) {
        final o = offers[i];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${o.pickup} → ${o.destination}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('الأجرة: ${o.fare.toStringAsFixed(0)} ريال · المسافة: ${(o.distanceMeters / 1000).toStringAsFixed(1)} كم',
                          style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('تنتهي بعد ${o.expiresAt.difference(DateTime.now()).inMinutes} دقيقة',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (o.status == OfferStatus.pending && !hasActiveRide)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: accepting ? null : () => _accept(context, ref, o),
                        child: const Text('قبول'),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        onPressed: () => ref.read(offersViewModelProvider.notifier).rejectOffer(o.offerId),
                        child: const Text('رفض'),
                      ),
                    ],
                  )
                else
                  Chip(label: Text(_statusLabel(o.status))),
              ],
            ),
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
}
