import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Servidor HTTP local que sirve los videos HLS encriptados desde disco,
/// desencriptándolos en memoria antes de enviarlos al display.
class LocalVideoServer {
  static HttpServer? _server;
  static String? _videosDir;
  static const int port = 8765;

  // Clave AES-256-CBC inyectada desde el servidor (nunca hardcodeada)
  static enc.Key? _key;
  static enc.IV? _iv;
  static enc.Encrypter? _encrypter;

  static bool get hasKey => _encrypter != null;

  /// Inyecta la clave obtenida del backend (base64, 32 y 16 bytes).
  static void setKey(String keyBase64, String ivBase64) {
    _key = enc.Key(base64Decode(keyBase64));
    _iv  = enc.IV(base64Decode(ivBase64));
    _encrypter = enc.Encrypter(enc.AES(_key!, mode: enc.AESMode.cbc));
  }

  static Future<void> start(String videosDirectory) async {
    if (_server != null) return;
    _videosDir = videosDirectory;

    final handler = Pipeline()
        .addMiddleware(_cors)
        .addHandler(_handle);

    _server = await shelf_io.serve(handler, 'localhost', port);
  }

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  static bool get isRunning => _server != null;

  // ── Encriptación (usada por VideoSyncService al guardar) ──────────────────

  static Uint8List encryptBytes(Uint8List plain) {
    if (_encrypter == null || _iv == null) throw Exception('Clave no configurada');
    return _encrypter!.encryptBytes(plain, iv: _iv!).bytes;
  }

  static Uint8List decryptBytes(Uint8List cipher) {
    if (_encrypter == null || _iv == null) throw Exception('Clave no configurada');
    return Uint8List.fromList(_encrypter!.decryptBytes(enc.Encrypted(cipher), iv: _iv!));
  }

  // ── Middleware CORS ───────────────────────────────────────────────────────

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Range, Authorization',
    'Access-Control-Expose-Headers': 'Content-Length',
  };

  static final Middleware _cors = (Handler inner) => (Request req) async {
    if (req.method == 'OPTIONS') return Response.ok('', headers: _corsHeaders);
    final res = await inner(req);
    return res.change(headers: _corsHeaders);
  };

  // ── Handler principal ─────────────────────────────────────────────────────

  static Response _handle(Request req) {
    final dir = _videosDir;
    if (dir == null) return Response.internalServerError();
    if (!hasKey) return Response.forbidden('Clave no disponible');

    var path = req.url.path;
    if (path.startsWith('videos/')) path = path.substring(7);

    final localPath = p.joinAll([dir, ...path.split('/')]);

    if (path.endsWith('.m3u8')) {
      final file = File(localPath);
      if (!file.existsSync()) return Response.notFound('Not found: $path');
      return Response.ok(
        file.readAsBytesSync(),
        headers: {'Content-Type': 'application/vnd.apple.mpegurl', 'Cache-Control': 'no-cache'},
      );
    }

    if (path.endsWith('.ts')) {
      final encPath = localPath.replaceAll('.ts', '.enc');
      final file = File(encPath);
      if (!file.existsSync()) return Response.notFound('Not found: $encPath');
      try {
        return Response.ok(
          decryptBytes(file.readAsBytesSync()),
          headers: {'Content-Type': 'video/mp2t'},
        );
      } catch (_) {
        return Response.internalServerError(body: 'Decrypt error');
      }
    }

    return Response.notFound('Not found');
  }
}
