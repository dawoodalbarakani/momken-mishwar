
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../domain/models/available_ride.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeViewModelProvider.notifier).fetchAvailableRides();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(homeViewModelProvider);
    final online = vm.availability == AvailabilityStatus.online;
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية')),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AvailabilityCard(
                online: online,
                isLoading: vm.isLoading,
                lastLocationUpdate: vm.lastLocationUpdate,
                connectionStatus: vm.connectionStatus,
                error: vm.error,
                onToggle: () => ref.read(homeViewModelProvider.notifier).toggleAvailability(),
              ),
              const SizedBox(height: UberSpacing.xl),
              UberSectionHeader(
                title: 'الرحلات المتاحة',
                action: vm.availableRides.isEmpty
                    ? null
                    : UberStatusPill(label: '${vm.availableRides.length} رحلة'),
              ),
              const SizedBox(height: UberSpacing.md),
              Expanded(
                child: vm.availableRides.isEmpty
                    ? UberEmptyState(
                        icon: Icons.local_taxi_outlined,
                        title: 'لا توجد رحلات متاحة حالياً',
                        message: online
                            ? 'سنخبرك فور وصول رحلة قريبة منك.'
                            : 'أنت غير متصل — فعّل الاتصال لاستقبال الرحلات.',
                      )
                    : _RideList(
                        rides: vm.availableRides,
                        offline: vm.availability == AvailabilityStatus.offline,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inverted hero panel: the driver's current availability is the single most
/// important fact on this screen, so it gets the system's strongest surface
/// (Uber Black) and the largest type.
class _AvailabilityCard extends StatelessWidget {
  final bool online;
  final bool isLoading;
  final DateTime? lastLocationUpdate;
  final ConnectionStatus connectionStatus;
  final String? error;
  final VoidCallback onToggle;

  const _AvailabilityCard({
    required this.online,
    required this.isLoading,
    required this.connectionStatus,
    required this.onToggle,
    this.lastLocationUpdate,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final offlineConnection = connectionStatus == ConnectionStatus.offline;
    return UberCard(
      inverted: true,
      padding: const EdgeInsets.all(UberSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حالة التوفر',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: UberColors.mutedGray),
                    ),
                    const SizedBox(height: UberSpacing.xs),
                    Text(
                      online ? 'متصل' : 'غير متصل',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.1, color: UberColors.white),
                    ),
                  ],
                ),
              ),
              _StatusDot(online: online),
            ],
          ),
          const SizedBox(height: UberSpacing.sm),
          Text(
            online ? 'أنت تستقبل طلبات الرحلات الآن.' : 'لن تصلك طلبات جديدة حتى تتصل.',
            style: const TextStyle(fontSize: 14, height: 1.43, color: UberColors.mutedGray),
          ),
          if (lastLocationUpdate != null) ...[
            const SizedBox(height: UberSpacing.sm),
            Text(
              'آخر تحديث موقع: ${lastLocationUpdate!.toLocal().toString().substring(11, 19)}',
              style: const TextStyle(fontSize: 12, color: UberColors.mutedGray),
            ),
          ],
          if (offlineConnection) ...[
            const SizedBox(height: UberSpacing.sm),
            const Row(
              children: [
                Icon(Icons.wifi_off, size: 14, color: UberColors.white),
                SizedBox(width: UberSpacing.xs),
                Flexible(
                  child: Text(
                    'لا يوجد اتصال بالإنترنت',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: UberColors.white),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: UberSpacing.sm),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 14, color: UberColors.white),
                const SizedBox(width: UberSpacing.xs),
                Flexible(
                  child: Text(
                    error!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: UberColors.white),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: UberSpacing.lg),
          // White pill on black: the system's secondary button on a dark surface.
          ElevatedButton(
            onPressed: isLoading ? null : onToggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: UberColors.white,
              foregroundColor: UberColors.black,
              disabledBackgroundColor: UberColors.bodyGray,
              disabledForegroundColor: UberColors.mutedGray,
            ),
            child: Text(online ? 'الانقطاع عن العمل' : 'الاتصال بالعمل'),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool online;

  const _StatusDot({required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? UberColors.white : UberColors.bodyGray,
        border: Border.all(color: UberColors.white, width: 1.5),
      ),
    );
  }
}

/// One column on mobile, two once there's room for them side-by-side.
///
/// Rows use a fixed pixel height rather than an aspect ratio so the card
/// content can never overflow as type scales up with the viewport.
class _RideList extends StatelessWidget {
  final List<AvailableRide> rides;
  final bool offline;

  const _RideList({required this.rides, required this.offline});

  @override
  Widget build(BuildContext context) {
    final columns = responsiveColumnCount(context);
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: UberSpacing.sm,
        crossAxisSpacing: UberSpacing.sm,
        mainAxisExtent: 88,
      ),
      itemCount: rides.length,
      itemBuilder: (context, i) {
        final r = rides[i];
        final minutes = r.expiresAt.difference(DateTime.now()).inMinutes;
        return UberCard(
          padding: const EdgeInsets.symmetric(horizontal: UberSpacing.lg, vertical: UberSpacing.md),
          onTap: offline ? null : () => context.go('/offers'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UberRouteLine(pickup: r.pickup, destination: r.destination),
                    const SizedBox(height: 6),
                    Text(
                      '${(r.distanceMeters / 1000).toStringAsFixed(1)} كم · تنتهي بعد $minutes دقيقة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: UberTypography.caption,
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
                    r.fare.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2, color: UberColors.black),
                  ),
                  const Text('ريال', style: TextStyle(fontSize: 12, color: UberColors.mutedGray)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
