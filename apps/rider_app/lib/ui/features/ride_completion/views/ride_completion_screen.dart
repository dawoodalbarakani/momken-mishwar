
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_constants.dart';
import '../../../core/responsive.dart';

class RideCompletionScreen extends StatelessWidget {
  final String rideId;
  const RideCompletionScreen({required this.rideId, super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: AppConstants.defaultLocale.languageCode);
    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الرحلة')),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('الرحلة مكتملة'),
              const SizedBox(height: 24),
              Text('الأجرة النهائية: ${currencyFormat.format(0)} ${'YER'}', style: TextStyle(fontSize: fluidFontSize(context, min: 28, max: 36), fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('طريقة الدفع: نقدي'),
              const SizedBox(height: 24),
              const Text('تقييم السائق'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(icon: const Icon(Icons.star), onPressed: () {})),
              ),
              const Spacer(),
              ElevatedButton(onPressed: () {}, child: const Text('إنهاء وتسجيل الرحلة')),
            ],
          ),
        ),
      ),
    );
  }
}
