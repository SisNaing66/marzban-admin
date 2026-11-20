import 'package:local_auth/local_auth.dart';

final _auth = LocalAuthentication();

/// True while the system fingerprint dialog is up, and for 3s after it closes.
/// The dialog pauses/resumes the app; the lock gate must ignore those events.
bool authBusy = false;
DateTime? _authEnd;
bool authRecently() => authBusy || (_authEnd != null && DateTime.now().difference(_authEnd!).inSeconds < 3);

Future<bool> biometricAvailable() async {
  try {
    return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<bool> biometricAuth(String reason) async {
  if (authBusy) return false; // never open two prompts at once
  authBusy = true;
  try {
    return await _auth.authenticate(
        localizedReason: reason, options: const AuthenticationOptions(biometricOnly: true, stickyAuth: false));
  } catch (_) {
    return false;
  } finally {
    authBusy = false;
    _authEnd = DateTime.now();
  }
}
