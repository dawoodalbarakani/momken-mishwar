library rider_app.features.ride_tracking.ride_tracking_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants.dart';
import 'ride_tracking_provider.dart';

class RideTrackingScreen extends ConsumerWidget {
  final String rideId;
  const RideTrackingScreen({required this.rideId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rideTrackingProvider(rideId));
    return Scaffold(
      appBar: AppBar(title: Text('تتبع الرحلة $rideId')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              child: state.driverLocation == null
                  ? const Center(child: Text('انتظار موقع السائق...'))
                  : const Center(child: Text('موقع السائق على الخريطة')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.driverName != null) Text('السائق: ${state.driverName}'),
                if (state.vehiclePlate != null) Text('المركبة: ${state.vehiclePlate}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('عمر البيانات: '),
                    Text(state.isLocationFresh ? 'مباشر' : 'قديم/غير موثوق', style: TextStyle(color: state.isLocationFresh ? Colors.green : Colors.orange)),
                  ],
                ),
                if (state.startCode != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue.shade50,
                    child: Text('رمز بدء الرحلة: ${state.startCode}', textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final ok = await ref.read(rideTrackingProvider(rideId).notifier).cancelRide();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'تم إلغاء الرحلة' : 'فشل الإلغاء')),
                      );
                    },
                    child: const Text('إلغاء الرحلة'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم دعم البلاغ قريباً'))), child: const Text('إبلاغ عن مشكلة')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
