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

    test('login throws ApiException on 401 invalid credentials', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          json.encode({'error': 'invalid credentials'}),
          401,
        );
      });

      final apiClient = MewmerApiClient(httpClient: mockHttp);
      final provider = CloudProvider(
        apiClient: apiClient,
        sessionStore: InMemorySessionStore(),
        mediaCache: MediaCacheService(
          apiClient: apiClient,
          directoryProvider: () async => tempDir,
        ),
      );

      await expectLater(
        () => provider.login(email: 'wrong@mewmer.com', password: 'bad'),
        throwsA(isA<ApiException>()),
      );
      expect(provider.isAuthenticated, isFalse);
      expect(provider.errorMessage, 'invalid credentials');
    });

    test('createPack, uploadSticker, deleteSticker, and deletePack sync cleanly', () async {
      final traySource = File('${tempDir.path}/tray_src.png');
      await traySource.writeAsBytes([1, 2, 3]);
      final stickerSource = File('${tempDir.path}/sticker_src.webp');
      await stickerSource.writeAsBytes([4, 5, 6]);

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
        if (request.url.path == '/api/v1/packs' && request.method == 'POST') {
          return http.Response(
            json.encode({
              'id': 'p_new',
              'title': 'New Pack',
              'publisher': 'Admin · mewmer.com',
              'trayImageKey': 'https://cdn.example.com/tray_new.png',
              'isAnimated': false,
              'visibility': 'private',
              'userId': 'u1',
              'downloadsCount': 0,
              'createdAt': '2026-01-01T00:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/v1/packs/p_new/stickers' &&
            request.method == 'POST') {
          return http.Response(
            json.encode({
              'id': 's_new',
              'packId': 'p_new',
              'userId': 'u1',
              'imageKey': 'https://cdn.example.com/s_new.webp',
              'emojis': ['😂', '👍'],
              'byteSize': 3,
              'width': 512,
              'height': 512,
              'isAnimated': false,
              'sortOrder': 1,
              'createdAt': '2026-01-01T00:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/v1/packs/p_new' &&
            request.method == 'GET') {
          return http.Response(
            json.encode({
              'id': 'p_new',
              'title': 'New Pack',
              'publisher': 'Admin · mewmer.com',
              'trayImageKey': 'https://cdn.example.com/tray_new.png',
              'isAnimated': false,
              'visibility': 'private',
              'userId': 'u1',
              'downloadsCount': 0,
              'createdAt': '2026-01-01T00:00:00Z',
              'stickers': [
                {
                  'id': 's_new',
                  'packId': 'p_new',
                  'userId': 'u1',
                  'imageKey': 'https://cdn.example.com/s_new.webp',
                  'emojis': ['😂', '👍'],
                  'byteSize': 3,
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
        if (request.url.path == '/api/v1/stickers/s_new' &&
            request.method == 'DELETE') {
          return http.Response(json.encode({'status': 'deleted'}), 200);
        }
        if (request.url.path == '/api/v1/packs/p_new' &&
            request.method == 'DELETE') {
          return http.Response(json.encode({'status': 'deleted'}), 200);
        }
        if (request.url.path == '/tray_new.png') {
          return http.Response.bytes([1, 2, 3], 200);
        }
        if (request.url.path == '/s_new.webp') {
          return http.Response.bytes([4, 5, 6], 200);
        }
        return http.Response('Not found', 404);
      });

      final apiClient = MewmerApiClient(httpClient: mockHttp);
      final provider = CloudProvider(
        apiClient: apiClient,
        sessionStore: InMemorySessionStore(),
        mediaCache: MediaCacheService(
          apiClient: apiClient,
          directoryProvider: () async => tempDir,
        ),
      );

      await provider.login(email: 'admin@mewmer.com', password: 'secret');
      final created = await provider.createPack(
        title: 'New Pack',
        trayFile: traySource,
      );
      expect(created.id, 'p_new');

      final uploaded = await provider.uploadStickerToPack(
        packId: 'p_new',
        stickerFile: stickerSource,
        isAnimated: false,
        emojis: const ['😂', '👍'],
      );
      expect(uploaded.id, 's_new');
      expect(provider.localStickerPath('s_new'), isNotNull);

      await provider.deleteSticker('p_new', 's_new');
      expect(provider.localStickerPath('s_new'), isNull);
      expect(provider.packDetail('p_new')?.stickers, isEmpty);

      await provider.deletePack('p_new');
      expect(provider.packs, isEmpty);
      expect(provider.localTrayPath('p_new'), isNull);
    });

    test('paginates packs on loadMorePacks and passes search query q', () async {
      final seenQueries = <String>[];
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
          seenQueries.add(request.url.query);
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          final q = request.url.queryParameters['q'] ?? '';
          if (q == 'cat') {
            return http.Response(
              json.encode({
                'packs': [
                  {
                    'id': 'p_cat',
                    'title': 'Cat Pack',
                    'publisher': 'Admin · mewmer.com',
                    'trayImageKey': '',
                    'isAnimated': false,
                    'visibility': 'private',
                    'tags': ['cat', 'funny'],
                    'userId': 'u1',
                    'downloadsCount': 0,
                    'createdAt': '2026-01-01T00:00:00Z',
                  }
                ],
                'page': 1,
                'limit': 10,
                'total': 1,
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            json.encode({
              'packs': [
                {
                  'id': 'p_$page',
                  'title': 'Pack $page',
                  'publisher': 'Admin · mewmer.com',
                  'trayImageKey': '',
                  'isAnimated': false,
                  'visibility': 'private',
                  'tags': ['meme'],
                  'userId': 'u1',
                  'downloadsCount': 0,
                  'createdAt': '2026-01-01T00:00:00Z',
                }
              ],
              'page': page,
              'limit': 10,
              'total': 2,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = MewmerApiClient(httpClient: mockHttp);
      final provider = CloudProvider(
        apiClient: apiClient,
        sessionStore: InMemorySessionStore(),
        mediaCache: MediaCacheService(
          apiClient: apiClient,
          directoryProvider: () async => tempDir,
        ),
      );

      await provider.login(email: 'admin@mewmer.com', password: 'secret');
      expect(provider.packs.length, 1);
      expect(provider.hasMorePacks, isTrue);

      await provider.loadMorePacks();
      expect(provider.packs.length, 2);
      expect(provider.hasMorePacks, isFalse);

      await provider.refreshPacks(query: 'cat');
      expect(provider.packs.length, 1);
      expect(provider.packs.first.tags, ['cat', 'funny']);
      expect(seenQueries.last, contains('q=cat'));
    });
  });
}
