import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    late AuthService authService;

    setUp(() => authService = AuthService());

    test('Old default PINs are rejected before setup', () async {
      expect(await authService.isSetupComplete(), isFalse);
      expect(await authService.verifyPin('1234'), AuthStatus.failed);
      expect(await authService.verifyPin('9999'), AuthStatus.failed);
    });

    test('setPins rejects equal, non-4-digit and wipe PINs', () async {
      for (final p in [('1111', '1111'), ('12', '5678'), ('0000', '5678'), ('1234', '0000')]) {
        expect(() => authService.setPins(realPin: p.$1, duressPin: p.$2), throwsArgumentError);
      }
      expect(await authService.isSetupComplete(), isFalse);
    });

    test('After setup, chosen PINs work and defaults do not', () async {
      await authService.setPins(realPin: '2468', duressPin: '1357');
      expect(await authService.isSetupComplete(), isTrue);
      expect(await authService.verifyPin('2468'), AuthStatus.authenticatedReal);
      expect(await authService.verifyPin('1357'), AuthStatus.authenticatedDuress);
      expect(await authService.verifyPin('1234'), AuthStatus.failed);
      expect(await authService.verifyPin('9999'), AuthStatus.failed);
    });
  });
}
