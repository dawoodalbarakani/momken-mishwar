
import 'package:driver_app/data/repositories/auth_repository.dart';
import 'package:driver_app/domain/models/auth_user.dart';
import 'package:driver_app/ui/features/auth/view_models/auth_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  test('initial state is unauthenticated and still initializing', () {
    final state = container.read(authViewModelProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.isApproved, isFalse);
    expect(state.isLoading, isFalse);
    // The router holds on the splash while this is true.
    expect(state.isInitializing, isTrue);
  });

  test('verifyOtp stores token and user on success', () async {
    const user = AuthUser(
      id: '1',
      phone: '967771234567',
      verificationStatus: VerificationStatus.approved,
    );
    when(repo.verifyOtp(any, any))
        .thenAnswer((_) async => const AuthResult(accessToken: 'tok', user: user));

    final ok = await container
        .read(authViewModelProvider.notifier)
        .verifyOtp('967771234567', '123456');

    expect(ok, isTrue);
    final state = container.read(authViewModelProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.isApproved, isTrue);
    expect(state.user?.phone, '967771234567');
  });

  test('requestOtp failure records error', () async {
    when(repo.requestOtp(any)).thenThrow(Exception('network'));

    final ok = await container
        .read(authViewModelProvider.notifier)
        .requestOtp('967771234567');

    expect(ok, isFalse);
    final state = container.read(authViewModelProvider);
    expect(state.error, 'فشل طلب رمز التحقق');
    expect(state.isLoading, isFalse);
  });

  test('initialize restores stored session', () async {
    const user = AuthUser(
      id: '1',
      phone: 'p',
      verificationStatus: VerificationStatus.approved,
    );
    when(repo.accessToken).thenAnswer((_) async => 'tok');
    when(repo.loadMe()).thenAnswer((_) async => user);

    final authenticated =
        await container.read(authViewModelProvider.notifier).initialize();

    expect(authenticated, isTrue);
    final state = container.read(authViewModelProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.isApproved, isTrue);
    // Guard can now route away from the splash.
    expect(state.isInitializing, isFalse);
  });

  test('initialize clears isInitializing even when restore throws', () async {
    when(repo.accessToken).thenAnswer((_) async => 'tok');
    when(repo.loadMe()).thenThrow(Exception('session expired'));

    final authenticated =
        await container.read(authViewModelProvider.notifier).initialize();

    expect(authenticated, isFalse);
    final state = container.read(authViewModelProvider);
    // Splash must still resolve, not hang forever.
    expect(state.isInitializing, isFalse);
    expect(state.error, 'تعذر استعادة الجلسة');
  });

  test('initialize without stored token stays unauthenticated', () async {
    when(repo.accessToken).thenAnswer((_) async => null);

    final authenticated =
        await container.read(authViewModelProvider.notifier).initialize();

    expect(authenticated, isFalse);
    final state = container.read(authViewModelProvider);
    expect(state.isLoading, isFalse);
    // No token: isInitializing cleared so the guard sends us to /login.
    expect(state.isInitializing, isFalse);
  });

  test('logout clears session', () async {
    when(repo.verifyOtp(any, any)).thenAnswer(
      (_) async => const AuthResult(accessToken: 'tok'),
    );
    await container
        .read(authViewModelProvider.notifier)
        .verifyOtp('p', '123456');

    await container.read(authViewModelProvider.notifier).logout();

    final state = container.read(authViewModelProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.user, isNull);
    // Logout must not re-show the splash; guard goes straight to /login.
    expect(state.isInitializing, isFalse);
  });
}
