import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/cloud_models.dart';
import '../models/sticker_provider.dart';
import '../services/api_client.dart';
import '../services/media_cache_service.dart';
import '../services/session_store.dart';

class CloudProvider extends ChangeNotifier {
  final MewmerApiClient _apiClient;
  final SessionStore _sessionStore;
  final MediaCacheService _mediaCache;
  final Future<Directory> Function()? _tempDirProvider;

  CloudUser? _user;
  String? _token;
  List<CloudPack> _packs = [];
  final Map<String, CloudPack> _packDetails = {};
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isLoadingMore = false;
  final Set<String> _syncingPackIds = {};
  int _currentPage = 1;
  int _totalPacks = 0;
  static const int _pageSize = 10;
  String _searchQuery = '';
  String? _errorMessage;

  CloudProvider({
    MewmerApiClient? apiClient,
    SessionStore? sessionStore,
    MediaCacheService? mediaCache,
    Future<Directory> Function()? tempDirProvider,
  })  : _apiClient = apiClient ?? MewmerApiClient(),
        _sessionStore = sessionStore ?? SecureSessionStore(),
        _mediaCache = mediaCache ??
            MediaCacheService(apiClient: apiClient ?? MewmerApiClient()),
        _tempDirProvider = tempDirProvider;

  CloudUser? get user => _user;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty && _user != null;
  List<CloudPack> get packs => List.unmodifiable(_packs);
  int get totalPacks => _totalPacks;
  bool get hasMorePacks => _packs.length < _totalPacks;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isLoadingMore => _isLoadingMore;
  bool isPackSyncing(String packIdentifier) =>
      _syncingPackIds.contains(packIdentifier);
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;
  String get baseUrl => _apiClient.baseUrl;

  CloudPack? packDetail(String packId) => _packDetails[packId];

  String? localTrayPath(String packId) =>
      _mediaCache.getCachedPath('pack:$packId:tray');

  String? localStickerPath(String stickerId) =>
      _mediaCache.getCachedPath('sticker:$stickerId');

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final savedUrl = await _sessionStore.readBaseUrl();
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _apiClient.setBaseUrl(savedUrl);
      }
      final savedToken = await _sessionStore.readToken();
      final savedUser = await _sessionStore.readUser();
      if (savedToken != null && savedToken.isNotEmpty) {
        _token = savedToken;
        _user = savedUser;
        try {
          final freshUser = await _apiClient.getMe(savedToken);
          _user = freshUser;
          await _sessionStore.writeUser(freshUser);
        } on ApiException catch (e) {
          if (e.statusCode == 401) {
            await _clearLocalAuth();
          }
        } catch (_) {}
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateBaseUrl(String url) async {
    _apiClient.setBaseUrl(url);
    await _sessionStore.writeBaseUrl(_apiClient.baseUrl);
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
    String? serverUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (serverUrl != null && serverUrl.trim().isNotEmpty) {
        await updateBaseUrl(serverUrl);
      }
      final result = await _apiClient.login(email: email, password: password);
      _token = result.token;
      _user = result.user;
      await _sessionStore.writeToken(result.token);
      await _sessionStore.writeUser(result.user);
      await refreshPacks();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      rethrow;
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final token = _token;
    if (token != null && token.isNotEmpty) {
      await _apiClient.logout(token);
    }
    await _clearLocalAuth();
    notifyListeners();
  }

  Future<void> _clearLocalAuth() async {
    _token = null;
    _user = null;
    _packs = [];
    _totalPacks = 0;
    _currentPage = 1;
    _searchQuery = '';
    _packDetails.clear();
    await _sessionStore.clearSession();
  }

  Future<void> refreshPacks({String? query}) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    if (query != null) {
      _searchQuery = query.trim();
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiClient.listMyPacks(
        token,
        query: _searchQuery,
        page: 1,
        limit: _pageSize,
      );
      _packs = result.packs;
      _currentPage = result.page;
      _totalPacks = result.total;
      for (final pack in result.packs) {
        await _downloadTrayIfPresent(pack);
      }
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _clearLocalAuth();
      }
      _errorMessage = e.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePacks() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    if (_isLoadingMore || _isSyncing || !hasMorePacks) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final result = await _apiClient.listMyPacks(
        token,
        query: _searchQuery,
        page: nextPage,
        limit: _pageSize,
      );
      final existingIds = _packs.map((p) => p.id).toSet();
      final newPacks =
          result.packs.where((p) => !existingIds.contains(p.id)).toList();
      _packs = [..._packs, ...newPacks];
      _currentPage = result.page;
      _totalPacks = result.total;
      for (final pack in newPacks) {
        await _downloadTrayIfPresent(pack);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _clearLocalAuth();
      }
      _errorMessage = e.message;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<CloudPack> fetchPackDetails(String packId) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Not signed in');
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final pack = await _apiClient.getPack(token, packId);
      _packDetails[packId] = pack;
      final idx = _packs.indexWhere((p) => p.id == packId);
      if (idx != -1) {
        _packs[idx] = pack;
      }
      await _downloadTrayIfPresent(pack);
      for (final sticker in pack.stickers) {
        await _downloadStickerIfPresent(pack.id, sticker);
      }
      notifyListeners();
      return pack;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _clearLocalAuth();
      }
      _errorMessage = e.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<CloudPack> createPack({
    required String title,
    required File trayFile,
    bool isAnimated = false,
    List<String> tags = const [],
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Not signed in');
    }

    final created = await _apiClient.createPack(
      token,
      title: title,
      trayFile: trayFile,
      visibility: 'private',
      isAnimated: isAnimated,
      tags: tags,
    );
    _packs.insert(0, created);
    _totalPacks += 1;
    _packDetails[created.id] = created;
    await _downloadTrayIfPresent(created);
    notifyListeners();
    return created;
  }

  Future<CloudSticker> uploadStickerToPack({
    required String packId,
    required File stickerFile,
    required bool isAnimated,
    List<String> emojis = const ['✨'],
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Not signed in');
    }

    final uploaded = await _apiClient.uploadSticker(
      token,
      packId: packId,
      stickerFile: stickerFile,
      isAnimated: isAnimated,
      emojis: emojis,
    );

    await _downloadStickerIfPresent(packId, uploaded);
    await fetchPackDetails(packId);
    return uploaded;
  }

  Future<Directory> _getTempDir() =>
      _tempDirProvider != null ? _tempDirProvider() : getTemporaryDirectory();

  Future<File> buildTrayIconFromSticker(File stickerFile) async {
    final bytes = await stickerFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode sticker for tray icon');
    }
    final firstFrame = decoded.numFrames > 1 ? decoded.frames[0] : decoded;
    final staticFrame = img.Image(
      width: firstFrame.width,
      height: firstFrame.height,
      numChannels: 4,
    );
    img.compositeImage(staticFrame, firstFrame);
    final trayResized = img.copyResize(staticFrame, width: 96, height: 96);
    final trayPngBytes = Uint8List.fromList(img.encodePng(trayResized));
    final tempDir = await _getTempDir();
    final trayFile = File(
      '${tempDir.path}/cloud_tray_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await trayFile.writeAsBytes(trayPngBytes);
    return trayFile;
  }

  Future<File> _buildFallbackTrayIcon() async {
    final blank = img.Image(width: 96, height: 96, numChannels: 4);
    img.fill(blank, color: img.ColorRgba8(139, 92, 246, 255));
    final trayPngBytes = Uint8List.fromList(img.encodePng(blank));
    final tempDir = await _getTempDir();
    final trayFile = File(
      '${tempDir.path}/cloud_tray_default_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await trayFile.writeAsBytes(trayPngBytes);
    return trayFile;
  }

  Future<void> syncLocalPack(
    StickerProvider localProvider,
    StickerPack pack,
  ) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Not signed in');
    }
    if (_syncingPackIds.contains(pack.identifier)) return;

    _syncingPackIds.add(pack.identifier);
    notifyListeners();

    try {
      String? cloudId = pack.cloudPackId;
      if (cloudId == null || cloudId.isEmpty) {
        File trayFile;
        if (pack.trayImagePath != null && File(pack.trayImagePath!).existsSync()) {
          trayFile = File(pack.trayImagePath!);
        } else if (pack.stickerPaths.isNotEmpty &&
            File(pack.stickerPaths.first).existsSync()) {
          trayFile = await buildTrayIconFromSticker(File(pack.stickerPaths.first));
        } else {
          trayFile = await _buildFallbackTrayIcon();
        }
        final created = await createPack(
          title: pack.name,
          trayFile: trayFile,
          isAnimated: pack.isActuallyAnimated,
          tags: pack.tags,
        );
        cloudId = created.id;
      }

      if (pack.pendingDeleteStickerIds.isNotEmpty) {
        final deletedIds = <String>[];
        for (final stickerId in List<String>.from(pack.pendingDeleteStickerIds)) {
          try {
            await _apiClient.deleteSticker(token, stickerId);
            await _mediaCache.removeByKey('sticker:$stickerId');
            deletedIds.add(stickerId);
          } on ApiException catch (e) {
            if (e.statusCode == 404) {
              deletedIds.add(stickerId);
            } else {
              rethrow;
            }
          }
        }
        await localProvider.clearPendingStickerDeletes(
          pack.identifier,
          deletedIds,
        );
      }

      final newlySynced = <String, String>{};
      for (final localPath in pack.stickerPaths) {
        if (pack.syncedStickers.containsKey(localPath)) continue;
        final file = File(localPath);
        if (!await file.exists()) continue;
        final uploaded = await _apiClient.uploadSticker(
          token,
          packId: cloudId,
          stickerFile: file,
          isAnimated: pack.isActuallyAnimated,
        );
        await _downloadStickerIfPresent(cloudId, uploaded);
        newlySynced[localPath] = uploaded.id;
      }

      await localProvider.markPackSynced(pack.identifier, cloudId, newlySynced);
    } finally {
      _syncingPackIds.remove(pack.identifier);
      notifyListeners();
    }
  }

  Future<void> syncAll(StickerProvider localProvider) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Not signed in');
    }

    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (localProvider.pendingDeleteCloudPackIds.isNotEmpty) {
        final deletedPackIds = <String>[];
        for (final packId
            in List<String>.from(localProvider.pendingDeleteCloudPackIds)) {
          try {
            await deletePack(packId);
            deletedPackIds.add(packId);
          } on ApiException catch (e) {
            if (e.statusCode == 404) {
              deletedPackIds.add(packId);
            } else {
              rethrow;
            }
          }
        }
        await localProvider.clearPendingPackDeletes(deletedPackIds);
      }

      final pendingLocal = localProvider.packs
          .where((p) => p.hasPendingSync)
          .toList();
      for (final pack in pendingLocal) {
        await syncLocalPack(localProvider, pack);
      }

      int page = 1;
      final remotePacks = <CloudPack>[];
      while (true) {
        final res = await _apiClient.listMyPacks(token, page: page, limit: 50);
        remotePacks.addAll(res.packs);
        if (remotePacks.length >= res.total || res.packs.isEmpty) break;
        page += 1;
      }

      for (final summary in remotePacks) {
        final alreadyLinked = localProvider.packs.any(
          (p) => p.cloudPackId == summary.id,
        );
        if (alreadyLinked) continue;

        final detail = await fetchPackDetails(summary.id);
        final trayPath = localTrayPath(detail.id);
        final localPaths = <String>[];
        final syncedMap = <String, String>{};
        for (final s in detail.stickers) {
          final path = localStickerPath(s.id);
          if (path != null) {
            localPaths.add(path);
            syncedMap[path] = s.id;
          }
        }
        await localProvider.upsertCloudPack(
          cloudPackId: detail.id,
          name: detail.title,
          publisher: detail.publisher,
          isAnimated: detail.isAnimated,
          tags: detail.tags,
          createdAt: detail.createdAt,
          trayImagePath: trayPath,
          localStickerPaths: localPaths,
          syncedStickers: syncedMap,
        );
      }
      _packs = remotePacks;
      _totalPacks = remotePacks.length;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> deletePack(String packId) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Not signed in');
    }

    await _apiClient.deletePack(token, packId);
    final removed = _packDetails.remove(packId);
    _packs.removeWhere((p) => p.id == packId);
    await _mediaCache.removeByKey('pack:$packId:tray');
    if (removed != null) {
      for (final s in removed.stickers) {
        await _mediaCache.removeByKey('sticker:${s.id}');
      }
    }
    notifyListeners();
  }

  Future<void> deleteSticker(String packId, String stickerId) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const ApiException(401, 'Not signed in');
    }

    await _apiClient.deleteSticker(token, stickerId);
    await _mediaCache.removeByKey('sticker:$stickerId');
    final existing = _packDetails[packId];
    if (existing != null) {
      _packDetails[packId] = existing.copyWith(
        stickers: existing.stickers.where((s) => s.id != stickerId).toList(),
      );
    }
    notifyListeners();
  }

  Future<void> _downloadTrayIfPresent(CloudPack pack) async {
    if (pack.trayImageUrl.isEmpty) return;
    final cleanUrl = pack.trayImageUrl.split('?').first.toLowerCase();
    final ext = cleanUrl.endsWith('.webp') ? 'webp' : 'png';
    try {
      await _mediaCache.getOrDownload(
        cacheKey: 'pack:${pack.id}:tray',
        remoteUrl: pack.trayImageUrl,
        relativePath: 'packs/${pack.id}/tray.$ext',
      );
    } catch (_) {}
  }

  Future<void> _downloadStickerIfPresent(
    String packId,
    CloudSticker sticker,
  ) async {
    if (sticker.imageUrl.isEmpty) return;
    try {
      await _mediaCache.getOrDownload(
        cacheKey: 'sticker:${sticker.id}',
        remoteUrl: sticker.imageUrl,
        relativePath: 'packs/$packId/stickers/${sticker.id}.webp',
      );
    } catch (_) {}
  }
}
