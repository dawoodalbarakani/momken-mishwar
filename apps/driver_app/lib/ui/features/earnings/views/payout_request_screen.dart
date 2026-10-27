
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../view_models/earnings_view_model.dart';
import '../../../../l10n/app_localizations.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.payoutInvalidAmount)));
      return;
    }
    setState(() => _submitting = true);
    ref.read(earningsViewModelProvider.notifier).requestPayout(amount).then((ok) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? AppLocalizations.of(context)!.payoutRequestSent : ref.read(earningsViewModelProvider).error ?? AppLocalizations.of(context)!.payoutRequestFailed)),
      );
      if (ok) context.go('/earnings');
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(earningsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.payoutRequest)),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 560,
          child: ListView(
            children: [
              const Text(
                'المتاح للسحب',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: UberColors.bodyGray),
              ),
              const SizedBox(height: UberSpacing.xs),
              Text(
                '${vm.netPayable.toStringAsFixed(0)} ريال',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15, color: UberColors.black),
              ),
              const SizedBox(height: UberSpacing.md),
              Text(
                'اطلب مراجعة مبلغ أو سجّل نزاعاً مالياً على مستحقاتك، وسيراجعه فريق العمليات.',
                style: UberTypography.caption,
              ),
              const SizedBox(height: UberSpacing.xl),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المطلوب (ريال)',
                  hintText: 'أدخل المبلغ',
                ),
              ),
              const SizedBox(height: UberSpacing.xl),
              ElevatedButton(
                onPressed: _submitting ? null : _request,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: UberColors.white))
                    : const Text('إرسال الطلب'),
              ),
              const SizedBox(height: UberSpacing.md),
              TextButton(onPressed: () => context.go('/earnings'), child: const Text('العودة')),
            ],
          ),
        ),
      ),
    );
  }
}
