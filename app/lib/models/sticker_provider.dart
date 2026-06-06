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

  StickerPack({
    required this.identifier,
    required this.name,
    required this.publisher,
    required this.stickerPaths,
    this.trayImagePath,
    required this.createdAt,
    this.isAnimated,
  });

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'name': name,
    'publisher': publisher,
    'stickerPaths': stickerPaths,
    'trayImagePath': trayImagePath,
    'createdAt': createdAt.toIso8601String(),
    'isAnimated': isAnimated,
  };

  factory StickerPack.fromJson(Map<String, dynamic> json) => StickerPack(
    identifier: json['identifier'] as String,
    name: json['name'] as String,
    publisher: json['publisher'] as String,
    stickerPaths: List<String>.from(json['stickerPaths'] as List),
    trayImagePath: json['trayImagePath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isAnimated: json['isAnimated'] as bool?,
  );
}

class StickerProvider extends ChangeNotifier {
  final List<Sticker> _recentStickers = [];
  final List<StickerPack> _packs = [];
  bool _isLoading = true;

  List<Sticker> get recentStickers => List.unmodifiable(_recentStickers);
  List<StickerPack> get packs => List.unmodifiable(_packs);
  bool get isLoading => _isLoading;

  Future<void> init() async {
    await loadFromStorage();
  }

  Future<File> _getMetadataFile() async {
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
  }) async {
    final id = 'mewmer_pack_${DateTime.now().millisecondsSinceEpoch}';
    final newPack = StickerPack(
      identifier: id,
      name: name.isEmpty ? 'Mewmer Pack' : name,
      publisher: publisher,
      stickerPaths: [],
      createdAt: DateTime.now(),
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
        throw 'Cannot mix animated and static stickers in the same pack!';
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
      _packs[packIndex].stickerPaths.remove(path);
      await saveToStorage();
      notifyListeners();
    }
  }

  Future<void> deletePack(String packIdentifier) async {
    _packs.removeWhere((p) => p.identifier == packIdentifier);
    await saveToStorage();
    notifyListeners();
  }

  Future<void> deleteRecentSticker(String path) async {
    _recentStickers.removeWhere((s) => s.imagePath == path);

    for (var pack in _packs) {
      pack.stickerPaths.remove(path);
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
}
