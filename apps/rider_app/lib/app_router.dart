
import 'package:flutter/material.dart';
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

/// Routes reachable before the session restore has completed.
const _publicRoutes = <String>{'/login', '/otp'};

final goRouterProvider = Provider<GoRouter>((ref) {
  // Bumping this notifier re-runs [redirect]; we fire it on every auth change
  // so login, logout, and session-restore transitions re-route automatically.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authViewModelProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authViewModelProvider);
      final loc = state.matchedLocation;

      // Splash: hold until the session restore finishes, then hand off to the
      // same rules the guards below apply.
      if (loc == '/') {
        if (auth.isInitializing) return null;
        return auth.isAuthenticated ? '/home' : '/login';
      }

      // The auth funnel is always reachable.
      if (_publicRoutes.contains(loc)) return null;

      // Every other route requires a session. (Unlike the driver app, riders
      // have no approval gate.)
      if (!auth.isAuthenticated) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phone: phone);
        },
      ),
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

/// Splash: kicks off the one-time session restore. The GoRouter [redirect]
/// owns where the user actually goes; this widget only shows a spinner until
/// auth is resolved.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // initialize() never throws (it records errors in AuthState), so this is
      // a safe fire-and-forget; the redirect reacts to the resulting state.
      ref.read(authViewModelProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
