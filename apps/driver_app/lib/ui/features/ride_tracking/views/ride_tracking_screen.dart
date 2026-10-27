import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/ride.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../../offers/view_models/offers_view_model.dart';
import '../view_models/ride_tracking_view_model.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  const RideTrackingScreen({required this.rideId, super.key});
  final String rideId;

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  final _code = TextEditingController();
  RideTrackingNotifier get _notifier => ref.read(rideTrackingViewModelProvider(widget.rideId).notifier);

  @override
  void dispose() { _code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(rideTrackingViewModelProvider(widget.rideId));
    final terminal = vm.status == RideStatus.completed || vm.status == RideStatus.cancelled;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.rideNumber(widget.rideId))),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: context.responsivePadding,
          child: ContentMaxWidth(maxWidth: 720, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TripMap(state: vm),
              const SizedBox(height: UberSpacing.lg),
              _TripCard(rideId: widget.rideId, state: vm),
              if (vm.verifiedAssignment && !vm.started) ...[
                const SizedBox(height: UberSpacing.md),
                UberCard(child: TextField(
                  controller: _code,
                  enabled: !vm.isLoading,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
                  decoration: const InputDecoration(labelText: 'رمز بدء الرحلة', hintText: '••••'),
                )),
              ],
              if (vm.started || vm.status == RideStatus.completed) ...[
                const SizedBox(height: UberSpacing.md),
                const UberCard(
                  background: UberColors.chipGray,
                  elevated: false,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.payments_outlined),
                    title: Text('الدفع نقداً'),
                    subtitle: Text('حصّل المبلغ النهائي من الراكب بعد الوصول.'),
                  ),
                ),
              ],
              const SizedBox(height: UberSpacing.lg),
              OutlinedButton(
                onPressed: vm.isLoading || terminal ? null : _cancel,
                style: OutlinedButton.styleFrom(foregroundColor: UberColors.danger),
                child: const Text('إلغاء الرحلة'),
              ),
              UberErrorText(vm.error),
            ],
          )),
        )),
        UberActionBar(child: _action(vm, terminal)),
      ]),
    );
  }

  Widget _action(RideTrackingState vm, bool terminal) {
    if (terminal) return ElevatedButton(onPressed: null, child: Text(vm.status == RideStatus.completed ? 'اكتملت الرحلة' : 'الرحلة ملغاة'));
    if (!vm.verifiedAssignment) return ElevatedButton(onPressed: vm.isLoading ? null : _notifier.verifyAssignment, child: const Text('تحقق من إسناد الرحلة'));
    if (!vm.started) {
      final ready = _code.text.trim().length >= (vm.startCode?.length ?? 4);
      return ElevatedButton(onPressed: vm.isLoading || !ready ? null : () => _notifier.startRide(_code.text), child: const Text('تحقق وابدأ الرحلة'));
    }
    return ElevatedButton(onPressed: vm.isLoading ? null : () async {
      if (await _notifier.completeRide()) ref.read(offersViewModelProvider.notifier).endActiveRide();
    }, child: const Text('إنهاء الرحلة'));
  }

  void _cancel() {
    final reason = TextEditingController();
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('إلغاء الرحلة'),
      content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'سبب الإلغاء')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('تراجع')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(dialogContext);
          if (await _notifier.cancelRide(reason: reason.text.trim(), actor: 'driver')) ref.read(offersViewModelProvider.notifier).endActiveRide();
        }, child: const Text('تأكيد الإلغاء')),
      ],
    ));
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.rideId, required this.state});
  final String rideId;
  final RideTrackingState state;

  @override
  Widget build(BuildContext context) => UberCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(children: [
        Expanded(child: Text(_label(state.status), style: UberTypography.subHeading)),
        UberStatusPill(label: state.isConnected ? 'مباشر' : 'غير متصل', tone: state.isConnected ? UberStatusTone.active : UberStatusTone.neutral),
      ]),
      const SizedBox(height: UberSpacing.sm),
      Text('رقم الرحلة $rideId', style: UberTypography.micro),
      const Divider(color: UberColors.hairline),
      UberRouteLine(pickup: state.pickup ?? 'نقطة الالتقاط', destination: state.destination ?? 'الوجهة'),
      if (state.customerName != null) ...[
        const Divider(color: UberColors.hairline),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_outline), title: Text(state.customerName!), subtitle: const Text('الراكب'), trailing: const Icon(Icons.call_outlined)),
      ],
    ],
  ));

  String _label(RideStatus status) => switch (status) {
    RideStatus.assigned => 'اتجه إلى الراكب',
    RideStatus.arriving => 'في الطريق',
    RideStatus.arrived => 'وصلت إلى الراكب',
    RideStatus.inProgress => 'الرحلة جارية',
    RideStatus.completed => 'اكتملت الرحلة',
    RideStatus.cancelled => 'الرحلة ملغاة',
  };
}

class _TripMap extends StatelessWidget {
  const _TripMap({required this.state});
  final RideTrackingState state;

  @override
  Widget build(BuildContext context) {
    final active = state.status == RideStatus.inProgress;
    return ClipRRect(
      borderRadius: BorderRadius.circular(UberRadii.featured),
      child: SizedBox(height: 260, child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: UberColors.chipGray),
        const CustomPaint(painter: _RoutePainter()),
        PositionedDirectional(top: UberSpacing.md, start: UberSpacing.md, end: UberSpacing.md, child: Container(
          padding: const EdgeInsets.all(UberSpacing.md),
          decoration: BoxDecoration(color: UberColors.black, borderRadius: BorderRadius.circular(UberRadii.card), boxShadow: UberShadows.medium),
          child: Row(children: [
            const Icon(Icons.turn_right, color: UberColors.white, size: 28),
            const SizedBox(width: UberSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(active ? 'تابع مباشرة نحو الوجهة' : 'اتجه إلى نقطة الالتقاط', style: const TextStyle(color: UberColors.white, fontWeight: FontWeight.w700)),
              Text(active ? state.destination ?? 'الوجهة' : state.pickup ?? 'موقع الالتقاط', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: UberColors.mutedGray, fontSize: 12)),
            ])),
            const Text('١٫٢ كم', style: TextStyle(color: UberColors.white, fontWeight: FontWeight.w700)),
          ]),
        )),
        const PositionedDirectional(top: 135, end: 62, child: CircleAvatar(backgroundColor: UberColors.black, child: Icon(Icons.place, color: UberColors.white))),
        const PositionedDirectional(bottom: 30, start: 70, child: CircleAvatar(backgroundColor: UberColors.black, child: Icon(Icons.navigation, color: UberColors.white))),
        PositionedDirectional(bottom: UberSpacing.md, end: UberSpacing.md, child: UberStatusPill(label: state.isConnected ? 'الموقع مباشر' : 'GPS غير متاح', tone: state.isConnected ? UberStatusTone.active : UberStatusTone.neutral)),
      ])),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final street = Paint()..color = UberColors.white..strokeWidth = 12;
    for (var i = 0; i < 5; i++) { final y = 90.0 + i * 45; canvas.drawLine(Offset(-20, y), Offset(size.width + 20, y - 70), street); }
    final path = Path()..moveTo(size.width * .22, size.height * .82)..cubicTo(size.width * .45, size.height * .62, size.width * .6, size.height * .7, size.width * .82, size.height * .48);
    canvas.drawPath(path, Paint()..color = UberColors.white..style = PaintingStyle.stroke..strokeWidth = 11);
    canvas.drawPath(path, Paint()..color = UberColors.black..style = PaintingStyle.stroke..strokeWidth = 5);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
