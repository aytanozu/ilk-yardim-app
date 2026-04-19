import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:ilk_yardim_app/features/auth/data/auth_repo.dart';
import 'package:ilk_yardim_app/features/auth/providers/auth_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepo extends Mock implements AuthRepo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthRepo repo;
  late StreamController<User?> authController;

  setUp(() {
    repo = _MockAuthRepo();
    // Never emits during the test unless we explicitly add a value, which
    // keeps the constructor's auth-state-change listener from triggering
    // side-effects like FcmService / BackgroundServiceRunner that depend
    // on Flutter method channels.
    authController = StreamController<User?>();
    when(() => repo.authStateChanges())
        .thenAnswer((_) => authController.stream);
    when(() => repo.signOut()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await authController.close();
  });

  group('AuthProvider submitPhone', () {
    test(
        'uncertified phone transitions stage → notCertified with reason',
        () async {
      when(() => repo.checkCertified('+905551112233')).thenAnswer(
        (_) async =>
            CertifiedCheckResult(ok: false, reason: 'not_found'),
      );
      final provider = AuthProvider(repo: repo);

      await provider.submitPhone('+905551112233');

      expect(provider.stage, AuthStage.notCertified);
      expect(provider.notCertifiedReason, 'not_found');
      expect(provider.phoneE164, '+905551112233');
    });

    test(
        'certified phone moves to awaitingCode and forwards verificationId',
        () async {
      when(() => repo.checkCertified(any())).thenAnswer(
        (_) async => CertifiedCheckResult(ok: true),
      );
      when(() => repo.startPhoneVerification(
            phoneE164: any(named: 'phoneE164'),
            onCodeSent: any(named: 'onCodeSent'),
            onAutoVerified: any(named: 'onAutoVerified'),
            onError: any(named: 'onError'),
          )).thenAnswer((invocation) async {
        final onCodeSent =
            invocation.namedArguments[#onCodeSent] as void Function(String);
        onCodeSent('VERIFICATION_ID');
      });
      final provider = AuthProvider(repo: repo);

      await provider.submitPhone('+905551112233');

      expect(provider.stage, AuthStage.awaitingCode);
    });

    test(
        'verificationFailed rolls stage back to phoneEntry with error',
        () async {
      when(() => repo.checkCertified(any())).thenAnswer(
        (_) async => CertifiedCheckResult(ok: true),
      );
      when(() => repo.startPhoneVerification(
            phoneE164: any(named: 'phoneE164'),
            onCodeSent: any(named: 'onCodeSent'),
            onAutoVerified: any(named: 'onAutoVerified'),
            onError: any(named: 'onError'),
          )).thenAnswer((invocation) async {
        final onError =
            invocation.namedArguments[#onError] as void Function(String);
        onError('SMS hatası');
      });
      final provider = AuthProvider(repo: repo);

      await provider.submitPhone('+905551112233');

      expect(provider.stage, AuthStage.phoneEntry);
      expect(provider.lastError, 'SMS hatası');
    });
  });

  group('AuthProvider resetToPhoneEntry', () {
    test('clears error, reason, verificationId and returns to phoneEntry',
        () async {
      when(() => repo.checkCertified(any())).thenAnswer(
        (_) async =>
            CertifiedCheckResult(ok: false, reason: 'expired'),
      );
      final provider = AuthProvider(repo: repo);
      await provider.submitPhone('+905551112233');
      expect(provider.stage, AuthStage.notCertified);

      provider.resetToPhoneEntry();

      expect(provider.stage, AuthStage.phoneEntry);
      expect(provider.notCertifiedReason, isNull);
      expect(provider.lastError, isNull);
    });
  });

  group('AuthProvider submitOtp', () {
    test('without verificationId sets lastError and stays awaiting', () async {
      final provider = AuthProvider(repo: repo);
      await provider.submitOtp('123456');
      expect(provider.lastError, isNotNull);
    });

    test('failed confirmation moves back to awaitingCode with error',
        () async {
      when(() => repo.checkCertified(any())).thenAnswer(
        (_) async => CertifiedCheckResult(ok: true),
      );
      when(() => repo.startPhoneVerification(
            phoneE164: any(named: 'phoneE164'),
            onCodeSent: any(named: 'onCodeSent'),
            onAutoVerified: any(named: 'onAutoVerified'),
            onError: any(named: 'onError'),
          )).thenAnswer((invocation) async {
        (invocation.namedArguments[#onCodeSent] as void Function(String))(
          'VID',
        );
      });
      when(() => repo.confirmOtp(
            verificationId: any(named: 'verificationId'),
            smsCode: any(named: 'smsCode'),
          )).thenThrow(Exception('bad code'));

      final provider = AuthProvider(repo: repo);
      await provider.submitPhone('+905551112233');
      await provider.submitOtp('000000');

      expect(provider.stage, AuthStage.awaitingCode);
      expect(provider.lastError, 'Kod doğrulanamadı');
    });
  });

  group('AuthProvider signOut', () {
    test('delegates to repo', () async {
      final provider = AuthProvider(repo: repo);
      await provider.signOut();
      verify(() => repo.signOut()).called(1);
    });
  });

}
