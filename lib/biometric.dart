import 'package:local_auth/local_auth.dart';

final _auth = LocalAuthentication();

Future<bool> biometricAvailable() async {
  try {
    return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<bool> biometricAuth(String reason) async {
  try {
    return await _auth.authenticate(
        localizedReason: reason, options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true));
  } catch (_) {
    return false;
  }
}
