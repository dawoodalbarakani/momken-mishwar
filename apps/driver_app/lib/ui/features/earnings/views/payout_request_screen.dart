library driver_app.ui.features.earnings.views.payout_request_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../view_models/earnings_view_model.dart';

class PayoutRequestScreen extends ConsumerStatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  ConsumerState<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends ConsumerState<PayoutRequestScreen> {
  final _amountController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _request() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }
    setState(() => _submitting = true);
    final vm = ref.read(earningsViewModelProvider);
    vm.requestPayout(amount).then((ok) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'تم إرسال طلب التسوية للمراجعة' : vm.error ?? 'فشل الإرسال')),
      );
      if (ok) context.go('/earnings');
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(earningsViewModelProvider);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('طلب تسوية / نزاع مالي')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('اطلب مراجعة مبلغ أو تسجيل نزاع مالي على مستحقاتك.'),
                const SizedBox(height: 16),
                Text('صافي المستحقات المتاح: ${vm.netPayable.toStringAsFixed(0)} ريال', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ المطلوب (ريال)', hintText: 'أدخل المبلغ'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _request,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('إرسال الطلب'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => context.go('/earnings'), child: const Text('العودة')),
              ],
            ),
          ),
        );
      },
    );
  }
}
