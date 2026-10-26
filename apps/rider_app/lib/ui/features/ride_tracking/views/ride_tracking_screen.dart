
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/map_surface.dart';
import '../../../core/responsive.dart';
import '../view_models/ride_tracking_view_model.dart';

class RideTrackingScreen extends ConsumerWidget {
  final String rideId;
  const RideTrackingScreen({required this.rideId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rideTrackingViewModelProvider(rideId));
    return Scaffold(
      appBar: AppBar(title: Text('تتبع الرحلة $rideId')),
      body: Column(
        children: [
          Expanded(
            child: MapSurface(
              initialCenter: state.driverLocation ?? MapSurface.defaultCenter,
              initialZoom: 15,
              markerPosition: state.driverLocation,
              markerLabel: 'السائق',
              placeholderLabel: state.driverLocation == null
                  ? 'انتظار موقع السائق...'
                  : 'موقع السائق على الخريطة',
            ),
          ),
          Padding(
            padding: context.responsivePadding,
            child: ContentMaxWidth(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.driverName != null) Text('السائق: ${state.driverName}'),
                  if (state.vehiclePlate != null) Text('المركبة: ${state.vehiclePlate}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Flexible(child: Text('عمر البيانات: ')),
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
                  ElevatedButton(
                    onPressed: () async {
                      final ok = await ref
                          .read(rideTrackingViewModelProvider(rideId).notifier)
                          .cancelRide();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'تم إلغاء الرحلة' : 'فشل الإلغاء')),
                      );
                    },
                    child: const Text('إلغاء الرحلة'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم دعم البلاغ قريباً'))),
                    child: const Text('إبلاغ عن مشكلة'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
