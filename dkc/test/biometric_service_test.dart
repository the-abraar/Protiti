import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:protiti/data/services/auth_service.dart';
import 'package:protiti/data/services/biometric_service.dart';

import 'helpers/fakes.dart';

/// Records how authenticate() was called and answers [result].
class FakeLocalAuth implements LocalAuthentication {
  final List<Map<Symbol, dynamic>> calls = [];
  bool result = true;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #authenticate) {
      calls.add(invocation.namedArguments);
      return Future.value(result);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = FakeSecureStorage();
  late FakeLocalAuth localAuth;
  late AuthService auth;

  setUp(() {
    storage
      ..store.clear()
      ..install();
    localAuth = FakeLocalAuth();
    auth = AuthService(biometricService: BiometricService(auth: localAuth));
  });
  tearDown(storage.uninstall);

  test('biometrics are off by default and never prompt', () async {
    expect(await auth.isBiometricEnabled(), isFalse);
    expect(await auth.authenticateBiometric(), AuthStatus.failed);
    expect(localAuth.calls, isEmpty);
  });

  test('once opted in, only biometrics count, never the device PIN', () async {
    expect(await auth.setBiometricEnabled(true), isTrue);
    expect(await auth.authenticateBiometric(), AuthStatus.authenticatedReal);
    expect(localAuth.calls, isNotEmpty);
    for (final call in localAuth.calls) {
      expect(call[#biometricOnly], isTrue);
    }
  });

  test('opting in fails if the sensor check fails', () async {
    localAuth.result = false;
    expect(await auth.setBiometricEnabled(true), isFalse);
    expect(await auth.isBiometricEnabled(), isFalse);
  });
}
