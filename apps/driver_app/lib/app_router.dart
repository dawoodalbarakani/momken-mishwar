library driver_app.app_router;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/documents_screen.dart';
import 'features/home/home_screen.dart';
import 'features/offers/offers_screen.dart';
import 'features/ride_tracking/ride_tracking_screen.dart';
import 'features/earnings/earnings_screen.dart';
import 'features/earnings/payout_request_screen.dart';
import 'core/constants.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (context, state) {
        final phone = state.queryParameters['phone'] ?? '';
        return OtpScreen(phone: phone);
      }),
      GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/offers', builder: (context, state) => const OffersScreen()),
      GoRoute(
        path: '/ride-track/:rideId',
        builder: (context, state) => RideTrackingScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(path: '/earnings', builder: (context, state) => const EarningsScreen()),
      GoRoute(
        path: '/earnings/payout-request',
        builder: (context, state) => const PayoutRequestScreen(),
      ),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    ],
  );
});

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (auth.token != null && auth.token!.isNotEmpty) {
        context.go('/home');
      } else if (auth.isLoading == false) {
        context.go('/login');
      }
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(auth.user?.name ?? 'السائق', style: const TextStyle(fontSize: 20)),
            Text(auth.user?.phone ?? ''),
            const SizedBox(height: 16),
            Text('حالة الاعتماد: ${_label(auth.verificationStatus)}'),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('تسجيل الخروج'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(VerificationStatus? s) {
    switch (s) {
      case VerificationStatus.approved:
        return 'معتمد';
      case VerificationStatus.pending:
        return 'قيد المراجعة';
      case VerificationStatus.rejected:
        return 'مرفوض';
      case VerificationStatus.suspended:
        return 'موقوف';
      default:
        return 'غير معروف';
    }
  }
}
