library rider_app.features.ride_completion.ride_completion_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class RideCompletionScreen extends ConsumerWidget {
  final String rideId;
  const RideCompletionScreen({required this.rideId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: AppConstants.defaultLocale.languageCode);
    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الرحلة')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('الرحلة مكتملة'),
            const SizedBox(height: 24),
            Text('الأجرة النهائية: ${currencyFormat.format(0)} ${'YER'}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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
            SizedBox(height: 50, child: ElevatedButton(onPressed: () {}, child: const Text('إنهاء وتسجيل الرحلة'))),
          ],
        ),
      ),
    );
  }
}
