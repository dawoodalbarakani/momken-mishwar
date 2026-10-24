library rider_app.app_router;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ui/features/auth/views/login_screen.dart';
import 'ui/features/auth/views/otp_screen.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/home/views/home_screen.dart';
import 'ui/features/quote/views/quote_screen.dart';
import 'ui/features/ride_request/views/ride_request_screen.dart';
import 'ui/features/ride_tracking/views/ride_tracking_screen.dart';
import 'ui/features/ride_completion/views/ride_completion_screen.dart';

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
    final auth = ref.watch(authViewModelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      final authenticated = await auth.initialize();
      if (!context.mounted) return;
      if (authenticated) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
