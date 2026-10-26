
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../domain/models/available_ride.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../../offers/view_models/offers_view_model.dart';
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
    // A trip in progress outranks availability: Uber keeps the driver on that
    // trip and refuses to let them drift offline mid-ride.
    final activeRideId = ref.watch(offersViewModelProvider.select((s) => s.activeRideId));
    final hasActiveRide = activeRideId != null && activeRideId.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('الرئيسية')),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasActiveRide) ...[
                _ActiveRideStrip(onResume: () => context.go('/ride-track/$activeRideId')),
                const SizedBox(height: UberSpacing.md),
              ],
              _AvailabilityCard(
                online: online,
                isLoading: vm.isLoading,
                blocked: hasActiveRide,
                lastLocationUpdate: vm.lastLocationUpdate,
                connectionStatus: vm.connectionStatus,
                error: vm.error,
                onToggle: () => ref.read(homeViewModelProvider.notifier).toggleAvailability(),
              ),
              const SizedBox(height: UberSpacing.xl),
              UberSectionHeader(
                title: 'الرحلات المتاحة',
                action: UberPill(
                  label: 'تحديث',
                  icon: Icons.refresh,
                  onPressed: vm.isLoading
                      ? null
                      : () => ref.read(homeViewModelProvider.notifier).fetchAvailableRides(),
                ),
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

/// Continuity strip for the trip already in progress. It sits above the
/// availability panel because, in the real app, the trip the driver is on is
/// always the first thing on screen.
class _ActiveRideStrip extends StatelessWidget {
  final VoidCallback onResume;

  const _ActiveRideStrip({required this.onResume});

  @override
  Widget build(BuildContext context) {
    return UberCard(
      inverted: true,
      elevated: false,
      padding: const EdgeInsets.all(UberSpacing.lg),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رحلة نشطة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: UberColors.white),
                ),
                SizedBox(height: UberSpacing.xxs),
                Text(
                  'أكمل الرحلة الحالية قبل استقبال طلبات جديدة.',
                  style: TextStyle(fontSize: 12, height: 1.43, color: UberColors.mutedGray),
                ),
              ],
            ),
          ),
          const SizedBox(width: UberSpacing.md),
          ElevatedButton(
            onPressed: onResume,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: UberColors.white,
              foregroundColor: UberColors.black,
            ),
            child: const Text('متابعة'),
          ),
        ],
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

  /// True while a trip is running: the driver can't go offline mid-ride.
  final bool blocked;
  final DateTime? lastLocationUpdate;
  final ConnectionStatus connectionStatus;
  final String? error;
  final VoidCallback onToggle;

  const _AvailabilityCard({
    required this.online,
    required this.isLoading,
    required this.connectionStatus,
    required this.onToggle,
    this.blocked = false,
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
            blocked
                ? 'لا يمكن تغيير حالة العمل أثناء رحلة نشطة.'
                : online
                ? 'أنت تستقبل طلبات الرحلات الآن.'
                : 'لن تصلك طلبات جديدة حتى تتصل.',
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
            onPressed: (isLoading || blocked) ? null : onToggle,
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
