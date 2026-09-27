import 'package:flutter_test/flutter_test.dart';
import 'package:protiti/data/services/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    late AuthService authService;

    setUp(() {
      // Using the default static PINs for test purposes
      authService = AuthService();
    });

    test('Entering Real PIN returns authenticatedReal', () async {
      final status = await authService.verifyPin('1234');
      expect(status, AuthStatus.authenticatedReal);
    });

    test('Entering Duress PIN returns authenticatedDuress', () async {
      final status = await authService.verifyPin('9999');
      expect(status, AuthStatus.authenticatedDuress);
    });

    test('Entering Invalid PIN returns failed', () async {
      // '0000' is reserved as the nuclear-wipe PIN, so use a PIN that is
      // neither the real, duress, nor wipe PIN to test the failure path.
      final status = await authService.verifyPin('5555');
      expect(status, AuthStatus.failed);
    });
  });
}
