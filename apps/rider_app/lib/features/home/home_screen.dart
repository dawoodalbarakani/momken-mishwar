library rider_app.features.home.home_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants.dart';
import '../../core/map_provider.dart';
import '../../core/constants.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    return Scaffold(
      body: Stack(
        children: [
          // Map placeholder. Replace with GoogleMap widget backed by a real MapProvider.
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey.shade200,
            child: const Center(child: Text('الخريطة (بانتظار مزود خرائط حقيقي)')),
          ),
          if (state.connectionStatus == ConnectionStatus.offline)
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
                    onPressed: () => ref.read(homeProvider.notifier).locateMe(),
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
                      final results = await ref.read(homeProvider.notifier).searchPlaces(q);
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
                  label: Text(state.pickup != null ? 'نقطة الانطلاق: مٌحددة' : 'اختر نقطة الانطلاق'),
                  onDeleted: state.pickup != null ? () => ref.read(homeProvider.notifier).setPickup(null) : null,
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(state.destination != null ? 'الوجهة: مٌحددة' : 'اختر الوجهة'),
                  onDeleted: state.destination != null ? () => ref.read(homeProvider.notifier).setDestination(null) : null,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (state.pickup == null || state.destination == null) ? null : () => context.go('/quote'),
                    child: const Text('احسب الأجرة وانتقل إلى التقدير'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
