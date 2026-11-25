class CloudUser {
  final String id;
  final String email;
  final String username;
  final String displayName;
  final String role;

  const CloudUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    required this.role,
  });

  factory CloudUser.fromJson(Map<String, dynamic> json) {
    return CloudUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'displayName': displayName,
        'role': role,
      };
}

class CloudSticker {
  final String id;
  final String packId;
  final String userId;
  final String imageUrl;
  final List<String> emojis;
  final int byteSize;
  final int width;
  final int height;
  final bool isAnimated;
  final int sortOrder;
  final DateTime createdAt;

  const CloudSticker({
    required this.id,
    required this.packId,
    required this.userId,
    required this.imageUrl,
    required this.emojis,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.isAnimated,
    required this.sortOrder,
    required this.createdAt,
  });

  factory CloudSticker.fromJson(Map<String, dynamic> json) {
    final rawEmojis = json['emojis'] as List<dynamic>? ?? const [];
    return CloudSticker(
      id: json['id'] as String? ?? '',
      packId: json['packId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      imageUrl: json['imageKey'] as String? ?? '',
      emojis: rawEmojis.map((e) => e.toString()).toList(),
      byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 512,
      height: (json['height'] as num?)?.toInt() ?? 512,
      isAnimated: json['isAnimated'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CloudPack {
  final String id;
  final String title;
  final String publisher;
  final String trayImageUrl;
  final bool isAnimated;
  final String visibility;
  final List<String> tags;
  final String userId;
  final int downloadsCount;
  final DateTime createdAt;
  final List<CloudSticker> stickers;

  const CloudPack({
    required this.id,
    required this.title,
    required this.publisher,
    required this.trayImageUrl,
    required this.isAnimated,
    required this.visibility,
    this.tags = const [],
    required this.userId,
    required this.downloadsCount,
    required this.createdAt,
    this.stickers = const [],
  });

  String get typeLabel => isAnimated ? 'Animated' : 'Static';

  CloudPack copyWith({
    String? id,
    String? title,
    String? publisher,
    String? trayImageUrl,
    bool? isAnimated,
    String? visibility,
    List<String>? tags,
    String? userId,
    int? downloadsCount,
    DateTime? createdAt,
    List<CloudSticker>? stickers,
  }) {
    return CloudPack(
      id: id ?? this.id,
      title: title ?? this.title,
      publisher: publisher ?? this.publisher,
      trayImageUrl: trayImageUrl ?? this.trayImageUrl,
      isAnimated: isAnimated ?? this.isAnimated,
      visibility: visibility ?? this.visibility,
      tags: tags ?? this.tags,
      userId: userId ?? this.userId,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      createdAt: createdAt ?? this.createdAt,
      stickers: stickers ?? this.stickers,
    );
  }

  factory CloudPack.fromJson(Map<String, dynamic> json) {
    final rawStickers = json['stickers'] as List<dynamic>? ?? const [];
    final rawTags = json['tags'] as List<dynamic>? ?? const [];
    return CloudPack(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      publisher: json['publisher'] as String? ?? 'mewmer.com',
      trayImageUrl: json['trayImageKey'] as String? ?? '',
      isAnimated: json['isAnimated'] as bool? ?? false,
      visibility: json['visibility'] as String? ?? 'private',
      tags: rawTags.map((t) => t.toString()).toList(),
      userId: json['userId'] as String? ?? '',
      downloadsCount: (json['downloadsCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      stickers: rawStickers
          .map((s) => CloudSticker.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaginatedCloudPacks {
  final List<CloudPack> packs;
  final int page;
  final int limit;
  final int total;

  const PaginatedCloudPacks({
    required this.packs,
    required this.page,
    required this.limit,
    required this.total,
  });
}
