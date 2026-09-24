import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to show vault',
        options: const AuthenticationOptions(useErrorDialogs: false),
      );
      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }
}\n