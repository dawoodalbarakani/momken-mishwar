
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'domain/models/auth_user.dart';
import 'ui/core/responsive.dart';
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
      // Home/offers/earnings/profile are the app's top-level sections, so they
      // share a navigation shell that swaps between a bottom bar (mobile) and a
      // side rail (tablet/desktop). Ride tracking and payout-request stay
      // outside the shell: they are focused, single-task screens reached from
      // within a section, not sections themselves.
      ShellRoute(
        builder: (context, state, child) => DriverNavShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/offers', builder: (context, state) => const OffersScreen()),
          GoRoute(path: '/earnings', builder: (context, state) => const EarningsScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/ride-track/:rideId',
        builder: (context, state) => RideTrackingScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(
        path: '/earnings/payout-request',
        builder: (context, state) => const PayoutRequestScreen(),
      ),
    ],
  );
});

/// One tappable entry in [DriverNavShell].
class _NavDestination {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination(this.path, this.icon, this.selectedIcon, this.label);
}

/// Adaptive navigation for the driver app's top-level sections: a Material 3
/// bottom [NavigationBar] on mobile, and a [NavigationRail] (labelled,
/// non-extended) on tablet, which additionally extends to show full labels on
/// desktop once there's room for them.
class DriverNavShell extends StatelessWidget {
  final String location;
  final Widget child;

  const DriverNavShell({required this.location, required this.child, super.key});

  static const _destinations = <_NavDestination>[
    _NavDestination('/home', Icons.home_outlined, Icons.home, 'الرئيسية'),
    _NavDestination('/offers', Icons.local_offer_outlined, Icons.local_offer, 'العروض'),
    _NavDestination('/earnings', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'الأرباح'),
    _NavDestination('/profile', Icons.person_outline, Icons.person, 'الملف الشخصي'),
  ];

  int get _currentIndex {
    final index = _destinations.indexWhere((d) => location.startsWith(d.path));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final size = context.deviceSize;
    final isMobile = size == DeviceSize.mobile;

    void onSelect(int index) => context.go(_destinations[index].path);

    if (isMobile) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: onSelect,
          destinations: _destinations
              .map((d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ))
              .toList(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: size == DeviceSize.desktop,
            labelType: size == DeviceSize.desktop ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
            selectedIndex: _currentIndex,
            onDestinationSelected: onSelect,
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

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
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 480,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(auth.user?.name ?? 'السائق', style: TextStyle(fontSize: fluidFontSize(context, min: 20, max: 24))),
              Text(auth.user?.phone ?? ''),
              const SizedBox(height: 16),
              Text('حالة الاعتماد: ${_label(auth.user?.verificationStatus)}'),
              const SizedBox(height: 16),
              OutlinedButton(
                // No explicit navigation: logout clears the session, the auth
                // listener bumps refreshListenable, and the redirect routes to
                // /login.
                onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
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
