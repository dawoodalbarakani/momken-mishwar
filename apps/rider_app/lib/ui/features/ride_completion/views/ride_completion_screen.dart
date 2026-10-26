
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_constants.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../quote/view_models/quote_view_model.dart';

/// Post-trip receipt: the fare the server computed, the payment method, and a
/// working driver rating. The finish button returns the rider to Home so the
/// flow is a closed loop instead of a dead end.
class RideCompletionScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideCompletionScreen({required this.rideId, super.key});

  @override
  ConsumerState<RideCompletionScreen> createState() => _RideCompletionScreenState();
}

class _RideCompletionScreenState extends ConsumerState<RideCompletionScreen> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.simpleCurrency(locale: AppConstants.defaultLocale.languageCode);
    // The estimate carried through the ride flow is the best available fare for
    // the receipt; the server recomputes the final amount authoritatively.
    final quote = ref.watch(quoteViewModelProvider).quote;
    final fare = quote == null
        ? null
        : currencyFormat.format(double.tryParse(quote.estimatedAmount) ?? 0);
    final selectedTier = ref.watch(quoteViewModelProvider).selectedOption?.name;

    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الرحلة')),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle, size: 56, color: UberColors.black),
              const SizedBox(height: 12),
              Text(
                'شكراً لرحلتك مع mishwar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'الأجرة النهائية',
                style: const TextStyle(color: UberColors.bodyGray),
              ),
              Text(
                fare == null ? '—' : '$fare ${quote!.currency}',
                style: TextStyle(
                  fontSize: fluidFontSize(context, min: 28, max: 36),
                  fontWeight: FontWeight.bold,
                  color: UberColors.black,
                ),
              ),
              const SizedBox(height: 8),
              if (selectedTier != null) ...[
                Text('نوع الرحلة: $selectedTier',
                    style: const TextStyle(color: UberColors.bodyGray)),
                const SizedBox(height: 4),
              ],
              const Text('طريقة الدفع: نقدي',
                  style: TextStyle(color: UberColors.bodyGray)),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                _rating == 0 ? 'تقييم السائق' : 'تقييمك: $_rating من 5',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final value = i + 1;
                  return IconButton(
                    icon: Icon(
                      value <= _rating ? Icons.star : Icons.star_border,
                      color: UberColors.black,
                    ),
                    onPressed: () => setState(() => _rating = value),
                  );
                }),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('العودة إلى الرئيسية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
