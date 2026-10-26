
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/app_constants.dart';
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
    final phone = _normalizePhone(_phoneController.text.trim());
    if (phone.length < AppConstants.yemenCountryCode.length + 7) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل رقم هاتف يمني صحيح (مثال: 771234567)')),
        );
      }
      return;
    }
    setState(() => _requesting = true);
    final ok = await ref.read(authViewModelProvider.notifier).requestOtp(phone);
    setState(() => _requesting = false);
    if (ok && mounted) {
      context.go('/otp?phone=$phone');
    } else if (mounted) {
      final error = ref.read(authViewModelProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'فشل طلب الرمز')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('أدخل رقم هاتفك اليمني لطلب رمز التحقق'),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixText: '+967 ',
                hintText: '771234567',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _requesting ? null : _requestOtp,
                child: _requesting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('طلب رمز التحقق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
