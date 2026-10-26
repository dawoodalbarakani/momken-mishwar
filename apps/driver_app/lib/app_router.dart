
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'domain/models/auth_user.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/auth/views/login_screen.dart';
import 'ui/features/auth/views/otp_screen.dart';
import 'ui/features/auth/views/register_screen.dart';
import 'ui/features/auth/views/documents_screen.dart';
import 'ui/features/home/views/home_screen.dart';
import 'ui/features/offers/views/offers_screen.dart';
import 'ui/features/ride_tracking/views/ride_tracking_screen.dart';
import 'ui/features/earnings/views/earnings_screen.dart';
import 'ui/features/earnings/views/payout_request_screen.dart';

/// Routes reachable before the session restore has completed.
const _publicRoutes = <String>{'/login', '/register', '/otp'};

final goRouterProvider = Provider<GoRouter>((ref) {
  // Bumping this notifier re-runs [redirect]; we fire it on every auth change
  // so login, logout, and approval transitions re-route automatically.
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
        if (!auth.isAuthenticated) return '/login';
        return auth.isApproved ? '/home' : '/documents';
      }

      // The auth funnel is always reachable.
      if (_publicRoutes.contains(loc)) return null;

      // Every other route requires a session; unverified drivers are pinned to
      // document upload until they are approved.
      if (!auth.isAuthenticated) return '/login';
      if (!auth.isApproved) return loc == '/documents' ? null : '/documents';
      if (loc == '/documents') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phone: phone);
        },
      ),
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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(auth.user?.name ?? 'السائق', style: const TextStyle(fontSize: 20)),
            Text(auth.user?.phone ?? ''),
            const SizedBox(height: 16),
            Text('حالة الاعتماد: ${_label(auth.user?.verificationStatus)}'),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                // No explicit navigation: logout clears the session, the auth
                // listener bumps refreshListenable, and the redirect routes to
                // /login.
                onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
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
