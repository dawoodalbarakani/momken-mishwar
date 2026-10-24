
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/models/offer.dart';
import '../view_models/offers_view_model.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(offersViewModelProvider);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('العروض'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: vm.isLoading ? null : () => vm.fetchOffers(),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
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
                      trailing: TextButton(onPressed: () => vm.clearError(), child: const Text('حسناً')),
                    ),
                  ),
                if (vm.hasActiveRide) const SizedBox(height: 12),
                Expanded(
                  child: vm.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : vm.offers.isEmpty
                      ? const Center(child: Text('لا توجد عروض حالية'))
                      : RefreshIndicator(
                          onRefresh: () async => vm.fetchOffers(),
                          child: ListView.builder(
                            itemCount: vm.offers.length,
                            itemBuilder: (context, i) {
                              final o = vm.offers[i];
                              return Card(
                                child: ListTile(
                                  title: Text('${o.pickup} → ${o.destination}'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('الأجرة: ${o.fare.toStringAsFixed(0)} ريال · المسافة: ${(o.distanceMeters / 1000).toStringAsFixed(1)} كم'),
                                      Text('تنتهي بعد ${o.expiresAt.difference(DateTime.now()).inMinutes} دقيقة', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (o.status == OfferStatus.pending && !vm.hasActiveRide) ...[
                                        SizedBox(
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: vm.accepting ? null : () => _accept(context, vm, o),
                                            child: const Text('قبول'),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 40,
                                          child: OutlinedButton(onPressed: () => vm.rejectOffer(o.offerId), child: const Text('رفض')),
                                        ),
                                      ] else ...[
                                        Chip(label: Text(_statusLabel(o.status))),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                if (vm.error != null) ...[
                  const SizedBox(height: 8),
                  Text(vm.error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _accept(BuildContext context, OffersViewModel vm, Offer o) {
    vm.acceptOffer(o.offerId).then((ok) {
      if (!context.mounted) return;
      if (!vm.accepting) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'تم قبول العرض وتوجيهك للرحلة' : vm.error ?? 'فشل القبول')),
        );
      }
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
