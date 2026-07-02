import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';

/// Credenciales guardadas para reanudar la sesión sin volver a escribirlas.
class SavedCredentials {
  final String username;
  final String password;
  const SavedCredentials(this.username, this.password);
}

/// Guarda las credenciales del cajero cifradas (AES) en almacenamiento local
/// para que el POS reanude la sesión automáticamente al abrir, sin pedir
/// usuario y PIN cada vez. Se limpian solo al cerrar sesión explícitamente.
///
/// Nota: la clave está embebida en la app (ofuscación en reposo, no secreto
/// fuerte). Suficiente para un kiosco físicamente controlado; evita guardar la
/// contraseña en texto plano.
class SessionStore {
  static const _kUser = 'session_username';
  static const _kPassEnc = 'session_password_enc';
  static const _kIv = 'session_password_iv';

  // Clave AES de 32 bytes embebida (obfuscación en reposo).
  static final enc.Key _key =
      enc.Key.fromUtf8('MBSportP0S6-KioskSessionKey-2026');

  static Future<void> save(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(password, iv: iv);
    await prefs.setString(_kUser, username);
    await prefs.setString(_kPassEnc, encrypted.base64);
    await prefs.setString(_kIv, iv.base64);
  }

  static Future<SavedCredentials?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = prefs.getString(_kUser);
      final passEnc = prefs.getString(_kPassEnc);
      final ivStr = prefs.getString(_kIv);
      if (user == null || user.isEmpty || passEnc == null || ivStr == null) {
        return null;
      }
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      final password = encrypter.decrypt64(passEnc, iv: enc.IV.fromBase64(ivStr));
      if (password.isEmpty) return null;
      return SavedCredentials(user, password);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUser);
      await prefs.remove(_kPassEnc);
      await prefs.remove(_kIv);
    } catch (_) {
      // ignore
    }
  }
}
