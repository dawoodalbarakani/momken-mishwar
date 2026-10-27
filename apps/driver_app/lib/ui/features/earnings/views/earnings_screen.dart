
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../domain/models/earnings.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../view_models/earnings_view_model.dart';
import '../../../../l10n/app_localizations.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(earningsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.earnings)),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PayoutHero(
                netPayable: vm.netPayable,
                onRequestPayout: () => context.go('/earnings/payout-request'),
              ),
              const SizedBox(height: UberSpacing.lg),
              UberCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UberMetricRow(label: 'إجمالي الأجرة', value: '${vm.totalFare.toStringAsFixed(0)} ريال'),
                    UberMetricRow(label: 'عمولة المنصة', value: '-${vm.platformCommission.toStringAsFixed(0)} ريال'),
                    UberMetricRow(label: 'النقد المحصل', value: '${vm.cashCollected.toStringAsFixed(0)} ريال'),
                    UberMetricRow(
                      label: 'مستحقات المنصة',
                      value: '-${vm.platformReceivables.toStringAsFixed(0)} ريال',
                      divided: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UberSpacing.xl),
              UberSectionHeader(
                title: 'سجل الرحلات المكتملة',
                action: vm.completedRides.isEmpty
                    ? null
                    : UberStatusPill(label: '${vm.completedRides.length} رحلة'),
              ),
              const SizedBox(height: UberSpacing.md),
              Expanded(
                child: vm.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : vm.completedRides.isEmpty
                    ? const UberEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'لا توجد رحلات مكتملة',
                        message: 'ستظهر هنا كل رحلة تُنهيها مع صافي أرباحها.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.read(earningsViewModelProvider.notifier).fetchEarnings(),
                        child: _CompletedRidesGrid(rides: vm.completedRides),
                      ),
              ),
              UberErrorText(vm.error),
            ],
          ),
        ),
      ),
    );
  }
}

/// The payout figure is the screen's headline, so it gets the inverted surface
/// and the largest type in the app's body content.
class _PayoutHero extends StatelessWidget {
  final double netPayable;
  final VoidCallback onRequestPayout;

  const _PayoutHero({required this.netPayable, required this.onRequestPayout});

  @override
  Widget build(BuildContext context) {
    return UberCard(
      inverted: true,
      padding: const EdgeInsets.all(UberSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'صافي مستحقاتك',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: UberColors.mutedGray),
          ),
          const SizedBox(height: UberSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  netPayable.toStringAsFixed(0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, height: 1.15, color: UberColors.white),
                ),
              ),
              const SizedBox(width: UberSpacing.sm),
              const Text(
                'ريال يمني',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: UberColors.mutedGray),
              ),
            ],
          ),
          const SizedBox(height: UberSpacing.lg),
          ElevatedButton(
            onPressed: onRequestPayout,
            style: ElevatedButton.styleFrom(
              backgroundColor: UberColors.white,
              foregroundColor: UberColors.black,
            ),
            child: const Text('طلب تسوية'),
          ),
        ],
      ),
    );
  }
}

/// One column on mobile, two once there's room for them side-by-side.
class _CompletedRidesGrid extends StatelessWidget {
  final List<CompletedRide> rides;

  const _CompletedRidesGrid({required this.rides});

  @override
  Widget build(BuildContext context) {
    final columns = responsiveColumnCount(context);
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: UberSpacing.sm,
        crossAxisSpacing: UberSpacing.sm,
        mainAxisExtent: 84,
      ),
      itemCount: rides.length,
      itemBuilder: (context, i) {
        final r = rides[i];
        return UberCard(
          padding: const EdgeInsets.symmetric(horizontal: UberSpacing.lg, vertical: UberSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرحلة ${r.rideId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: UberColors.black),
                    ),
                    const SizedBox(height: UberSpacing.xxs),
                    Text(
                      'اكتملت ${r.completedAt.toLocal().toString().substring(0, 16)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UberTypography.micro,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: UberSpacing.md),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${r.netToDriver.toStringAsFixed(0)} ريال',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2, color: UberColors.black),
                  ),
                  Text(
                    'عمولة ${r.platformCommission.toStringAsFixed(0)}',
                    style: UberTypography.micro,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
