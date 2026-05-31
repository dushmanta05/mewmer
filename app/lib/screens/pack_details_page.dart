import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_stickers_injector/whatsapp_stickers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../models/sticker_provider.dart';

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

  Future<void> _exportToWhatsApp(BuildContext context, StickerPack pack) async {
    if (_isExporting) return;

    if (pack.stickerPaths.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Need ${3 - pack.stickerPaths.length} more stickers to add to WhatsApp (min 3)!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final tempDir = await getTemporaryDirectory();

      final firstStickerBytes = await File(pack.stickerPaths[0]).readAsBytes();
      img.Image? decoded = img.decodeImage(firstStickerBytes);
      if (decoded == null) throw 'Could not decode sticker for tray icon';

      img.Image trayResized = img.copyResize(decoded, width: 96, height: 96);
      final Uint8List trayPngBytes = Uint8List.fromList(
        img.encodePng(trayResized),
      );

      final String trayFileName =
          't_${pack.identifier}_${DateTime.now().millisecondsSinceEpoch}.png';
      final trayFile = File('${tempDir.path}/$trayFileName');
      await trayFile.writeAsBytes(trayPngBytes);

      var stickerPack = WhatsappStickers(
        identifier: pack.identifier,
        name: pack.name,
        publisher: pack.publisher,
        trayImageFileName: WhatsappStickerImage.fromFile(trayFile.path),
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
          content: Text('Pack shared to WhatsApp!'),
          backgroundColor: Colors.green,
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Stickers'),
        content: Text(
          'Are you sure you want to delete the ${_selectedStickers.length} selected sticker(s) from this pack?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
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

  Future<void> _deletePack(StickerProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pack'),
        content: const Text(
          'Are you sure you want to delete this entire sticker pack? The sticker files will remain in your recent folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
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

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedStickers.length} Selected')
            : Text(
                pack.name,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _deleteSelectedStickers(stickerProvider),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'Delete Pack',
              onPressed: () => _deletePack(stickerProvider),
            ),
            if (stickers.length >= 3)
              IconButton(
                icon: const Icon(Icons.share, color: Colors.greenAccent),
                tooltip: 'Add to WhatsApp',
                onPressed: () => _exportToWhatsApp(context, pack),
              ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Publisher: ${pack.publisher}',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${stickers.length} stickers',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (stickers.length < 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.orange,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Min 3 stickers for WhatsApp',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: stickers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.portrait,
                                size: 72,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No stickers in this pack yet!',
                                style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Create stickers and add them here.',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AspectRatio(
                                              aspectRatio: 1,
                                              child: Image.file(
                                                file,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceEvenly,
                                              children: [
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _toggleStickerSelection(
                                                      path,
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.select_all,
                                                  ),
                                                  label: const Text('Select'),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () async {
                                                    Navigator.pop(context);
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text(
                                                          'Remove Sticker',
                                                        ),
                                                        content: const Text(
                                                          'Remove this sticker from the pack?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  true,
                                                                ),
                                                            style:
                                                                ElevatedButton.styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                            child: const Text(
                                                              'Remove',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      await stickerProvider
                                                          .removeStickerFromPack(
                                                            widget
                                                                .packIdentifier,
                                                            path,
                                                          );
                                                    }
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor: Colors
                                                            .red
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.delete,
                                                  ),
                                                  label: const Text('Remove'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              onLongPress: () => _toggleStickerSelection(path),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.blue.shade400
                                              : Colors.white10,
                                          width: isSelected ? 3 : 1,
                                        ),
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.file(
                                          file,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: Colors.white30,
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_isSelectionMode)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.black54,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          isSelected
                                              ? Icons.check
                                              : Icons.circle,
                                          size: 14,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
