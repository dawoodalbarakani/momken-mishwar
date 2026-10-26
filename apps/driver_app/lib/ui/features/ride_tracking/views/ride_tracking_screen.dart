
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/ride.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../../offers/view_models/offers_view_model.dart';
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                      customerPhone: vm.customerPhone,
                      isConnected: vm.isConnected,
                    ),
                    if (vm.cancellation != null) ...[
                      const SizedBox(height: UberSpacing.md),
                      _CancellationBanner(cancellation: vm.cancellation!),
                    ],
                    if (vm.verifiedAssignment && !vm.started) ...[
                      const SizedBox(height: UberSpacing.lg),
                      _StartCodeCard(
                        controller: _startCodeController,
                        enabled: !vm.isLoading,
                        // Rebuild so the pinned action bar can enable the start
                        // button as soon as a full code is typed.
                        onChanged: () => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: UberSpacing.xl),
                    // Destructive and secondary: kept in the scroll body so it
                    // never sits next to the primary action in the thumb zone.
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
          ),
          UberActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _primaryAction(vm, terminal),
                const SizedBox(height: UberSpacing.xs),
                Text(
                  _hint(vm, terminal),
                  textAlign: TextAlign.center,
                  style: UberTypography.micro,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One action at a time, in the driver's thumb zone: verify, start, finish.
  Widget _primaryAction(RideTrackingState vm, bool terminal) {
    if (terminal) {
      return ElevatedButton(
        onPressed: null,
        child: Text(vm.status == RideStatus.completed ? 'اكتملت الرحلة' : 'الرحلة ملغاة'),
      );
    }
    if (!vm.verifiedAssignment) {
      return ElevatedButton(
        onPressed: vm.isLoading ? null : _verifyAssignment,
        child: const Text('تحقق من إسناد الرحلة'),
      );
    }
    if (!vm.started) {
      final codeLength = vm.startCode?.length ?? 4;
      final ready = _startCodeController.text.trim().length >= codeLength;
      return ElevatedButton(
        onPressed: (vm.isLoading || !ready) ? null : _startRide,
        child: const Text('بدء الرحلة'),
      );
    }
    return ElevatedButton(
      onPressed: vm.isLoading ? null : _completeRide,
      child: const Text('إنهاء الرحلة'),
    );
  }

  String _hint(RideTrackingState vm, bool terminal) {
    if (terminal) return 'شكراً — لا حاجة لأي إجراء آخر.';
    if (!vm.verifiedAssignment) return 'تأكد أن الرحلة مسندة إليك قبل التحرك.';
    if (!vm.started) return 'أدخل رمز الراكب أعلاه لبدء الرحلة.';
    return 'أنهِ الرحلة عند الوصول مع الراكب.';
  }

  Future<void> _verifyAssignment() async {
    final ok = await _notifier.verifyAssignment();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'تم التحقق من إسناد الرحلة' : 'فشل التحقق من الإسناد')),
    );
  }

  Future<void> _startRide() async {
    final ok = await _notifier.startRide(_startCodeController.text);
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('بدأت الرحلة')),
    );
  }

  Future<void> _completeRide() async {
    final ok = await _notifier.completeRide();
    if (!mounted) return;
    // The trip is over: release the driver to accept new requests, which also
    // clears the active-trip strip on the home screen.
    if (ok) ref.read(offersViewModelProvider.notifier).endActiveRide();
    final error = ref.read(rideTrackingViewModelProvider(widget.rideId)).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'تم إنهاء الرحلة' : error ?? 'فشل إنهاء الرحلة')),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الرحلة'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'سبب الإلغاء')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('تراجع')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await _notifier.cancelRide(reason: controller.text.trim(), actor: 'driver');
              if (ok) ref.read(offersViewModelProvider.notifier).endActiveRide();
            },
            style: ElevatedButton.styleFrom(backgroundColor: UberColors.danger, foregroundColor: UberColors.white),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }
}

class _CancellationBanner extends StatelessWidget {
  final RideCancellation cancellation;

  const _CancellationBanner({required this.cancellation});

  @override
  Widget build(BuildContext context) {
    return UberCard(
      background: UberColors.dangerSurface,
      elevated: false,
      padding: const EdgeInsets.all(UberSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.block, size: 20, color: UberColors.danger),
          const SizedBox(width: UberSpacing.md),
          Expanded(
            child: Text(
              'تم الإلغاء: ${cancellation.reason} (${cancellation.actor})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: UberColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rider's start code is the single hand-off moment of the trip, so it gets
/// its own card with an oversized field instead of a small form row.
class _StartCodeCard extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  const _StartCodeCard({required this.controller, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return UberCard(
      padding: const EdgeInsets.all(UberSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_outlined, size: 20, color: UberColors.black),
              const SizedBox(width: UberSpacing.sm),
              Expanded(
                child: Text(
                  'رمز بدء الرحلة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: UberSpacing.xs),
          Text(
            'اطلب الرمز من الراكب وأدخله لتأكيد انطلاق الرحلة.',
            style: UberTypography.caption,
          ),
          const SizedBox(height: UberSpacing.md),
          TextField(
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
            decoration: const InputDecoration(hintText: '••••'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onChanged(),
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
  final String? customerPhone;
  final bool isConnected;

  const _StatusCard({
    required this.status,
    required this.rideId,
    required this.isConnected,
    this.pickup,
    this.destination,
    this.customerName,
    this.customerPhone,
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
            if (customerPhone != null) ...[
              const SizedBox(height: UberSpacing.sm),
              _DetailRow(icon: Icons.call_outlined, label: 'الهاتف', value: customerPhone!),
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
