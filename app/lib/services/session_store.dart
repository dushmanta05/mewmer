import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/cloud_models.dart';

abstract class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<CloudUser?> readUser();
  Future<void> writeUser(CloudUser user);
  Future<String?> readBaseUrl();
  Future<void> writeBaseUrl(String baseUrl);
  Future<void> clearSession();
}

class SecureSessionStore implements SessionStore {
  static const _tokenKey = 'mewmer_auth_token';
  static const _userKey = 'mewmer_auth_user';
  static const _baseUrlKey = 'mewmer_api_base_url';

  final FlutterSecureStorage _storage;

  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<CloudUser?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CloudUser.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeUser(CloudUser user) =>
      _storage.write(key: _userKey, value: json.encode(user.toJson()));

  @override
  Future<String?> readBaseUrl() => _storage.read(key: _baseUrlKey);

  @override
  Future<void> writeBaseUrl(String baseUrl) =>
      _storage.write(key: _baseUrlKey, value: baseUrl);

  @override
  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
