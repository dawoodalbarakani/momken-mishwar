library driver_app.features.earnings.earnings_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'earnings_provider.dart';
import 'payout_request_screen.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(earningsProvider);
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
                    _row('إجمالي الأجرة', '${state.totalFare.toStringAsFixed(0)} ريال'),
                    _row('عمولة المنصة', '-${state.platformCommission.toStringAsFixed(0)} ريال'),
                    _row('صافي مستحقات السائق', '${state.netPayable.toStringAsFixed(0)} ريال', isHighlight: true),
                    _row('النقد المحصل', '${state.cashCollected.toStringAsFixed(0)} ريال'),
                    _row('مستحقات المنصة', '-${state.platformReceivables.toStringAsFixed(0)} ريال'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('سجل الرحلات المكتملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.completedRides.isEmpty
                      ? const Center(child: Text('لا توجد رحلات مكتملة'))
                      : ListView.builder(
                          itemCount: state.completedRides.length,
                          itemBuilder: (context, i) {
                            final r = state.completedRides[i];
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
            if (state.error != null) Text(state.error!, style: const TextStyle(color: Colors.red)),
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
