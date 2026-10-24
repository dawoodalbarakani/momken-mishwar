library driver_app.features.offers.offers_screen;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'offers_provider.dart';

class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  String _generateIdempotencyKey() {
    final random = Random.secure();
    return List.generate(16, (i) => random.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.isLoading ? null : () => ref.read(offersProvider.notifier).fetchOffers(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.hasActiveRide)
              Card(
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: const Icon(Icons.info, color: Colors.amber),
                  title: const Text('رحلة نشطة'),
                  subtitle: Text('معرف الرحلة: ${state.activeRideId} — لا يمكن قبول عروض جديدة حتى تنتهي الرحلة الحالية.'),
                  trailing: TextButton(onPressed: () => ref.read(offersProvider.notifier).clearError(), child: const Text('حسناً')),
                ),
              ),
            if (state.hasActiveRide) const SizedBox(height: 12),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.offers.isEmpty
                      ? const Center(child: Text('لا توجد عروض حالية'))
                      : RefreshIndicator(
                          onRefresh: () async => ref.read(offersProvider.notifier).fetchOffers(),
                          child: ListView.builder(
                            itemCount: state.offers.length,
                            itemBuilder: (context, i) {
                              final o = state.offers[i];
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
                                      if (o.status == OfferStatus.pending && !state.hasActiveRide) ...[
                                        SizedBox(
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: state.accepting ? null : () => _accept(ref, o),
                                            child: const Text('قبول'),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 40,
                                          child: OutlinedButton(onPressed: () => ref.read(offersProvider.notifier).rejectOffer(o.offerId), child: const Text('رفض')),
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
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(state.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  void _accept(WidgetRef ref, Offer o) {
    final key = _generateIdempotencyKey();
    ref.read(offersProvider.notifier).acceptOffer(o.offerId, key).then((ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'تم قبول العرض وتوجيهك للرحلة' : ref.read(offersProvider).error ?? 'فشل القبول')),
      );
      if (ok) context.go('/ride-track/${o.rideId}');
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
