
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_constants.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../view_models/auth_view_model.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _plateController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _licenseController = TextEditingController();
  bool _registering = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleTypeController.dispose();
    _plateController.dispose();
    _nationalIdController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('967')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '${AppConstants.yemenCountryCode}$digits';
  }

  Future<void> _register() async {
    final phone = _normalizePhone(_phoneController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        phone.length < AppConstants.yemenCountryCode.length + 7 ||
        _vehicleTypeController.text.trim().isEmpty ||
        _plateController.text.trim().isEmpty ||
        _nationalIdController.text.trim().isEmpty ||
        _licenseController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل جميع الحقول المطلوبة')));
      }
      return;
    }
    setState(() => _registering = true);
    final ok = await ref.read(authViewModelProvider.notifier).registerDriver(
      name: _nameController.text.trim(),
      phone: phone,
      vehicleType: _vehicleTypeController.text.trim(),
      plateNumber: _plateController.text.trim(),
      nationalId: _nationalIdController.text.trim(),
      licenseNumber: _licenseController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _registering = false);
    if (ok) {
      context.go('/login?phone=$phone');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(authViewModelProvider).error ?? 'فشل التسجيل')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل سائق')),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 560,
          child: ListView(
            children: [
              const SizedBox(height: UberSpacing.sm),
              const Text(
                'تسجيل سائق جديد',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.25, color: UberColors.black),
              ),
              const SizedBox(height: UberSpacing.sm),
              Text(
                'أدخل بياناتك كما تظهر في مستنداتك الرسمية؛ ستُراجع قبل تفعيل حسابك.',
                style: UberTypography.caption,
              ),
              const SizedBox(height: UberSpacing.xl),
              const Text(
                'بيانات السائق',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: UberColors.black),
              ),
              const SizedBox(height: UberSpacing.md),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              const SizedBox(height: UberSpacing.md),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixText: '+967 ', hintText: '771234567'),
              ),
              const SizedBox(height: UberSpacing.xl),
              const Text(
                'المركبة والمستندات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: UberColors.black),
              ),
              const SizedBox(height: UberSpacing.md),
              TextField(controller: _vehicleTypeController, decoration: const InputDecoration(labelText: 'نوع المركبة')),
              const SizedBox(height: UberSpacing.md),
              TextField(controller: _plateController, decoration: const InputDecoration(labelText: 'لوحة المركبة')),
              const SizedBox(height: UberSpacing.md),
              TextField(
                controller: _nationalIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الرقم الوطني'),
              ),
              const SizedBox(height: UberSpacing.md),
              TextField(controller: _licenseController, decoration: const InputDecoration(labelText: 'رقم رخصة القيادة')),
              const SizedBox(height: UberSpacing.xl),
              ElevatedButton(
                onPressed: _registering ? null : _register,
                child: _registering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: UberColors.white),
                      )
                    : const Text('تسجيل'),
              ),
              const SizedBox(height: UberSpacing.sm),
              TextButton(onPressed: () => context.go('/login'), child: const Text('لديك حساب؟ تسجيل الدخول')),
            ],
          ),
        ),
      ),
    );
  }
}
