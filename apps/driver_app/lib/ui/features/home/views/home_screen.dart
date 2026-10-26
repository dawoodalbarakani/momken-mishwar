
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../domain/models/available_ride.dart';
import '../../../core/responsive.dart';
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
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AvailabilityCard(
                online: online,
                isLoading: vm.isLoading,
                lastLocationUpdate: vm.lastLocationUpdate,
                connectionStatus: vm.connectionStatus,
                error: vm.error,
                onToggle: () => ref.read(homeViewModelProvider.notifier).toggleAvailability(),
              ),
              const SizedBox(height: 16),
              Text(
                'الرحلات المتاحة',
                style: TextStyle(
                  fontSize: fluidFontSize(context, min: 16, max: 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: vm.availableRides.isEmpty
                    ? const Center(child: Text('لا توجد رحلات متاحة حالياً'))
                    : _RideList(rides: vm.availableRides, offline: vm.availability == AvailabilityStatus.offline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final bool online;
  final bool isLoading;
  final DateTime? lastLocationUpdate;
  final ConnectionStatus connectionStatus;
  final String? error;
  final VoidCallback onToggle;

  const _AvailabilityCard({
    required this.online,
    required this.isLoading,
    required this.connectionStatus,
    required this.onToggle,
    this.lastLocationUpdate,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'حالة التوفر: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Chip(
                    label: Text(
                      online ? 'متصل (أونلاين)' : 'غير متصل (أوفلاين)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: online ? Colors.green.shade50 : Colors.grey.shade50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: Icon(online ? Icons.cancel : Icons.check_circle),
              label: Text(online ? 'الانقطاع عن العمل' : 'الاتصال بالعمل'),
              onPressed: isLoading ? null : onToggle,
            ),
            if (lastLocationUpdate != null) ...[
              const SizedBox(height: 8),
              Text('آخر تحديث موقع: ${lastLocationUpdate!.toLocal().toString().substring(11, 19)}'),
            ],
            if (connectionStatus == ConnectionStatus.offline)
              const Text('لا يوجد اتصال بالإنترنت', style: TextStyle(color: Colors.red, fontSize: 12)),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// One column on mobile, two once there's room for them side-by-side.
class _RideList extends StatelessWidget {
  final List<AvailableRide> rides;
  final bool offline;

  const _RideList({required this.rides, required this.offline});

  @override
  Widget build(BuildContext context) {
    final columns = responsiveColumnCount(context);
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: columns == 1 ? 3.2 : 2.6,
      ),
      itemCount: rides.length,
      itemBuilder: (context, i) {
        final r = rides[i];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r.pickup} → ${r.destination}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        'الأجرة: ${r.fare.toStringAsFixed(0)} ريال · المسافة: ${(r.distanceMeters / 1000).toStringAsFixed(1)} كم · تنتهي بعد ${r.expiresAt.difference(DateTime.now()).inMinutes} دقيقة',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: offline ? null : () => context.go('/offers'),
                  child: const Text('عرض العروض'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
