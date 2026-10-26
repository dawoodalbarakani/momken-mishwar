
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rider_app/data/repositories/auth_repository.dart';
import 'package:rider_app/data/services/dio_client.dart';
import 'package:rider_app/domain/models/auth_user.dart';
import 'package:rider_app/ui/features/auth/view_models/auth_view_model.dart';

/// Hand-written, generated-style mock: every member that tests stub via
/// `when(...)` gets a nullable-widened override delegating to noSuchMethod with
/// a typed `returnValue`, so the when-phase never returns bare null (which
/// leaks mockito global state and poisons every later `when()` in the suite).
class MockAuthRepository extends Mock implements AuthRepository {
  @override
  Future<String?> get accessToken => (super.noSuchMethod(
        Invocation.getter(#accessToken),
        returnValue: Future<String?>.value(),
      ) as Future<String?>);

  @override
  Future<bool> requestOtp(String? phone) => (super.noSuchMethod(
        Invocation.method(#requestOtp, [phone]),
        returnValue: Future<bool>.value(true),
      ) as Future<bool>);

  @override
  Future<AuthResult> verifyOtp(String? phone, String? otp) => (super.noSuchMethod(
        Invocation.method(#verifyOtp, [phone, otp]),
        returnValue: Future<AuthResult>.value(const AuthResult(accessToken: '')),
      ) as Future<AuthResult>);

  @override
  Future<void> logout() => (super.noSuchMethod(
        Invocation.method(#logout, []),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      ) as Future<void>);
}

void main() {
  late MockAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = MockAuthRepository();
    container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() => container.dispose());

  AuthState state() => container.read(authViewModelProvider);
  AuthNotifier notifier() => container.read(authViewModelProvider.notifier);

  group('AuthState initial', () {
    test('starts initializing so the router holds on splash', () {
      expect(state().isInitializing, isTrue);
      expect(state().isAuthenticated, isFalse);
    });
  });

  group('initialize', () {
    test('restores a persisted token and clears isInitializing', () async {
      when(repo.accessToken).thenAnswer((_) async => 'token-123');
      final ok = await notifier().initialize();
      expect(ok, isTrue);
      expect(state().token, 'token-123');
      expect(state().isAuthenticated, isTrue);
      expect(state().isInitializing, isFalse);
      expect(state().isLoading, isFalse);
    });

    test('no stored token leaves the session unauthenticated', () async {
      when(repo.accessToken).thenAnswer((_) async => null);
      final ok = await notifier().initialize();
      expect(ok, isFalse);
      expect(state().isAuthenticated, isFalse);
      expect(state().isInitializing, isFalse);
    });

    test('restore failure records an error and resolves the splash', () async {
      when(repo.accessToken).thenAnswer((_) async => throw Exception('storage'));
      final ok = await notifier().initialize();
      expect(ok, isFalse);
      expect(state().error, 'تعذر استعادة الجلسة');
      expect(state().isInitializing, isFalse);
      expect(state().isLoading, isFalse);
    });
  });

  group('requestOtp', () {
    test('success clears loading', () async {
      when(repo.requestOtp('+967771234567')).thenAnswer((_) async => true);
      expect(await notifier().requestOtp('+967771234567'), isTrue);
      expect(state().isLoading, isFalse);
      expect(state().error, isNull);
    });

    test('failure records an error', () async {
      when(repo.requestOtp(any)).thenAnswer((_) async => throw Exception('network'));
      expect(await notifier().requestOtp('+967771234567'), isFalse);
      expect(state().error, 'فشل طلب رمز التحقق');
      expect(state().isLoading, isFalse);
    });
  });

  group('verifyOtp', () {
    test('success stores token and user and ends initialization', () async {
      when(repo.verifyOtp(any, any)).thenAnswer((_) async => const AuthResult(
            accessToken: 'tok',
            user: AuthUser(id: 'u1', phone: '+967771234567', name: 'أحمد'),
          ));
      expect(await notifier().verifyOtp('+967771234567', '123456'), isTrue);
      expect(state().token, 'tok');
      expect(state().user?.name, 'أحمد');
      expect(state().isInitializing, isFalse);
      verify(repo.verifyOtp('+967771234567', '123456')).called(1);
    });

    test('ApiException surfaces the server Arabic message', () async {
      when(repo.verifyOtp(any, any)).thenAnswer((_) async => throw ApiException(
            code: 'invalid_otp',
            messageAr: 'رمز التحقق غير صحيح',
            messageEn: 'Invalid OTP',
          ));
      expect(await notifier().verifyOtp('+967771234567', '000000'), isFalse);
      expect(state().error, 'رمز التحقق غير صحيح');
    });

    test('unexpected failure uses the generic message', () async {
      when(repo.verifyOtp(any, any)).thenAnswer((_) async => throw Exception('boom'));
      expect(await notifier().verifyOtp('+967771234567', '000000'), isFalse);
      expect(state().error, 'فشل التحقق من الرمز');
    });
  });

  group('logout', () {
    test('clears the session without re-entering initialization', () async {
      when(repo.accessToken).thenAnswer((_) async => 'tok');
      await notifier().initialize();
      expect(state().isAuthenticated, isTrue);

      await notifier().logout();
      expect(state().isAuthenticated, isFalse);
      expect(state().user, isNull);
      expect(state().error, isNull);
      // Guard contract: the router must go straight to /login, not splash.
      expect(state().isInitializing, isFalse);
      verify(repo.logout()).called(1);
    });
  });

  group('AuthState value semantics', () {
    test('equal states compare equal for the router refresh listener', () {
      const a = AuthState(token: 't', isInitializing: false);
      const b = AuthState(token: 't', isInitializing: false);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(clearSession: true), isNot(equals(a)));
    });
  });
}
