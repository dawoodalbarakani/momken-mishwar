library driver_app.ui.features.ride_tracking.views.ride_tracking_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/ride.dart';
import '../view_models/ride_tracking_view_model.dart';

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
  Widget build(BuildContext context) {
    final vm = ref.watch(rideTrackingViewModelProvider(widget.rideId));
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text('تتبع الرحلة ${widget.rideId}')),
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
                        Text('الحالة: ${_label(vm.status)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (vm.pickup != null) Text('نقطة الالتقاط: ${vm.pickup}'),
                        if (vm.destination != null) Text('الوجهة: ${vm.destination}'),
                        if (vm.customerName != null) Text('الراكب: ${vm.customerName}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('بيانات الموقع: '),
                            Text(vm.isConnected ? 'مباشر' : 'غير متصل', style: TextStyle(color: vm.isConnected ? Colors.green : Colors.orange)),
                          ],
                        ),
                        if (vm.cancellation != null) ...[
                          const SizedBox(height: 12),
                          Text('تم الإلغاء: ${vm.cancellation!.reason} (${vm.cancellation!.actor})', style: const TextStyle(color: Colors.red)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!vm.verifiedAssignment)
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: vm.isLoading ? null : () async {
                        final ok = await vm.verifyAssignment();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'تم التحقق من إسناد الرحلة' : 'فشل التحقق من الإسناد')),
                        );
                      },
                      child: const Text('تحقق من إسناد الرحلة'),
                    ),
                  ),
                if (vm.verifiedAssignment && !vm.started) ...[
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
                      onPressed: vm.isLoading ? null : () => vm.startRide(_startCodeController.text),
                      child: const Text('بدء الرحلة'),
                    ),
                  ),
                ],
                if (vm.started && !vm.completed) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: vm.isLoading ? null : () => vm.completeRide(),
                      child: const Text('إنهاء الرحلة'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: vm.isLoading ? null : () => _showCancelDialog(context, vm),
                    child: const Text('إلغاء الرحلة'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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

  void _showCancelDialog(BuildContext context, RideTrackingViewModel vm) {
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
              vm.cancelRide(reason: controller.text.trim(), actor: 'driver');
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
