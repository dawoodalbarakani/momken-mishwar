
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/ride_tracking_view_model.dart';

class RideTrackingScreen extends ConsumerWidget {
  final String rideId;
  const RideTrackingScreen({required this.rideId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(rideTrackingViewModelProvider(rideId));
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text('تتبع الرحلة $rideId')),
          body: Column(
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey.shade200,
                  child: vm.driverLocation == null
                      ? const Center(child: Text('انتظار موقع السائق...'))
                      : const Center(child: Text('موقع السائق على الخريطة')),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (vm.driverName != null) Text('السائق: ${vm.driverName}'),
                    if (vm.vehiclePlate != null) Text('المركبة: ${vm.vehiclePlate}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('عمر البيانات: '),
                        Text(vm.isLocationFresh ? 'مباشر' : 'قديم/غير موثوق', style: TextStyle(color: vm.isLocationFresh ? Colors.green : Colors.orange)),
                      ],
                    ),
                    if (vm.startCode != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.blue.shade50,
                        child: Text('رمز بدء الرحلة: ${vm.startCode}', textAlign: TextAlign.center),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final ok = await vm.cancelRide();
                          if (!context.mounted) return;
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
                      child: OutlinedButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم دعم البلاغ قريباً'))),
                        child: const Text('إبلاغ عن مشكلة'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
