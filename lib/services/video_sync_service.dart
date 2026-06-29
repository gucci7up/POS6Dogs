import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'local_video_server.dart';

class SyncResult {
  final int downloaded;
  final int skipped;
  final int total;
  final int errors;

  SyncResult({
    required this.downloaded,
    required this.skipped,
    required this.total,
    required this.errors,
  });

  String get summary =>
      '$downloaded descargados · $skipped ya existían · $errors errores';
}

typedef SyncProgressCallback = void Function(int done, int total, String current);

class VideoSyncService {
  static const String _apiBase = 'https://api.mbsport.lat';
  static const _timeout = Duration(seconds: 30);
  static const _maxParallelSegments = 4; // descargar 4 segmentos a la vez

  static Future<SyncResult> sync({
    required String accessToken,
    required String videosDir,
    SyncProgressCallback? onProgress,
  }) async {
    final listResp = await http
        .get(
          Uri.parse('$_apiBase/videos/?activo=true'),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(_timeout);

    if (listResp.statusCode != 200) {
      throw Exception('Error al obtener lista de videos: ${listResp.statusCode}');
    }

    final videos = (jsonDecode(listResp.body) as List)
        .where((v) => v['hlsReady'] == true)
        .toList();

    int downloaded = 0, skipped = 0, errors = 0;

    for (int i = 0; i < videos.length; i++) {
      final video = videos[i];
      final archivo = (video['archivo'] as String? ?? '');
      final name = p.basenameWithoutExtension(archivo);

      onProgress?.call(i, videos.length, name);

      final videoDir = p.join(videosDir, 'hls', name);
      final playlistFile = File(p.join(videoDir, 'playlist.m3u8'));

      if (playlistFile.existsSync()) {
        skipped++;
        continue;
      }

      try {
        await _downloadVideo(
          name: name,
          videoDir: videoDir,
          accessToken: accessToken,
        );
        downloaded++;
      } catch (_) {
        errors++;
        // Borrar directorio parcial para que el próximo sync lo reintente
        try { Directory(videoDir).deleteSync(recursive: true); } catch (_) {}
      }
    }

    onProgress?.call(videos.length, videos.length, '');
    return SyncResult(
      downloaded: downloaded,
      skipped: skipped,
      total: videos.length,
      errors: errors,
    );
  }

  static Future<void> _downloadVideo({
    required String name,
    required String videoDir,
    required String accessToken,
  }) async {
    final headers = {'Authorization': 'Bearer $accessToken'};
    final baseUrl = '$_apiBase/videos/hls/$name';

    // Descargar playlist con timeout
    final playlistResp = await http
        .get(Uri.parse('$baseUrl/playlist.m3u8'), headers: headers)
        .timeout(_timeout);

    if (playlistResp.statusCode != 200) {
      throw Exception('Playlist no disponible para $name');
    }

    Directory(videoDir).createSync(recursive: true);
    File(p.join(videoDir, 'playlist.m3u8')).writeAsBytesSync(playlistResp.bodyBytes);

    final segments = _parseSegments(playlistResp.body);

    // Descargar segmentos en paralelo (lotes de _maxParallelSegments)
    for (int i = 0; i < segments.length; i += _maxParallelSegments) {
      final batch = segments.skip(i).take(_maxParallelSegments).toList();
      await Future.wait(batch.map((seg) => _downloadSegment(
        baseUrl: baseUrl,
        seg: seg,
        videoDir: videoDir,
        headers: headers,
      )));
    }
  }

  static Future<void> _downloadSegment({
    required String baseUrl,
    required String seg,
    required String videoDir,
    required Map<String, String> headers,
  }) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/$seg'), headers: headers)
          .timeout(_timeout);

      if (resp.statusCode != 200) return;

      final encrypted = LocalVideoServer.encryptBytes(resp.bodyBytes);
      final encName = seg.replaceAll('.ts', '.enc');
      File(p.join(videoDir, encName)).writeAsBytesSync(encrypted);
    } catch (_) {
      // Segmento fallido — se ignora, el video quedará incompleto
      // y el directorio se borrará en el catch del padre
      rethrow;
    }
  }

  static List<String> _parseSegments(String m3u8) =>
      m3u8
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toList();

  static void clearLocal(String videosDir) {
    final dir = Directory(videosDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
