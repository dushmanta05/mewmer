import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Sticker {
  final String imagePath;
  final DateTime createdAt;

  Sticker({required this.imagePath, required this.createdAt});

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Sticker.fromJson(Map<String, dynamic> json) => Sticker(
    imagePath: json['imagePath'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class StickerPack {
  final String identifier;
  String name;
  final String publisher;
  final List<String> stickerPaths;
  String? trayImagePath;
  final DateTime createdAt;
  bool? isAnimated;
  String? cloudPackId;
  bool cloudDownloaded;
  bool pendingMetadataSync;
  final Map<String, String> syncedStickers;
  final List<String> pendingDeleteStickerIds;
  final List<String> tags;

  bool get isActuallyAnimated => isAnimated == true;
  String get typeLabel => isActuallyAnimated ? 'Animated' : 'Static';
  bool get isCloudLinked => cloudPackId != null && cloudPackId!.isNotEmpty;
  int get pendingSyncCount =>
      stickerPaths.where((p) => !syncedStickers.containsKey(p)).length;
  bool get hasPendingSync =>
      !isCloudLinked ||
      pendingSyncCount > 0 ||
      pendingDeleteStickerIds.isNotEmpty ||
      pendingMetadataSync;

  StickerPack({
    required this.identifier,
    required this.name,
    required this.publisher,
    required List<String> stickerPaths,
    this.trayImagePath,
    required this.createdAt,
    this.isAnimated,
    this.cloudPackId,
    this.cloudDownloaded = true,
    this.pendingMetadataSync = false,
    Map<String, String>? syncedStickers,
    List<String>? pendingDeleteStickerIds,
    List<String>? tags,
  })  : stickerPaths = List<String>.from(stickerPaths),
        syncedStickers = Map<String, String>.from(syncedStickers ?? const {}),
        pendingDeleteStickerIds =
            List<String>.from(pendingDeleteStickerIds ?? const []),
        tags = List<String>.from(tags ?? const []);

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'name': name,
    'publisher': publisher,
    'stickerPaths': stickerPaths,
    'trayImagePath': trayImagePath,
    'createdAt': createdAt.toIso8601String(),
    'isAnimated': isAnimated,
    'cloudPackId': cloudPackId,
    'cloudDownloaded': cloudDownloaded,
    'pendingMetadataSync': pendingMetadataSync,
    'syncedStickers': syncedStickers,
    'pendingDeleteStickerIds': pendingDeleteStickerIds,
    'tags': tags,
  };

  factory StickerPack.fromJson(Map<String, dynamic> json) {
    final rawSynced = json['syncedStickers'] as Map<String, dynamic>? ?? const {};
    final synced = <String, String>{};
    rawSynced.forEach((k, v) {
      if (v is String) synced[k] = v;
    });
    final rawPendingDeletes =
        json['pendingDeleteStickerIds'] as List<dynamic>? ?? const [];
    final rawTags = json['tags'] as List<dynamic>? ?? const [];
    return StickerPack(
      identifier: json['identifier'] as String,
      name: json['name'] as String,
      publisher: json['publisher'] as String,
      stickerPaths: List<String>.from(json['stickerPaths'] as List),
      trayImagePath: json['trayImagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isAnimated: json['isAnimated'] as bool?,
      cloudPackId: json['cloudPackId'] as String?,
      cloudDownloaded: json['cloudDownloaded'] as bool? ?? true,
      pendingMetadataSync: json['pendingMetadataSync'] as bool? ?? false,
      syncedStickers: synced,
      pendingDeleteStickerIds:
          rawPendingDeletes.map((e) => e.toString()).toList(),
      tags: rawTags.map((e) => e.toString()).toList(),
    );
  }
}

class StickerProvider extends ChangeNotifier {
  final Future<File> Function()? _metadataFileProvider;
  final List<Sticker> _recentStickers = [];
  final List<StickerPack> _packs = [];
  final List<String> _pendingDeleteCloudPackIds = [];
  bool _isLoading = true;

  StickerProvider({Future<File> Function()? metadataFileProvider})
      : _metadataFileProvider = metadataFileProvider;

  List<Sticker> get recentStickers => List.unmodifiable(_recentStickers);
  List<StickerPack> get packs => List.unmodifiable(_packs);
  List<String> get pendingDeleteCloudPackIds =>
      List.unmodifiable(_pendingDeleteCloudPackIds);
  bool get isLoading => _isLoading;

  Future<void> init() async {
    await loadFromStorage();
  }

  Future<File> _getMetadataFile() async {
    if (_metadataFileProvider != null) {
      return _metadataFileProvider();
    }
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/stickers_metadata.json';
    return File(path);
  }

  Future<void> loadFromStorage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final file = await _getMetadataFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;

        _recentStickers.clear();
        if (data['recentStickers'] != null) {
          for (var item in data['recentStickers']) {
            _recentStickers.add(Sticker.fromJson(item));
          }
        }

        _packs.clear();
        if (data['packs'] != null) {
          for (var item in data['packs']) {
            _packs.add(StickerPack.fromJson(item));
          }
        }

        _pendingDeleteCloudPackIds.clear();
        if (data['pendingDeleteCloudPackIds'] != null) {
          for (var id in data['pendingDeleteCloudPackIds']) {
            _pendingDeleteCloudPackIds.add(id.toString());
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading stickers metadata: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveToStorage() async {
    try {
      final file = await _getMetadataFile();
      final data = {
        'recentStickers': _recentStickers.map((s) => s.toJson()).toList(),
        'packs': _packs.map((p) => p.toJson()).toList(),
        'pendingDeleteCloudPackIds': _pendingDeleteCloudPackIds,
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint('Error saving stickers metadata: $e');
    }
  }

  Future<String> persistStickerFile(String tempPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final stickersDir = Directory('${appDir.path}/stickers');
    if (!await stickersDir.exists()) {
      await stickersDir.create(recursive: true);
    }

    final originalFile = File(tempPath);
    final fileName = tempPath.split('/').last;
    final newFile = File('${stickersDir.path}/$fileName');

    await originalFile.copy(newFile.path);

    try {
      await originalFile.delete();
    } catch (_) {}

    return newFile.path;
  }

  Future<void> addStickerToRecent(String path) async {
    final persistentPath = await persistStickerFile(path);
    _recentStickers.insert(
      0,
      Sticker(imagePath: persistentPath, createdAt: DateTime.now()),
    );
    await saveToStorage();
    notifyListeners();
  }

  Future<void> createPack(
    String name, {
    String publisher = 'mewmer.com',
    bool isAnimated = false,
  }) async {
    final id = 'mewmer_pack_${DateTime.now().millisecondsSinceEpoch}';
    final newPack = StickerPack(
      identifier: id,
      name: name.isEmpty ? 'Mewmer Pack' : name,
      publisher: publisher,
      stickerPaths: [],
      createdAt: DateTime.now(),
      isAnimated: isAnimated,
    );
    _packs.insert(0, newPack);
    await saveToStorage();
    notifyListeners();
  }

  Future<void> addStickerToPack(String packIdentifier, String path, {required bool isAnimated}) async {
    String persistentPath = path;
    if (path.contains('/temp/') || path.contains('/cache/')) {
      persistentPath = await persistStickerFile(path);
    }

    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex != -1) {
      final pack = _packs[packIndex];

      if (pack.isAnimated != null && pack.isAnimated != isAnimated) {
        final packType = pack.isAnimated == true ? 'animated' : 'static';
        final stickerType = isAnimated ? 'animated' : 'static';
        throw 'Cannot add $stickerType sticker to a $packType pack. WhatsApp does not allow mixing static and animated stickers!';
      }

      pack.isAnimated ??= isAnimated;

      if (!pack.stickerPaths.contains(persistentPath)) {
        pack.stickerPaths.add(persistentPath);

        final existsInRecent = _recentStickers.any(
          (s) => s.imagePath == persistentPath,
        );
        if (!existsInRecent) {
          _recentStickers.insert(
            0,
            Sticker(imagePath: persistentPath, createdAt: DateTime.now()),
          );
        }

        await saveToStorage();
        notifyListeners();
      }
    }
  }

  Future<void> removeStickerFromPack(String packIdentifier, String path) async {
    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex != -1) {
      final pack = _packs[packIndex];
      pack.stickerPaths.remove(path);
      final cloudStickerId = pack.syncedStickers.remove(path);
      if (cloudStickerId != null &&
          !pack.pendingDeleteStickerIds.contains(cloudStickerId)) {
        pack.pendingDeleteStickerIds.add(cloudStickerId);
      }
      await saveToStorage();
      notifyListeners();
    }
  }

  Future<void> deletePack(String packIdentifier) async {
    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex != -1) {
      final cloudId = _packs[packIndex].cloudPackId;
      if (cloudId != null &&
          cloudId.isNotEmpty &&
          !_pendingDeleteCloudPackIds.contains(cloudId)) {
        _pendingDeleteCloudPackIds.add(cloudId);
      }
      _packs.removeAt(packIndex);
      await saveToStorage();
      notifyListeners();
    }
  }

  Future<void> deleteRecentSticker(String path) async {
    _recentStickers.removeWhere((s) => s.imagePath == path);

    for (var pack in _packs) {
      pack.stickerPaths.remove(path);
      final cloudStickerId = pack.syncedStickers.remove(path);
      if (cloudStickerId != null &&
          !pack.pendingDeleteStickerIds.contains(cloudStickerId)) {
        pack.pendingDeleteStickerIds.add(cloudStickerId);
      }
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting sticker file: $e');
    }

    await saveToStorage();
    notifyListeners();
  }

  Future<void> updatePackTrayImage(
    String packIdentifier,
    String trayPath,
  ) async {
    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex != -1) {
      _packs[packIndex].trayImagePath = trayPath;
      await saveToStorage();
      notifyListeners();
    }
  }

  Future<void> markPackSynced(
    String packIdentifier,
    String cloudPackId,
    Map<String, String> newlySyncedStickers,
  ) async {
    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex != -1) {
      _packs[packIndex].cloudPackId = cloudPackId;
      _packs[packIndex].pendingMetadataSync = false;
      _packs[packIndex].syncedStickers.addAll(newlySyncedStickers);
      await saveToStorage();
      notifyListeners();
    }
  }

  Future<void> updatePackDetails(
    String packIdentifier, {
    required String name,
    required List<String> tags,
    String? trayImagePath,
  }) async {
    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex == -1) return;
    final pack = _packs[packIndex];
    pack.name = name;
    pack.tags
      ..clear()
      ..addAll(tags);
    if (trayImagePath != null) {
      pack.trayImagePath = trayImagePath;
    }
    if (pack.isCloudLinked) {
      pack.pendingMetadataSync = true;
    }
    await saveToStorage();
    notifyListeners();
  }

  Future<void> clearPendingStickerDeletes(
    String packIdentifier,
    List<String> deletedIds,
  ) async {
    final packIndex = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (packIndex != -1) {
      _packs[packIndex]
          .pendingDeleteStickerIds
          .removeWhere((id) => deletedIds.contains(id));
      await saveToStorage();
      notifyListeners();
    }
  }

  Future<void> clearPendingPackDeletes(List<String> deletedPackIds) async {
    _pendingDeleteCloudPackIds.removeWhere((id) => deletedPackIds.contains(id));
    await saveToStorage();
    notifyListeners();
  }

  Future<void> upsertCloudPack({
    required String cloudPackId,
    required String name,
    required String publisher,
    required bool isAnimated,
    required List<String> tags,
    required DateTime createdAt,
    String? trayImagePath,
    bool cloudDownloaded = false,
    required List<String> localStickerPaths,
    required Map<String, String> syncedStickers,
  }) async {
    final idx = _packs.indexWhere((p) => p.cloudPackId == cloudPackId);
    if (idx == -1) {
      _packs.add(
        StickerPack(
          identifier: 'cloud_$cloudPackId',
          name: name,
          publisher: publisher,
          stickerPaths: localStickerPaths,
          trayImagePath: trayImagePath,
          createdAt: createdAt,
          isAnimated: isAnimated,
          cloudPackId: cloudPackId,
          cloudDownloaded: cloudDownloaded,
          syncedStickers: syncedStickers,
          tags: tags,
        ),
      );
    } else {
      final pack = _packs[idx];
      pack.name = name;
      if (trayImagePath != null) {
        pack.trayImagePath = trayImagePath;
      }
      if (cloudDownloaded) {
        pack.cloudDownloaded = true;
      }
      for (final path in localStickerPaths) {
        if (!pack.stickerPaths.contains(path)) {
          pack.stickerPaths.add(path);
        }
      }
      pack.syncedStickers.addAll(syncedStickers);
    }
    await saveToStorage();
    notifyListeners();
  }

  Future<void> markPackHydrated(
    String packIdentifier, {
    required List<String> localStickerPaths,
    required Map<String, String> syncedStickers,
    String? trayImagePath,
  }) async {
    final idx = _packs.indexWhere((p) => p.identifier == packIdentifier);
    if (idx == -1) return;
    final pack = _packs[idx];
    if (trayImagePath != null) {
      pack.trayImagePath = trayImagePath;
    }
    for (final path in localStickerPaths) {
      if (!pack.stickerPaths.contains(path)) {
        pack.stickerPaths.add(path);
      }
    }
    pack.syncedStickers.addAll(syncedStickers);
    pack.cloudDownloaded = true;
    await saveToStorage();
    notifyListeners();
  }
}
