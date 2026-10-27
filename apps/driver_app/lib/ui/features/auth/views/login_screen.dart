
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_constants.dart';
import '../../../../core/demo_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../data/mock/demo_data.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../view_models/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    // Demo mode: prefill the demo phone so testers go straight to the OTP
    // step without typing.
    if (ref.read(demoModeProvider)) {
      _phoneController.text =
          DemoData.demoPhone.substring(AppConstants.yemenCountryCode.length);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('967')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '${AppConstants.yemenCountryCode}$digits';
  }

  Future<void> _requestOtp() async {
    if (_requesting) return;
    final l10n = AppLocalizations.of(context)!;
    final phone = _normalizePhone(_phoneController.text.trim());
    if (phone.length < AppConstants.yemenCountryCode.length + 7) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidYemeniPhone(l10n.phoneHint))),
        );
      }
      return;
    }
    setState(() => _requesting = true);
    final ok = await ref.read(authViewModelProvider.notifier).requestOtp(phone);
    if (!mounted) return;
    setState(() => _requesting = false);
    if (ok) {
      context.go('/otp?phone=$phone');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authViewModelProvider).error ?? l10n.requestOtpFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 480,
          child: ListView(
            children: [
              const SizedBox(height: UberSpacing.sm),
              Text(
                l10n.login,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.25, color: UberColors.black),
              ),
              const SizedBox(height: UberSpacing.sm),
              Text(
                l10n.loginSubtitle,
                style: UberTypography.caption,
              ),
              const SizedBox(height: UberSpacing.xl),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _requestOtp(),
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  prefixText: '${AppConstants.yemenCountryCode} ',
                  hintText: l10n.phoneHint,
                ),
              ),
              if (ref.watch(demoModeProvider)) ...[
                const SizedBox(height: UberSpacing.sm),
                Text(
                  l10n.demoModeFilled,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
              const SizedBox(height: UberSpacing.xl),
              ElevatedButton(
                onPressed: _requesting ? null : _requestOtp,
                child: _requesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: UberColors.white),
                      )
                    : Text(l10n.requestOtp),
              ),
              const SizedBox(height: UberSpacing.sm),
              TextButton(onPressed: () => context.go('/register'), child: Text(l10n.createDriverAccount)),
            ],
          ),
        ),
      ),
    );
  }
}
