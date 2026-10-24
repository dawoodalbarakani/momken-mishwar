library rider_app.app_router;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/home/home_screen.dart';
import 'features/quote/quote_screen.dart';
import 'features/ride_request/ride_request_screen.dart';
import 'features/ride_tracking/ride_tracking_screen.dart';
import 'features/ride_completion/ride_completion_screen.dart';
import 'core/constants.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (context, state) {
        final phone = state.queryParameters['phone'] ?? '';
        return OtpScreen(phone: phone);
      }),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/quote', builder: (context, state) => const QuoteScreen()),
      GoRoute(path: '/ride-request', builder: (context, state) => const RideRequestScreen()),
      GoRoute(
        path: '/ride-track/:rideId',
        builder: (context, state) => RideTrackingScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(
        path: '/ride-complete/:rideId',
        builder: (context, state) => RideCompletionScreen(rideId: state.pathParameters['rideId']!),
      ),
    ],
  );
});

/// Splash / auth gate. Redirects to /home when authenticated, /login otherwise.
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
