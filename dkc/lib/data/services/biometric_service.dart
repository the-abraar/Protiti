import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication auth;

  BiometricService({LocalAuthentication? auth}) : auth = auth ?? LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      // biometricOnly: the phone's own PIN or pattern, which an abuser often
      // knows, must never open the app.
      return await auth.authenticate(localizedReason: 'Unlock', biometricOnly: true);
    } catch (e) {
      return false;
    }
  }
}
