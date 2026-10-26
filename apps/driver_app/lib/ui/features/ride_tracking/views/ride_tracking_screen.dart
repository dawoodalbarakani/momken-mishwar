
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/ride.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../view_models/ride_tracking_view_model.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideTrackingScreen({required this.rideId, super.key});

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  final _startCodeController = TextEditingController();

  @override
  void dispose() {
    _startCodeController.dispose();
    super.dispose();
  }

  RideTrackingNotifier get _notifier =>
      ref.read(rideTrackingViewModelProvider(widget.rideId).notifier);

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(rideTrackingViewModelProvider(widget.rideId));
    final terminal = vm.status == RideStatus.completed || vm.status == RideStatus.cancelled;
    return Scaffold(
      appBar: AppBar(title: Text('الرحلة ${widget.rideId}')),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusCard(
                status: vm.status,
                rideId: widget.rideId,
                pickup: vm.pickup,
                destination: vm.destination,
                customerName: vm.customerName,
                isConnected: vm.isConnected,
              ),
              if (vm.cancellation != null) ...[
                const SizedBox(height: UberSpacing.md),
                UberCard(
                  background: UberColors.dangerSurface,
                  elevated: false,
                  padding: const EdgeInsets.all(UberSpacing.lg),
                  child: Row(
                    children: [
                      const Icon(Icons.block, size: 20, color: UberColors.danger),
                      const SizedBox(width: UberSpacing.md),
                      Expanded(
                        child: Text(
                          'تم الإلغاء: ${vm.cancellation!.reason} (${vm.cancellation!.actor})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: UberColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: UberSpacing.lg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!vm.verifiedAssignment)
                        ElevatedButton(
                          onPressed: vm.isLoading ? null : () async {
                            final ok = await _notifier.verifyAssignment();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'تم التحقق من إسناد الرحلة' : 'فشل التحقق من الإسناد')),
                            );
                          },
                          child: const Text('تحقق من إسناد الرحلة'),
                        ),
                      if (vm.verifiedAssignment && !vm.started) ...[
                        const SizedBox(height: UberSpacing.md),
                        TextField(
                          controller: _startCodeController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
                          decoration: const InputDecoration(
                            labelText: 'رمز بدء الرحلة',
                            hintText: 'أدخل الرمز من الراكب',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: UberSpacing.md),
                        ElevatedButton(
                          onPressed: vm.isLoading ? null : () => _notifier.startRide(_startCodeController.text),
                          child: const Text('بدء الرحلة'),
                        ),
                      ],
                      if (vm.started && !vm.completed) ...[
                        const SizedBox(height: UberSpacing.md),
                        ElevatedButton(
                          onPressed: vm.isLoading ? null : () => _notifier.completeRide(),
                          child: const Text('إنهاء الرحلة'),
                        ),
                      ],
                      const SizedBox(height: UberSpacing.lg),
                      OutlinedButton(
                        onPressed: (vm.isLoading || terminal) ? null : () => _showCancelDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UberColors.danger,
                          side: const BorderSide(color: UberColors.danger, width: 1),
                          disabledForegroundColor: UberColors.mutedGray,
                        ),
                        child: const Text('إلغاء الرحلة'),
                      ),
                      UberErrorText(vm.error),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الرحلة'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'سبب الإلغاء')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _notifier.cancelRide(reason: controller.text.trim(), actor: 'driver');
            },
            style: ElevatedButton.styleFrom(backgroundColor: UberColors.danger, foregroundColor: UberColors.white),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }
}

/// The one card the driver reads at a glance mid-trip: state, route, passenger,
/// and whether location telemetry is live.
class _StatusCard extends StatelessWidget {
  final RideStatus status;
  final String rideId;
  final String? pickup;
  final String? destination;
  final String? customerName;
  final bool isConnected;

  const _StatusCard({
    required this.status,
    required this.rideId,
    required this.isConnected,
    this.pickup,
    this.destination,
    this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    return UberCard(
      padding: const EdgeInsets.all(UberSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _label(status),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15, color: UberColors.black),
                ),
              ),
              const SizedBox(width: UberSpacing.sm),
              UberStatusPill(
                label: isConnected ? 'مباشر' : 'غير متصل',
                tone: isConnected ? UberStatusTone.active : UberStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: UberSpacing.sm),
          Text('رقم الرحلة $rideId', style: UberTypography.micro),
          if (pickup != null || destination != null || customerName != null) ...[
            const Divider(height: UberSpacing.xl + UberSpacing.md, thickness: 1, color: UberColors.hairline),
            if (pickup != null) _DetailRow(icon: Icons.trip_origin, label: 'الالتقاط', value: pickup!),
            if (destination != null) ...[
              const SizedBox(height: UberSpacing.sm),
              _DetailRow(icon: Icons.place_outlined, label: 'الوجهة', value: destination!),
            ],
            if (customerName != null) ...[
              const SizedBox(height: UberSpacing.sm),
              _DetailRow(icon: Icons.person_outline, label: 'الراكب', value: customerName!),
            ],
          ],
        ],
      ),
    );
  }

  String _label(RideStatus s) {
    switch (s) {
      case RideStatus.assigned:
        return 'مسندة إليك';
      case RideStatus.arriving:
        return 'في الطريق';
      case RideStatus.arrived:
        return 'وصلت';
      case RideStatus.inProgress:
        return 'الرحلة جارية';
      case RideStatus.completed:
        return 'مكتملة';
      case RideStatus.cancelled:
        return 'ملغاة';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: UberColors.mutedGray),
        const SizedBox(width: UberSpacing.sm),
        Text(label, style: UberTypography.caption),
        const SizedBox(width: UberSpacing.sm),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: UberColors.black),
          ),
        ),
      ],
    );
  }
}
