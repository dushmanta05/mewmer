import 'package:flutter/foundation.dart';

class Sticker {
  final String imagePath;
  final DateTime createdAt;

  Sticker({
    required this.imagePath,
    required this.createdAt,
  });
}

class StickerProvider extends ChangeNotifier {
  final List<Sticker> _recentStickers = [];
  final List<Sticker> _currentPack = [];
  String _currentPackName = 'Mewmer Pack';

  List<Sticker> get recentStickers => List.unmodifiable(_recentStickers);
  List<Sticker> get currentPack => List.unmodifiable(_currentPack);
  String get currentPackName => _currentPackName;

  void setPackName(String name) {
    _currentPackName = name.isEmpty ? 'Mewmer Pack' : name;
    notifyListeners();
  }

  void addStickerToRecent(String path) {
    _recentStickers.insert(0, Sticker(imagePath: path, createdAt: DateTime.now()));
    notifyListeners();
  }

  void addToCurrentPack(String path) {
    _currentPack.add(Sticker(imagePath: path, createdAt: DateTime.now()));
    notifyListeners();
  }

  void clearPack() {
    _currentPack.clear();
    _currentPackName = 'Mewmer Pack';
    notifyListeners();
  }
}
