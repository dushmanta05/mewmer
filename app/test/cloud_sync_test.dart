import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mewmer/models/cloud_models.dart';
import 'package:mewmer/models/cloud_provider.dart';
import 'package:mewmer/services/api_client.dart';
import 'package:mewmer/services/media_cache_service.dart';
import 'package:mewmer/services/session_store.dart';

class InMemorySessionStore implements SessionStore {
  String? _token;
  CloudUser? _user;
  String? _baseUrl;

  @override
  Future<void> clearSession() async {
    _token = null;
    _user = null;
  }

  @override
  Future<String?> readBaseUrl() async => _baseUrl;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<CloudUser?> readUser() async => _user;

  @override
  Future<void> writeBaseUrl(String baseUrl) async {
    _baseUrl = baseUrl;
  }

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> writeUser(CloudUser user) async {
    _user = user;
  }
}

void main() {
  group('MewmerApiClient & MediaCacheService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mewmer_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('login stores token and fetches packs with bearer auth', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login' &&
            request.method == 'POST') {
          final body = json.decode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'admin@mewmer.com');
          expect(body['password'], 'secret');
          return http.Response(
            json.encode({
              'user': {
                'id': 'u1',
                'email': 'admin@mewmer.com',
                'username': 'admin',
                'displayName': 'Admin',
                'role': 'admin',
              },
              'token': 'tok_123',
            }),
            200,
          );
        }

        if (request.url.path == '/api/v1/me/packs' && request.method == 'GET') {
          expect(request.headers['Authorization'], 'Bearer tok_123');
          return http.Response(
            json.encode({
              'packs': [
                {
                  'id': 'p1',
                  'title': 'Cloud Cats',
                  'publisher': 'Admin · mewmer.com',
                  'trayImageKey': '/uploads/mewmer-private-media/packs/p1/tray.png',
                  'isAnimated': false,
                  'visibility': 'private',
                  'userId': 'u1',
                  'downloadsCount': 0,
                  'createdAt': '2026-01-01T00:00:00Z',
                }
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/uploads/mewmer-private-media/packs/p1/tray.png') {
          return http.Response.bytes([1, 2, 3, 4], 200);
        }

        return http.Response('Not found', 404);
      });

      final apiClient = MewmerApiClient(httpClient: mockHttp);
      final sessionStore = InMemorySessionStore();
      final mediaCache = MediaCacheService(
        apiClient: apiClient,
        directoryProvider: () async => tempDir,
      );
      final provider = CloudProvider(
        apiClient: apiClient,
        sessionStore: sessionStore,
        mediaCache: mediaCache,
      );

      await provider.login(email: 'admin@mewmer.com', password: 'secret');

      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?.email, 'admin@mewmer.com');
      expect(await sessionStore.readToken(), 'tok_123');
      expect(provider.packs.length, 1);
      expect(provider.packs.first.title, 'Cloud Cats');

      final cachedTray = provider.localTrayPath('p1');
      expect(cachedTray, isNotNull);
      expect(File(cachedTray!).existsSync(), isTrue);
    });

    test('fetchPackDetails downloads stickers to local files and caches them', () async {
      int stickerDownloadCount = 0;
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(
            json.encode({
              'user': {
                'id': 'u1',
                'email': 'admin@mewmer.com',
                'username': 'admin',
                'displayName': 'Admin',
                'role': 'admin',
              },
              'token': 'tok_123',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/me/packs') {
          return http.Response(json.encode({'packs': []}), 200);
        }
        if (request.url.path == '/api/v1/packs/p1') {
          return http.Response(
            json.encode({
              'id': 'p1',
              'title': 'Cloud Cats',
              'publisher': 'Admin · mewmer.com',
              'trayImageKey': 'https://cdn.example.com/tray.png?sig=abc',
              'isAnimated': false,
              'visibility': 'private',
              'userId': 'u1',
              'downloadsCount': 0,
              'createdAt': '2026-01-01T00:00:00Z',
              'stickers': [
                {
                  'id': 's1',
                  'packId': 'p1',
                  'userId': 'u1',
                  'imageKey': 'https://cdn.example.com/s1.webp?sig=xyz',
                  'emojis': ['😂'],
                  'byteSize': 1024,
                  'width': 512,
                  'height': 512,
                  'isAnimated': false,
                  'sortOrder': 1,
                  'createdAt': '2026-01-01T00:00:00Z',
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/tray.png') {
          return http.Response.bytes([10, 20, 30], 200);
        }
        if (request.url.path == '/s1.webp') {
          stickerDownloadCount++;
          return http.Response.bytes([82, 73, 70, 70], 200);
        }
        return http.Response('Not found', 404);
      });

      final apiClient = MewmerApiClient(httpClient: mockHttp);
      final sessionStore = InMemorySessionStore();
      final mediaCache = MediaCacheService(
        apiClient: apiClient,
        directoryProvider: () async => tempDir,
      );
      final provider = CloudProvider(
        apiClient: apiClient,
        sessionStore: sessionStore,
        mediaCache: mediaCache,
      );

      await provider.login(email: 'admin@mewmer.com', password: 'secret');
      await provider.fetchPackDetails('p1');
      await provider.fetchPackDetails('p1');

      expect(stickerDownloadCount, 1);
      final localPath = provider.localStickerPath('s1');
      expect(localPath, isNotNull);
      expect(await File(localPath!).readAsBytes(), [82, 73, 70, 70]);
    });
  });
}
