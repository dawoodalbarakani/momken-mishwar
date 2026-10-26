
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_constants.dart';
import '../../../../core/demo_mode.dart';
import '../../../../data/mock/demo_data.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../view_models/auth_view_model.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({required this.phone, super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _verifying = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Demo mode: prefill the demo OTP so the verify step needs no typing.
    if (ref.read(demoModeProvider)) {
      final digits = DemoData.demoOtp.split('');
      for (var i = 0; i < _controllers.length && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _resendTimer?.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds > 0) _resendSeconds--;
      });
      if (_resendSeconds <= 0) _resendTimer?.cancel();
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length != AppConstants.otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل الرمز الكامل من 6 أرقام')));
      return;
    }
    setState(() => _verifying = true);
    final ok = await ref.read(authViewModelProvider.notifier).verifyOtp(widget.phone, _otp);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (ok) {
      if (ref.read(authViewModelProvider).isApproved) {
        context.go('/home');
      } else {
        context.go('/documents');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(authViewModelProvider).error ?? 'رمز التحقق غير صحيح')),
      );
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    final ok = await ref.read(authViewModelProvider.notifier).requestOtp(widget.phone);
    if (!mounted) return;
    if (ok) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أُعيد إرسال الرمز')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(authViewModelProvider).error ?? 'فشل إعادة الإرسال')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من الرمز')),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 480,
          child: ListView(
            children: [
              const SizedBox(height: UberSpacing.sm),
              const Text(
                'أدخل رمز التحقق',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.25, color: UberColors.black),
              ),
              const SizedBox(height: UberSpacing.sm),
              Text(
                'أرسلنا ${AppConstants.otpLength} أرقام إلى ${widget.phone}',
                style: UberTypography.caption,
              ),
              if (ref.watch(demoModeProvider)) ...[
                const SizedBox(height: UberSpacing.sm),
                Text(
                  'وضع العرض التجريبي: الرمز ${DemoData.demoOtp} معبأ مسبقاً',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
              const SizedBox(height: UberSpacing.xl),
              // Cell width is derived from the available width instead of a
              // fixed 48px, so the row never overflows a narrow viewport and
              // never looks sparse on a wide one.
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = UberSpacing.sm;
                  final cellWidth = clampValue(
                    (constraints.maxWidth - spacing * (AppConstants.otpLength - 1)) / AppConstants.otpLength,
                    min: 40,
                    max: 64,
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(AppConstants.otpLength, (i) {
                      return SizedBox(
                        width: cellWidth,
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: UberColors.black),
                          onChanged: (v) {
                            _focusNodes[i + 1 < AppConstants.otpLength ? i + 1 : i].requestFocus();
                          },
                          decoration: const InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                            constraints: BoxConstraints(minHeight: 56),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: UberSpacing.xl),
              ElevatedButton(
                onPressed: _verifying ? null : _verify,
                child: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: UberColors.white),
                      )
                    : const Text('تحقق'),
              ),
              const SizedBox(height: UberSpacing.sm),
              TextButton(
                onPressed: _resendSeconds > 0 ? null : _resend,
                child: Text(_resendSeconds > 0 ? 'إعادة الإرسال بعد $_resendSeconds ث' : 'إعادة الإرسال'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
