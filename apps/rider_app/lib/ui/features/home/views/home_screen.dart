library rider_app.ui.features.home.views.home_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/services/connectivity_service.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = ref.read(homeViewModelProvider);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.grey.shade200,
                child: const Center(child: Text('الخريطة (بانتظار مزود خرائط حقيقي)')),
              ),
              if (vm.connectionStatus == ConnectionStatus.offline)
                const Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Card(color: Colors.amber, child: Padding(padding: EdgeInsets.all(8), child: Text('لا يوجد اتصال بالإنترنت', textAlign: TextAlign.center))),
                ),
              Positioned(
                top: 56,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.my_location),
                        label: const Text('تحديد موقعي'),
                        onPressed: () => vm.locateMe(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 46,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن حي أو معلم',
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                        ),
                        onSubmitted: (q) async {
                          final results = await vm.searchPlaces(q);
                          // TODO: show place picker bottom sheet with results
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    Chip(
                      label: Text(vm.pickup != null ? 'نقطة الانطلاق: محدَّدة' : 'اختر نقطة الانطلاق'),
                      onDeleted: vm.pickup != null ? () => vm.setPickup(null) : null,
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(vm.destination != null ? 'الوجهة: محدَّدة' : 'اختر الوجهة'),
                      onDeleted: vm.destination != null ? () => vm.setDestination(null) : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (vm.pickup == null || vm.destination == null)
                            ? null
                            : () => context.go('/quote'),
                        child: const Text('احسب الأجرة وانتقل إلى التقدير'),
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
