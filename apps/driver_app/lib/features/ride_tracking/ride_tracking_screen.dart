library driver_app.features.ride_tracking.ride_tracking_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ride_tracking_provider.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideTrackingScreen({required this.rideId, super.key});

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  final _startCodeController = TextEditingController();

  @override
  void dispose() {
    _startCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rideTrackingProvider(widget.rideId));
    return Scaffold(
      appBar: AppBar(title: Text('تتبع الرحلة ${state.rideId ?? widget.rideId}')),
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
                    Text('الحالة: ${_label(state.status)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (state.pickup != null) Text('نقطة الالتقاط: ${state.pickup}'),
                    if (state.destination != null) Text('الوجهة: ${state.destination}'),
                    if (state.customerName != null) Text('الراكب: ${state.customerName}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('بيانات الموقع: '),
                        Text(state.isLocationFresh ? 'مباشر' : 'قديم/غير موثوق', style: TextStyle(color: state.isLocationFresh ? Colors.green : Colors.orange)),
                      ],
                    ),
                    if (state.cancellation != null) ...[
                      const SizedBox(height: 12),
                      Text('تم الإلغاء: ${state.cancellation!.reason} (${state.cancellation!.actor})', style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!state.verifiedAssignment)
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : () async {
                    final ok = await ref.read(rideTrackingProvider(widget.rideId).notifier).verifyAssignment();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'تم التحقق من إسناد الرحلة' : 'فشل التحقق من الإسناد')),
                    );
                  },
                  child: const Text('تحقق من إسناد الرحلة'),
                ),
              ),
            if (state.verifiedAssignment && !state.started) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _startCodeController,
                decoration: const InputDecoration(labelText: 'أدخل رمز بدء الرحلة', hintText: 'أرقام الرمز'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : () => ref.read(rideTrackingProvider(widget.rideId).notifier).startRide(_startCodeController.text),
                  child: const Text('بدء الرحلة'),
                ),
              ),
            ],
            if (state.started && !state.completed) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : () => ref.read(rideTrackingProvider(widget.rideId).notifier).completeRide(),
                  child: const Text('إنهاء الرحلة'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: state.isLoading ? null : () => _showCancelDialog(ref),
                child: const Text('إلغاء الرحلة'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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

  void _showCancelDialog(WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الرحلة'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'سبب الإلغاء')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(rideTrackingProvider(widget.rideId).notifier).cancelRide(reason: controller.text.trim(), actor: 'driver');
            },
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  String _label(RideStatus s) {
    switch (s) {
      case RideStatus.assigned:
        return 'مسندة';
      case RideStatus.arriving:
        return 'قادم';
      case RideStatus.arrived:
        return 'وصل';
      case RideStatus.inProgress:
        return 'جارية';
      case RideStatus.completed:
        return 'مكتملة';
      case RideStatus.cancelled:
        return 'ملغاة';
    }
  }
}
