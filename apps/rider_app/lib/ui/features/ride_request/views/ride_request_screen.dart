
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/ride.dart';
import '../../../core/responsive.dart';
import '../view_models/ride_request_view_model.dart';

class RideRequestScreen extends ConsumerWidget {
  const RideRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rideRequestViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('طلب الرحلة')),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('جاري البحث عن سائق قريب منك...'),
              const SizedBox(height: 24),
              if (state.status == RideRequestStatus.driverFound && state.driverName != null) ...[
                Text('تم العثور على السائق: ${state.driverName}'),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: state.status == RideRequestStatus.searching
                            ? () => ref.read(rideRequestViewModelProvider.notifier).cancelRide()
                            : null,
                        child: const Text('إلغاء الطلب'),
                      ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(state.error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
