
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/ride.dart';
import '../view_models/ride_request_view_model.dart';

class RideRequestScreen extends ConsumerWidget {
  const RideRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(rideRequestViewModelProvider);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('طلب الرحلة')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('جاري البحث عن سائق قريب منك...'),
                const SizedBox(height: 24),
                if (vm.status == RideRequestStatus.driverFound && vm.driverName != null) ...[
                  Text('تم العثور على السائق: ${vm.driverName}'),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: vm.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: vm.status == RideRequestStatus.searching
                              ? () => vm.cancelRide()
                              : null,
                          child: const Text('إلغاء الطلب'),
                        ),
                ),
                if (vm.error != null) ...[
                  const SizedBox(height: 16),
                  Text(vm.error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
