import 'dart:convert';
import 'package:http/http.dart' as http;

/// Exception thrown when the backend responds with a 4xx/5xx status.
/// `message` is the human-readable message extracted from the response body.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Result of a successful login.
class AuthResult {
  final String accessToken;
  final String userId;
  final String username;
  final String role;
  final String? agencyId;
  final String? agencyName;

  AuthResult({
    required this.accessToken,
    required this.userId,
    required this.username,
    required this.role,
    this.agencyId,
    this.agencyName,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final agency = user['agency'] as Map<String, dynamic>?;
    return AuthResult(
      accessToken: json['accessToken'] as String,
      userId: user['id'] as String,
      username: (user['username'] ?? user['email'] ?? '') as String,
      role: user['role'] as String,
      agencyId: user['agencyId'] as String?,
      agencyName: agency?['name'] as String?,
    );
  }
}

/// Thin wrapper around the Racing Dogs backend REST API.
class ApiClient {
  static const String baseUrl = 'https://api.mbsport.lat';

  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: _headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null);
        break;
      default:
        throw ArgumentError('Método no soportado: $method');
    }

    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 400) {
      throw ApiException(_extractErrorMessage(decoded), statusCode: response.statusCode);
    }

    return decoded;
  }

  String _extractErrorMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String) return message;
      if (message is List && message.isNotEmpty) return message.join('\n');
    }
    return 'Error de comunicación con el servidor';
  }

  Future<AuthResult> login(String username, String password) async {
    final json = await _request('POST', '/auth/login', body: {
      'username': username,
      'password': password,
    });
    final auth = AuthResult.fromJson(json as Map<String, dynamic>);
    setToken(auth.accessToken);
    return auth;
  }

  /// Devuelve {key, iv} en base64 para encriptación local de videos,
  /// o null si el servidor no tiene configurada la clave.
  Future<Map<String, String>?> getVideoEncryptionKey(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/videos/encryption-key');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['localEnabled'] != true) return null;
      return {
        'key': data['key'] as String,
        'iv':  data['iv']  as String,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getRaceEngineStatus() async {
    return await _request('GET', '/race-engine/status') as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRaceOddsLive(String raceId) async {
    return await _request('GET', '/odds/race/$raceId/live') as List<dynamic>;
  }

  Future<List<dynamic>> getRaceOdds(String raceId) async {
    return await _request('GET', '/odds/race/$raceId') as List<dynamic>;
  }

  Future<List<dynamic>> getRaceHistory({int limit = 13}) async {
    return await _request('GET', '/races/history?limit=$limit') as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTicket({
    required String raceId,
    required List<Map<String, String>> details,
  }) async {
    return await _request('POST', '/tickets', body: {
      'raceId': raceId,
      'details': details,
    }) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTickets() async {
    return await _request('GET', '/tickets') as List<dynamic>;
  }

  Future<Map<String, dynamic>> getTicketByNumber(int ticketNumber) async {
    return await _request('GET', '/tickets/number/$ticketNumber') as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPendingPaymentTickets() async {
    return await _request('GET', '/tickets/pending-payment') as List<dynamic>;
  }

  Future<void> payTicket(String ticketId) async {
    await _request('POST', '/tickets/$ticketId/pay');
  }
}
