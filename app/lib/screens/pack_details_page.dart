import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_stickers_injector/whatsapp_stickers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../models/cloud_provider.dart';
import '../models/sticker_provider.dart';
import '../theme.dart';
import '../widgets/pack_sync_badge.dart';
import 'meme_editor_page.dart';

class PackDetailsPage extends StatefulWidget {
  final String packIdentifier;

  const PackDetailsPage({super.key, required this.packIdentifier});

  @override
  State<PackDetailsPage> createState() => _PackDetailsPageState();
}

class _PackDetailsPageState extends State<PackDetailsPage> {
  final Set<String> _selectedStickers = {};
  bool _isSelectionMode = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _downloadIfNeeded();
    });
  }

  Future<void> _downloadIfNeeded() async {
    final stickerProvider = context.read<StickerProvider>();
    final cloud = context.read<CloudProvider>();
    final pack = stickerProvider.packs
        .where((p) => p.identifier == widget.packIdentifier)
        .firstOrNull;
    if (pack != null &&
        pack.isCloudLinked &&
        !pack.cloudDownloaded &&
        cloud.isAuthenticated) {
      try {
        await cloud.downloadPackStickers(stickerProvider, pack);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download stickers: $e'),
            backgroundColor: MewmerTheme.rose,
          ),
        );
      }
    }
  }

  Future<void> _exportToWhatsApp(BuildContext context, StickerPack pack) async {
    if (_isExporting) return;

    if (pack.stickerPaths.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Need ${3 - pack.stickerPaths.length} more stickers to add to WhatsApp (min 3)!',
          ),
          backgroundColor: MewmerTheme.amber,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      String trayPath;
      if (pack.trayImagePath != null && File(pack.trayImagePath!).existsSync()) {
        trayPath = pack.trayImagePath!;
      } else {
        final tempDir = await getTemporaryDirectory();

        final firstStickerBytes = await File(pack.stickerPaths[0]).readAsBytes();
        img.Image? decoded = img.decodeImage(firstStickerBytes);
        if (decoded == null) throw 'Could not decode sticker for tray icon';

        final bool isAnimated = decoded.numFrames > 1;
        final img.Image firstFrame = isAnimated ? decoded.frames[0] : decoded;
        final img.Image staticFrame = img.Image(
          width: firstFrame.width,
          height: firstFrame.height,
          numChannels: 4,
        );
        img.compositeImage(staticFrame, firstFrame);

        img.Image trayResized = img.copyResize(staticFrame, width: 96, height: 96);
        final Uint8List trayPngBytes = Uint8List.fromList(
          img.encodePng(trayResized),
        );

        final String trayFileName =
            't_${pack.identifier}_${DateTime.now().millisecondsSinceEpoch}.png';
        final trayFile = File('${tempDir.path}/$trayFileName');
        await trayFile.writeAsBytes(trayPngBytes);
        trayPath = trayFile.path;
      }

      var stickerPack = WhatsappStickers(
        identifier: pack.identifier,
        name: pack.name,
        publisher: pack.publisher,
        trayImageFileName: WhatsappStickerImage.fromFile(trayPath),
        publisherWebsite: 'https://mewmer.com',
        privacyPolicyWebsite: 'https://mewmer.com/privacy',
        licenseAgreementWebsite: 'https://mewmer.com/license',
      );

      for (var stickerPath in pack.stickerPaths) {
        stickerPack.addSticker(WhatsappStickerImage.fromFile(stickerPath), [
          '✨',
        ]);
      }

      await stickerPack.sendToWhatsApp();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pack added to WhatsApp!'),
          backgroundColor: MewmerTheme.whatsappGreen,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _toggleStickerSelection(String path) {
    setState(() {
      if (_selectedStickers.contains(path)) {
        _selectedStickers.remove(path);
        if (_selectedStickers.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedStickers.add(path);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStickers.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedStickers(StickerProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: const Text(
            'Delete Stickers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          content: Text(
            'Delete ${_selectedStickers.length} sticker(s) from this pack?',
            style: const TextStyle(fontSize: 13, color: MewmerTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: MewmerTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: MewmerTheme.rose,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      for (var path in _selectedStickers) {
        await provider.removeStickerFromPack(widget.packIdentifier, path);
      }
      _clearSelection();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stickers removed from pack.')),
      );
    }
  }

  Future<void> _showEditPackDialog(StickerPack pack) async {
    final stickerProvider = context.read<StickerProvider>();
    final cloud = context.read<CloudProvider>();
    final nameController = TextEditingController(text: pack.name);
    final tagsController = TextEditingController(text: pack.tags.join(', '));
    String? selectedStickerForTray;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            title: const Text(
              'Edit Pack',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Pack Name',
                        hintText: 'Mewmer Cat',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: tagsController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'meme, funny, cats',
                        helperText: 'Separate with commas (max 5)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (pack.stickerPaths.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Tray Icon',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MewmerTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap a sticker to use as the pack icon.',
                        style: TextStyle(
                          fontSize: 11,
                          color: MewmerTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pack.stickerPaths.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final path = pack.stickerPaths[idx];
                            final isSelected = selectedStickerForTray == path;
                            return GestureDetector(
                              onTap: isSaving
                                  ? null
                                  : () => setDialogState(
                                        () => selectedStickerForTray = path,
                                      ),
                              child: Container(
                                width: 64,
                                height: 64,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: MewmerTheme.cardHover,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? MewmerTheme.brandViolet
                                        : MewmerTheme.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: MewmerTheme.muted,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: MewmerTheme.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) return;
                        setDialogState(() => isSaving = true);
                        try {
                          String? trayPath;
                          if (selectedStickerForTray != null) {
                            final built = await cloud.buildTrayIconFromSticker(
                              File(selectedStickerForTray!),
                            );
                            final appDir =
                                await getApplicationDocumentsDirectory();
                            final trayDir = Directory('${appDir.path}/trays');
                            if (!await trayDir.exists()) {
                              await trayDir.create(recursive: true);
                            }
                            final persisted = File(
                              '${trayDir.path}/tray_${pack.identifier}_${DateTime.now().millisecondsSinceEpoch}.png',
                            );
                            await built.copy(persisted.path);
                            trayPath = persisted.path;
                          }
                          final parsedTags = tagsController.text
                              .split(',')
                              .map((e) => e.trim().toLowerCase())
                              .where((e) => e.isNotEmpty)
                              .toSet()
                              .toList();
                          if (parsedTags.length > 5) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Maximum 5 tags allowed'),
                                  backgroundColor: MewmerTheme.rose,
                                ),
                              );
                            }
                            return;
                          }
                          await stickerProvider.updatePackDetails(
                            pack.identifier,
                            name: newName,
                            tags: parsedTags,
                            trayImagePath: trayPath,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                        }
                      },
                child: Text(isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePack(StickerProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: const Text(
            'Delete Pack',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          content: const Text(
            'Delete this entire pack? Sticker files will remain in your recent collection.',
            style: TextStyle(fontSize: 13, color: MewmerTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: MewmerTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: MewmerTheme.rose,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await provider.deletePack(widget.packIdentifier);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sticker pack deleted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stickerProvider = context.watch<StickerProvider>();
    final cloud = context.watch<CloudProvider>();
    final packIndex = stickerProvider.packs.indexWhere(
      (p) => p.identifier == widget.packIdentifier,
    );

    if (packIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pack Details')),
        body: const Center(child: Text('Pack not found.')),
      );
    }

    final pack = stickerProvider.packs[packIndex];
    final stickers = pack.stickerPaths;
    final canExport = stickers.length >= 3;
    final isDownloading = cloud.isPackDownloading(pack.identifier) ||
        (pack.isCloudLinked && !pack.cloudDownloaded);
    final downloadProgress = cloud.packDownloadProgress(pack.identifier);

    return Scaffold(
      backgroundColor: MewmerTheme.background,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedStickers.length} Selected')
            : Text(
                pack.name,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_isSelectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: () => _deleteSelectedStickers(stickerProvider),
                style: TextButton.styleFrom(
                  backgroundColor: MewmerTheme.rose.withValues(alpha: 0.14),
                  foregroundColor: MewmerTheme.rose,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else ...[
            OutlinedButton(
              onPressed: () => _showEditPackDialog(pack),
              style: OutlinedButton.styleFrom(
                foregroundColor: MewmerTheme.textPrimary,
                side: const BorderSide(color: MewmerTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: () => _deletePack(stickerProvider),
                style: TextButton.styleFrom(
                  backgroundColor: MewmerTheme.rose.withValues(alpha: 0.14),
                  foregroundColor: MewmerTheme.rose,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MewmerTheme.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MewmerTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Row(
                            children: [
                              Text(
                                pack.publisher,
                                style: const TextStyle(
                                  color: MewmerTheme.brandViolet,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pack.isActuallyAnimated
                                      ? MewmerTheme.brandViolet.withValues(alpha: 0.2)
                                      : MewmerTheme.whatsappGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  pack.typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: pack.isActuallyAnimated
                                        ? MewmerTheme.brandViolet
                                        : MewmerTheme.whatsappGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stickers.length} / 30 stickers',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: MewmerTheme.textPrimary,
                            ),
                          ),
                          if (pack.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: pack.tags
                                  .take(5)
                                  .map(
                                    (t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: MewmerTheme.cardHover,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#$t',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: MewmerTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      PackSyncBadge(pack: pack, showLabel: true),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MemeEditorPage(initialPackId: pack.identifier),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: MewmerTheme.brandViolet,
                    ),
                    label: const Text(
                      'Add Sticker',
                      style: TextStyle(
                        color: MewmerTheme.brandViolet,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: MewmerTheme.brandViolet.withValues(alpha: 0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: stickers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 56,
                              color: MewmerTheme.muted,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No stickers in this pack',
                              style: GoogleFonts.spaceGrotesk(
                                color: MewmerTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create stickers from the studio to add here.',
                              style: TextStyle(
                                color: MewmerTheme.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: stickers.length,
                        itemBuilder: (context, index) {
                          final path = stickers[index];
                          final isSelected = _selectedStickers.contains(path);
                          final file = File(path);

                          return GestureDetector(
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleStickerSelection(path);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MemeEditorPage(
                                      imageFile: file,
                                      initialPackId: pack.identifier,
                                    ),
                                  ),
                                );
                              }
                            },
                            onLongPress: () => _toggleStickerSelection(path),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? MewmerTheme.brandViolet : MewmerTheme.border,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                color: MewmerTheme.cardSurface,
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: MewmerTheme.muted,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (_isSelectionMode)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? MewmerTheme.brandViolet : Colors.black54,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        padding: const EdgeInsets.all(3),
                                        child: Icon(
                                          isSelected ? Icons.check : Icons.circle,
                                          size: 12,
                                          color: isSelected ? Colors.white : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: const BoxDecoration(
                  color: MewmerTheme.cardSurface,
                  border: Border(top: BorderSide(color: MewmerTheme.border)),
                ),
                child: isDownloading
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MewmerTheme.brandViolet,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                downloadProgress != null &&
                                        downloadProgress.total > 0
                                    ? 'Downloading stickers (${downloadProgress.downloaded}/${downloadProgress.total})...'
                                    : 'Downloading pack stickers...',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: MewmerTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (downloadProgress != null &&
                              downloadProgress.fraction != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: downloadProgress.fraction,
                                minHeight: 5,
                                backgroundColor: MewmerTheme.cardHover,
                                color: MewmerTheme.brandViolet,
                              ),
                            ),
                          ],
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: canExport && !_isExporting
                              ? () => _exportToWhatsApp(context, pack)
                              : null,
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                          label: Text(
                            canExport
                                ? 'Add to WhatsApp'
                                : 'Add at least 3 stickers to export',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MewmerTheme.whatsappGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: MewmerTheme.cardHover,
                            disabledForegroundColor: MewmerTheme.textMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: MewmerTheme.whatsappGreen),
              ),
            ),
        ],
      ),
    );
  }
}
