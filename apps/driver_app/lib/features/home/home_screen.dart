library driver_app.features.home.home_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants.dart';
import '../../core/connectivity.dart';
import '../../core/map_provider.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeProvider.notifier).fetchAvailableRides();
      ref.read(homeProvider.notifier).fetchEarningsSummary();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    final online = state.availability == AvailabilityStatus.online;
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية (سائق)'), actions: [
        IconButton(
          icon: Icon(online ? Icons.circle_outlined : Icons.circle, color: online ? Colors.green : Colors.grey),
          onPressed: () => ref.read(homeProvider.notifier).toggleAvailability(),
        ),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text('حالة التوفر: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(online ? 'متصل (أونلاين)' : 'غير متصل (أوفلاين)'),
                          backgroundColor: online ? Colors.green.shade50 : Colors.grey.shade50,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: Icon(online ? Icons.cancel : Icons.check_circle),
                        label: Text(online ? 'الانقطاع عن العمل' : 'الاتصال بالعمل'),
                        onPressed: state.isLoading ? null : () => ref.read(homeProvider.notifier).toggleAvailability(),
                      ),
                    ),
                    if (state.lastLocationUpdate != null) ...[
                      const SizedBox(height: 8),
                      Text('آخر تحديث موقع: ${state.lastLocationUpdate!.toLocal().toString().substring(11, 19)}'),
                    ],
                    if (state.connectionStatus == ConnectionStatus.offline)
                      const Text('لا يوجد اتصال بالإنترنت', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('الرحلات المتاحة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: state.availableRides.isEmpty
                  ? const Center(child: Text('لا توجد رحلات متاحة حالياً'))
                  : ListView.builder(
                      itemCount: state.availableRides.length,
                      itemBuilder: (context, i) {
                        final r = state.availableRides[i];
                        return Card(
                          child: ListTile(
                            title: Text('${r.pickup} → ${r.destination}'),
                            subtitle: Text('الأجرة: ${r.fare.toStringAsFixed(0)} ريال · المسافة: ${(r.distanceMeters / 1000).toStringAsFixed(1)} كم · تنتهي بعد ${r.expiresAt.difference(DateTime.now()).inMinutes} دقيقة'),
                            trailing: ElevatedButton(
                              onPressed: state.availability == AvailabilityStatus.offline
                                  ? null
                                  : () => context.go('/offers'),
                              child: const Text('عرض العروض'),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
