
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_constants.dart';
import '../../../../domain/models/product_option.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../home/view_models/home_view_model.dart';
import '../view_models/quote_view_model.dart';

/// Fare-review screen: the server estimate plus the ride-product (tier) picker
/// that mirrors Uber's "choose a ride" step. Fetches its own quote on entry so
/// it is a live funnel rather than a dead end.
class QuoteScreen extends ConsumerStatefulWidget {
  const QuoteScreen({super.key});

  @override
  ConsumerState<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends ConsumerState<QuoteScreen> {
  @override
  void initState() {
    super.initState();
    // The screen is reached from Home only once both endpoints are set, so the
    // coordinates are available here; pass them to the estimate request.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final home = ref.read(homeViewModelProvider);
      ref.read(quoteViewModelProvider.notifier).fetchQuote(
            pickup: _coord(home.pickup),
            destination: _coord(home.destination),
          );
    });
  }

  static String _coord(dynamic latLng) =>
      latLng == null ? '' : '${latLng.latitude},${latLng.longitude}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quoteViewModelProvider);
    final currencyFormat =
        NumberFormat.simpleCurrency(locale: AppConstants.defaultLocale.languageCode);

    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة السعر')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? _Message(text: state.error!)
              : state.quote == null
                  ? const _Message(text: 'جارٍ تحضير التقدير...')
                  : _buildReview(context, state, currencyFormat),
    );
  }

  Widget _buildReview(
      BuildContext context, QuoteState state, NumberFormat currencyFormat) {
    final quote = state.quote!;
    final selectedId = state.selectedTierId;
    return Padding(
      padding: context.responsivePadding,
      child: ContentMaxWidth(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(
                    'اختر نوع الرحلة',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final option in state.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TierTile(
                        option: option,
                        selected: option.id == selectedId,
                        price: currencyFormat
                            .format(option.pricedFrom(quote.estimatedAmount).toDouble()),
                        currency: quote.currency,
                        onTap: () =>
                            ref.read(quoteViewModelProvider.notifier).selectTier(option.id),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _row(context, 'المسافة', '${quote.distanceMeters.toStringAsFixed(1)} كم'),
                  _row(context, 'المدة المتوقعة', '${quote.durationSeconds ~/ 60} دقيقة'),
                  _row(context, 'إصدار تسعير', quote.ruleVersion),
                  const SizedBox(height: 8),
                  Text(
                    'السعر النهائي يتم حسابه من قبل الخادم عند إتمام الرحلة.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/ride-request'),
              child: const Text('تأكيد الطلب'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: UberColors.bodyGray)),
          Text(value, style: const TextStyle(color: UberColors.black)),
        ],
      ),
    );
  }
}

/// A single ride product row: name + description on the leading side, tier
/// price + ETA on the trailing side. The active row inverts to black-on-white
/// inside a full-pill border, per the Uber monochrome language.
class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.option,
    required this.selected,
    required this.price,
    required this.currency,
    required this.onTap,
  });

  final ProductOption option;
  final bool selected;
  final String price;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? UberColors.black : UberColors.chipGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? UberColors.black : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              option.seats >= 6 ? Icons.group : Icons.airline_seat_recline_normal,
              color: selected ? UberColors.white : UberColors.black,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: TextStyle(
                      color: selected ? UberColors.white : UberColors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${option.description} • ${option.seats} مقاعد • ${option.etaMinutes} د',
                    style: TextStyle(
                      color: selected ? UberColors.white : UberColors.bodyGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$price $currency',
              style: TextStyle(
                color: selected ? UberColors.white : UberColors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
