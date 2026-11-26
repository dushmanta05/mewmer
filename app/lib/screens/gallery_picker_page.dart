import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import '../theme.dart';

class GalleryPickerPage extends StatefulWidget {
  const GalleryPickerPage({super.key});

  @override
  State<GalleryPickerPage> createState() => _GalleryPickerPageState();
}

class _GalleryPickerPageState extends State<GalleryPickerPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, Future<Uint8List?>> _thumbCache = {};
  final Map<String, int> _albumCounts = {};

  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  bool _hasPermission = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 60;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initGallery();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMoreAssets();
    }
  }

  Future<void> _initGallery() async {
    setState(() => _isLoading = true);
    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );

    if (!permission.hasAccess) {
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    for (final album in albums) {
      _albumCounts[album.id] = await album.assetCountAsync;
    }

    final nonEmpty = albums.where((a) => (_albumCounts[a.id] ?? 0) > 0).toList();
    if (!mounted) return;
    setState(() {
      _hasPermission = true;
      _albums = nonEmpty;
      _selectedAlbum = nonEmpty.isNotEmpty ? nonEmpty.first : null;
    });

    if (_selectedAlbum != null) {
      await _loadAlbum(_selectedAlbum!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAlbum(AssetPathEntity album) async {
    setState(() {
      _selectedAlbum = album;
      _assets = [];
      _page = 0;
      _hasMore = true;
      _isLoading = true;
    });

    final items = await album.getAssetListPaged(page: 0, size: _pageSize);
    if (!mounted) return;
    setState(() {
      _assets = items;
      _hasMore = items.length >= _pageSize;
      _isLoading = false;
    });
  }

  Future<void> _loadMoreAssets() async {
    if (_isLoadingMore || !_hasMore || _selectedAlbum == null) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final items =
        await _selectedAlbum!.getAssetListPaged(page: nextPage, size: _pageSize);
    if (!mounted) return;
    setState(() {
      _page = nextPage;
      _assets.addAll(items);
      _hasMore = items.length >= _pageSize;
      _isLoadingMore = false;
    });
  }

  Future<Uint8List?> _thumbFuture(AssetEntity asset) {
    return _thumbCache.putIfAbsent(
      asset.id,
      () => asset.thumbnailDataWithSize(const ThumbnailSize.square(256)),
    );
  }

  Future<void> _pickFallbackSystem() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      Navigator.pop(context, File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MewmerTheme.background,
      appBar: AppBar(
        title: _albums.isEmpty
            ? Text(
                'Gallery',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<AssetPathEntity>(
                  value: _selectedAlbum,
                  dropdownColor: MewmerTheme.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: MewmerTheme.textPrimary,
                  ),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: MewmerTheme.textPrimary,
                  ),
                  items: _albums.map((album) {
                    final count = _albumCounts[album.id] ?? 0;
                    return DropdownMenuItem<AssetPathEntity>(
                      value: album,
                      child: Text(
                        '${album.name} ($count)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (album) {
                    if (album != null) {
                      _loadAlbum(album);
                    }
                  },
                ),
              ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MewmerTheme.brandViolet),
            )
          : !_hasPermission
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 52,
                          color: MewmerTheme.muted,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Gallery Access Needed',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: MewmerTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Allow photo access to browse albums, or use the system picker.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: MewmerTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await PhotoManager.openSetting();
                          },
                          child: const Text('Open Settings'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _pickFallbackSystem,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: MewmerTheme.border),
                          ),
                          child: const Text(
                            'Use System Picker',
                            style: TextStyle(color: MewmerTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _assets.isEmpty
                  ? const Center(
                      child: Text(
                        'No images found in this album.',
                        style: TextStyle(color: MewmerTheme.textMuted),
                      ),
                    )
                  : GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: _assets.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _assets.length) {
                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MewmerTheme.brandViolet,
                            ),
                          );
                        }
                        final asset = _assets[index];
                        final isGif = (asset.mimeType?.toLowerCase().contains('gif') ??
                                false) ||
                            (asset.title?.toLowerCase().endsWith('.gif') ?? false);

                        return GestureDetector(
                          onTap: () async {
                            final file = await asset.file;
                            if (file != null && context.mounted) {
                              Navigator.pop(context, file);
                            }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: MewmerTheme.cardSurface,
                                child: FutureBuilder<Uint8List?>(
                                  future: _thumbFuture(asset),
                                  builder: (context, snapshot) {
                                    final data = snapshot.data;
                                    if (data == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Image.memory(
                                      data,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    );
                                  },
                                ),
                              ),
                              if (isGif)
                                Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'GIF',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
