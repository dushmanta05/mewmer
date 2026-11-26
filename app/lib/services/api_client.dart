import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/cloud_models.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class LoginResult {
  final CloudUser user;
  final String token;

  const LoginResult({required this.user, required this.token});
}

class MewmerApiClient {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3030/api/v1',
  );

  String baseUrl;
  final http.Client _http;

  MewmerApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = _normalizeBaseUrl(baseUrl ?? apiBaseUrl),
        _http = httpClient ?? http.Client();

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void setBaseUrl(String url) {
    baseUrl = _normalizeBaseUrl(url);
  }

  String resolveMediaUrl(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    final parsed = Uri.parse(baseUrl);
    final origin = '${parsed.scheme}://${parsed.host}${parsed.hasPort ? ':${parsed.port}' : ''}';
    if (urlOrPath.startsWith('/')) {
      return '$origin$urlOrPath';
    }
    return '$origin/$urlOrPath';
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
      };

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email.trim(), 'password': password}),
    );

    final body = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        body['error'] as String? ?? 'Login failed',
      );
    }

    final userJson = body['user'] as Map<String, dynamic>?;
    final token = body['token'] as String?;
    if (userJson == null || token == null || token.isEmpty) {
      throw const ApiException(500, 'Invalid login response');
    }

    return LoginResult(
      user: CloudUser.fromJson(userJson),
      token: token,
    );
  }

  Future<CloudUser> getMe(String token) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _authHeaders(token),
    );
    final body = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        body['error'] as String? ?? 'Failed to fetch user',
      );
    }
    return CloudUser.fromJson(body);
  }

  Future<void> logout(String token) async {
    try {
      await _http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _authHeaders(token),
      );
    } catch (_) {}
  }

  Future<PaginatedCloudPacks> listMyPacks(
    String token, {
    String? query,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    final uri = Uri.parse('$baseUrl/me/packs').replace(queryParameters: params);
    final response = await _http.get(
      uri,
      headers: _authHeaders(token),
    );
    final body = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        body['error'] as String? ?? 'Failed to list packs',
      );
    }
    final rawList = body['packs'] as List<dynamic>? ?? const [];
    final packs = rawList
        .map((p) => CloudPack.fromJson(p as Map<String, dynamic>))
        .toList();
    return PaginatedCloudPacks(
      packs: packs,
      page: (body['page'] as num?)?.toInt() ?? page,
      limit: (body['limit'] as num?)?.toInt() ?? limit,
      total: (body['total'] as num?)?.toInt() ?? packs.length,
    );
  }

  Future<CloudPack> getPack(String token, String packId) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/packs/$packId'),
      headers: _authHeaders(token),
    );
    final body = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        body['error'] as String? ?? 'Failed to load pack',
      );
    }
    return CloudPack.fromJson(body);
  }

  Future<CloudPack> createPack(
    String token, {
    required String title,
    required File trayFile,
    String visibility = 'private',
    List<String> tags = const [],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/packs'),
    );
    request.headers.addAll(_authHeaders(token));
    request.fields['title'] = title.trim();
    request.fields['visibility'] = visibility;
    if (tags.isNotEmpty) {
      request.fields['tags'] = tags.join(',');
    }
    request.files.add(
      await http.MultipartFile.fromPath('tray', trayFile.path),
    );

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final body = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        body['error'] as String? ?? 'Failed to create pack',
      );
    }
    return CloudPack.fromJson(body);
  }

  Future<CloudSticker> uploadSticker(
    String token, {
    required String packId,
    required File stickerFile,
    required bool isAnimated,
    List<String> emojis = const ['✨'],
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/packs/$packId/stickers'),
    );
    request.headers.addAll(_authHeaders(token));
    request.fields['isAnimated'] = isAnimated.toString();
    request.fields['emojis'] = emojis.join(',');
    request.files.add(
      await http.MultipartFile.fromPath('sticker', stickerFile.path),
    );

    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    final body = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        body['error'] as String? ?? 'Failed to upload sticker',
      );
    }
    return CloudSticker.fromJson(body);
  }

  Future<void> deleteSticker(String token, String stickerId) async {
    final response = await _http.delete(
      Uri.parse('$baseUrl/stickers/$stickerId'),
      headers: _authHeaders(token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _decodeJsonMap(response);
      throw ApiException(
        response.statusCode,
        body['error'] as String? ?? 'Failed to delete sticker',
      );
    }
  }

  Future<void> deletePack(String token, String packId) async {
    final response = await _http.delete(
      Uri.parse('$baseUrl/packs/$packId'),
      headers: _authHeaders(token),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = _decodeJsonMap(response);
      throw ApiException(
        response.statusCode,
        body['error'] as String? ?? 'Failed to delete pack',
      );
    }
  }

  Future<List<int>> downloadBytes(String urlOrPath) async {
    final resolved = resolveMediaUrl(urlOrPath);
    final response = await _http.get(Uri.parse(resolved));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Failed to download media');
    }
    return response.bodyBytes;
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }
}
