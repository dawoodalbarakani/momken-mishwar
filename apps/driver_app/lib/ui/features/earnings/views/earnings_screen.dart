
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../view_models/earnings_view_model.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(earningsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الأرباح'), actions: [
        IconButton(icon: const Icon(Icons.request_quote_outlined), onPressed: () => context.go('/earnings/payout-request')),
      ]),
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
                    _row('إجمالي الأجرة', '${vm.totalFare.toStringAsFixed(0)} ريال'),
                    _row('عمولة المنصة', '-${vm.platformCommission.toStringAsFixed(0)} ريال'),
                    _row('صافي مستحقات السائق', '${vm.netPayable.toStringAsFixed(0)} ريال', isHighlight: true),
                    _row('النقد المحصل', '${vm.cashCollected.toStringAsFixed(0)} ريال'),
                    _row('مستحقات المنصة', '-${vm.platformReceivables.toStringAsFixed(0)} ريال'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('سجل الرحلات المكتملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : vm.completedRides.isEmpty
                  ? const Center(child: Text('لا توجد رحلات مكتملة'))
                  : RefreshIndicator(
                      onRefresh: () async => ref.read(earningsViewModelProvider.notifier).fetchEarnings(),
                      child: ListView.builder(
                        itemCount: vm.completedRides.length,
                        itemBuilder: (context, i) {
                          final r = vm.completedRides[i];
                          return ListTile(
                            title: Text('الرحلة ${r.rideId}'),
                            subtitle: Text('تم الإكمال في ${r.completedAt.toLocal().toString().substring(0, 16)}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${r.netToDriver.toStringAsFixed(0)} ريال', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('عمولة ${r.platformCommission.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            if (vm.error != null) Text(vm.error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal, color: isHighlight ? Colors.green : null)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isHighlight ? Colors.green : null)),
        ],
      ),
    );
  }
}
