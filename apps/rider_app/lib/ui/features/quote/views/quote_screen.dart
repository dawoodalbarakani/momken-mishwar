
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_constants.dart';
import '../view_models/quote_view_model.dart';

class QuoteScreen extends ConsumerWidget {
  const QuoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(quoteViewModelProvider);
    final currencyFormat = NumberFormat.simpleCurrency(locale: AppConstants.defaultLocale.languageCode);

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('تقدير الأجرة')),
          body: vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : vm.error != null
              ? Center(child: Text(vm.error!))
              : vm.quote == null
              ? const Center(child: Text('لا يوجد تقدير'))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('السعر مقدر من الخادم (لا تثق بسعر التطبيق)'),
                      const SizedBox(height: 16),
                      Text(
                        '${currencyFormat.format(double.tryParse(vm.quote!.estimatedAmount) ?? 0)} ${vm.quote!.currency}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('إصدار تسعير: ${vm.quote!.ruleVersion}'),
                      const SizedBox(height: 24),
                      _row('المسافة', '${vm.quote!.distanceMeters.toStringAsFixed(1)} كم'),
                      _row('المدة المتوقعة', '${vm.quote!.durationSeconds ~/ 60} دقيقة'),
                      _row('رسوم إضافية', '${currencyFormat.format(double.tryParse(vm.quote!.extraFees) ?? 0)} ${vm.quote!.currency}'),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text('السعر النهائي يتم حسابه من قبل الخادم عند إتمام الرحلة.', style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => context.go('/ride-request'),
                          child: const Text('تأكيد الطلب'),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}
