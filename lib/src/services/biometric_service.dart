import 'package:local_auth/local_auth.dart';

/// Wrapper local_auth untuk kunci biometrik. [authenticate] memakai
/// `biometricOnly: false` agar jatuh ke PIN/pola perangkat bila
/// biometrik tidak tersedia — pengguna tidak akan terkunci.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final _auth = LocalAuthentication();

  /// Apakah perangkat mendukung autentikasi (biometrik ATAU kunci perangkat)?
  Future<bool> get canAuthenticate async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Minta autentikasi. Mengembalikan true jika lolos.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Buka kunci Saku',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
