import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';

class MediaCacheService {
  final MewmerApiClient _apiClient;
  final Future<Directory> Function()? _directoryProvider;
  final Map<String, String> _cacheMap = {};
  bool _loaded = false;

  MediaCacheService({
    required MewmerApiClient apiClient,
    Future<Directory> Function()? directoryProvider,
  })  : _apiClient = apiClient,
        _directoryProvider = directoryProvider;

  Future<Directory> _getBaseDir() async {
    if (_directoryProvider != null) {
      return _directoryProvider();
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final dir = await _getBaseDir();
      final indexFile = File('${dir.path}/cloud_media_cache.json');
      if (await indexFile.exists()) {
        final raw = await indexFile.readAsString();
        final decoded = json.decode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is String) {
            _cacheMap[key] = value;
          }
        });
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _persistIndex() async {
    try {
      final dir = await _getBaseDir();
      final indexFile = File('${dir.path}/cloud_media_cache.json');
      await indexFile.writeAsString(json.encode(_cacheMap));
    } catch (_) {}
  }

  String? getCachedPath(String cacheKey) {
    final path = _cacheMap[cacheKey];
    if (path == null) return null;
    if (File(path).existsSync()) return path;
    return null;
  }

  Future<String?> getOrDownload({
    required String cacheKey,
    required String remoteUrl,
    required String relativePath,
  }) async {
    if (remoteUrl.isEmpty) return null;
    await _ensureLoaded();

    final existingPath = _cacheMap[cacheKey];
    if (existingPath != null) {
      final existingFile = File(existingPath);
      if (await existingFile.exists() && await existingFile.length() > 0) {
        return existingPath;
      }
    }

    final bytes = await _apiClient.downloadBytes(remoteUrl);
    final baseDir = await _getBaseDir();
    final targetFile = File('${baseDir.path}/cloud_cache/$relativePath');
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    await targetFile.writeAsBytes(bytes);

    _cacheMap[cacheKey] = targetFile.path;
    await _persistIndex();
    return targetFile.path;
  }

  Future<void> removeByKey(String cacheKey) async {
    await _ensureLoaded();
    final path = _cacheMap.remove(cacheKey);
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    await _persistIndex();
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    _cacheMap.clear();
    try {
      final baseDir = await _getBaseDir();
      final cacheDir = Directory('${baseDir.path}/cloud_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      final indexFile = File('${baseDir.path}/cloud_media_cache.json');
      if (await indexFile.exists()) {
        await indexFile.delete();
      }
    } catch (_) {}
  }
}
