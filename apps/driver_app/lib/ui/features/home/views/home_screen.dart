
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../domain/models/available_ride.dart';
import '../view_models/home_view_model.dart';

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
      ref.read(homeViewModelProvider.notifier).fetchAvailableRides();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(homeViewModelProvider);
    final online = vm.availability == AvailabilityStatus.online;
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية (سائق)'), actions: [
        IconButton(
          icon: Icon(online ? Icons.circle_outlined : Icons.circle, color: online ? Colors.green : Colors.grey),
          onPressed: () => ref.read(homeViewModelProvider.notifier).toggleAvailability(),
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
                        onPressed: vm.isLoading
                            ? null
                            : () => ref.read(homeViewModelProvider.notifier).toggleAvailability(),
                      ),
                    ),
                    if (vm.lastLocationUpdate != null) ...[
                      const SizedBox(height: 8),
                      Text('آخر تحديث موقع: ${vm.lastLocationUpdate!.toLocal().toString().substring(11, 19)}'),
                    ],
                    if (vm.connectionStatus == ConnectionStatus.offline)
                      const Text('لا يوجد اتصال بالإنترنت', style: TextStyle(color: Colors.red, fontSize: 12)),
                    if (vm.error != null)
                      Text(vm.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('الرحلات المتاحة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: vm.availableRides.isEmpty
                  ? const Center(child: Text('لا توجد رحلات متاحة حالياً'))
                  : ListView.builder(
                      itemCount: vm.availableRides.length,
                      itemBuilder: (context, i) {
                        final r = vm.availableRides[i];
                        return Card(
                          child: ListTile(
                            title: Text('${r.pickup} → ${r.destination}'),
                            subtitle: Text('الأجرة: ${r.fare.toStringAsFixed(0)} ريال · المسافة: ${(r.distanceMeters / 1000).toStringAsFixed(1)} كم · تنتهي بعد ${r.expiresAt.difference(DateTime.now()).inMinutes} دقيقة'),
                            trailing: ElevatedButton(
                              onPressed: vm.availability == AvailabilityStatus.offline
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
