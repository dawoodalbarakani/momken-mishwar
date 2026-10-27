
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'domain/models/auth_user.dart';
import 'ui/core/app_theme.dart';
import 'ui/core/responsive.dart';
import 'ui/core/uber_components.dart';
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
import 'l10n/app_localizations.dart';

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
      // Approved drivers can revisit documents from the main navigation.
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
      // The main sections share adaptive navigation. Documents is available
      // to approved drivers too, while the redirect above still pins drivers
      // who are awaiting approval to this screen.
      ShellRoute(
        builder: (context, state, child) => DriverNavShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/earnings', builder: (context, state) => const EarningsScreen()),
          GoRoute(path: '/offers', builder: (context, state) => const OffersScreen()),
          GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
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
    _NavDestination('/earnings', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'الأرباح'),
    _NavDestination('/offers', Icons.local_offer_outlined, Icons.local_offer, 'العروض'),
    _NavDestination('/documents', Icons.description_outlined, Icons.description, 'المستندات'),
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
        // A 1px hairline is the only thing separating the bar from the page —
        // Uber never uses a raised or tinted navigation surface.
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: UberColors.hairline, width: 1)),
          ),
          child: NavigationBar(
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
            leading: Padding(
              padding: const EdgeInsets.only(top: UberSpacing.sm, bottom: UberSpacing.lg),
              child: size == DeviceSize.desktop
                  ? const Text(
                      'مشوار',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: UberColors.black),
                    )
                  : const Icon(Icons.local_taxi, color: UberColors.black),
            ),
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
    // Black splash: the first frame is the brand, not a white void.
    return const Scaffold(
      backgroundColor: UberColors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'مشوار',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: UberColors.white),
            ),
            SizedBox(height: UberSpacing.xl),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: UberColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authViewModelProvider);
    final name = auth.user?.name ?? 'السائق';
    final phone = auth.user?.phone ?? '';
    final status = auth.user?.verificationStatus;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.profile)),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 480,
          child: ListView(
            children: [
              UberCard(
                padding: const EdgeInsets.all(UberSpacing.xl),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: UberColors.black, shape: BoxShape.circle),
                      child: Text(
                        _initial(name),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: UberColors.white),
                      ),
                    ),
                    const SizedBox(width: UberSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: UberColors.black),
                          ),
                          const SizedBox(height: UberSpacing.xxs),
                          Text(phone, style: UberTypography.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UberSpacing.lg),
              UberCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('حالة الاعتماد', style: UberTypography.caption)),
                        const SizedBox(width: UberSpacing.sm),
                        UberStatusPill(label: _label(status), tone: _tone(status)),
                      ],
                    ),
                    const Divider(height: UberSpacing.xl, thickness: 1, color: UberColors.hairline),
                    Row(
                      children: [
                        Expanded(child: Text('رقم الهاتف', style: UberTypography.caption)),
                        const SizedBox(width: UberSpacing.sm),
                        Text(
                          phone,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: UberColors.black),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UberSpacing.xl),
              OutlinedButton(
                // No explicit navigation: logout clears the session, the auth
                // listener bumps refreshListenable, and the redirect routes to
                // /login.
                onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: UberColors.danger,
                  side: const BorderSide(color: UberColors.danger, width: 1),
                ),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'م' : trimmed.substring(0, 1);
  }

  UberStatusTone _tone(VerificationStatus? s) {
    switch (s) {
      case VerificationStatus.approved:
        return UberStatusTone.active;
      case VerificationStatus.rejected:
      case VerificationStatus.suspended:
        return UberStatusTone.danger;
      case VerificationStatus.pending:
        return UberStatusTone.neutral;
      default:
        return UberStatusTone.neutral;
    }
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
