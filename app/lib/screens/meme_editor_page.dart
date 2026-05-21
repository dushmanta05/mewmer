import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whatsapp_stickers_injector/whatsapp_stickers.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import '../models/text_item.dart';
import '../models/sticker_provider.dart';
import '../widgets/draggable_text.dart';

class MemeEditorPage extends StatefulWidget {
  final File imageFile;
  const MemeEditorPage({super.key, required this.imageFile});

  @override
  State<MemeEditorPage> createState() => _MemeEditorPageState();
}

class _MemeEditorPageState extends State<MemeEditorPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final List<TextItem> _textItems = [];
  TextItem? _selectedItem;

  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.white.withValues(alpha: 0.5),
    Colors.black.withValues(alpha: 0.5),
    Colors.deepPurple,
  ];

  final List<TextStyle> _fonts = [
    GoogleFonts.poppins(),
    GoogleFonts.roboto(),
    GoogleFonts.bebasNeue(),
    GoogleFonts.caveat(),
  ];

  void _addText() {
    final newItem = TextItem(
      text: 'Tap to edit',
      position: const Offset(100, 100),
      color: Colors.white,
      fontStyle: _fonts[0],
    );
    setState(() {
      _textItems.add(newItem);
      _selectedItem = newItem;
    });
  }

  Future<void> _captureSticker() async {
    setState(() => _selectedItem = null);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes == null) return;

      final Uint8List webpBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 512,
        minHeight: 512,
        format: CompressFormat.webp,
        quality: 80,
      );

      final tempDir = await getTemporaryDirectory();
      final String fileName = 'sticker_${DateTime.now().millisecondsSinceEpoch}.webp';
      final stickerFile = File('${tempDir.path}/$fileName');
      await stickerFile.writeAsBytes(webpBytes);

      if (mounted) {
        final stickerProvider = context.read<StickerProvider>();
        stickerProvider.addStickerToRecent(stickerFile.path);
        stickerProvider.addToCurrentPack(stickerFile.path);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sticker added to pack!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _exportToWhatsApp() async {
    final stickerProvider = context.read<StickerProvider>();
    final packStickers = stickerProvider.currentPack;

    if (packStickers.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need ${3 - packStickers.length} more stickers to create a pack!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      
      // Use the first sticker in the pack to generate a tray icon
      final firstStickerBytes = await File(packStickers[0].imagePath).readAsBytes();
      final Uint8List trayBytes = await FlutterImageCompress.compressWithList(
        firstStickerBytes,
        minWidth: 96,
        minHeight: 96,
        format: CompressFormat.png,
        quality: 80,
      );
      final trayFile = File('${tempDir.path}/tray_${DateTime.now().millisecondsSinceEpoch}.png');
      await trayFile.writeAsBytes(trayBytes);

      var stickerPack = WhatsappStickers(
        identifier: 'mewmer_pack_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Mewmer Pack',
        publisher: 'mewmer.com',
        trayImageFileName: WhatsappStickerImage.fromFile(trayFile.path),
        publisherWebsite: 'https://mewmer.com',
        privacyPolicyWebsite: 'https://mewmer.com/privacy',
        licenseAgreementWebsite: 'https://mewmer.com/license',
      );

      for (var sticker in packStickers) {
        stickerPack.addSticker(WhatsappStickerImage.fromFile(sticker.imagePath), ['✨']);
      }

      await stickerPack.sendToWhatsApp();
      stickerProvider.clearPack();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final packLength = context.watch<StickerProvider>().currentPack.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Meme'),
        actions: [
          // Counter for stickers in current pack
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: packLength >= 3 ? Colors.green : Colors.orange,
                child: Text(
                  '$packLength',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Add to Pack',
            onPressed: _captureSticker,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export Pack',
            onPressed: _exportToWhatsApp,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedItem = null),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(widget.imageFile, fit: BoxFit.cover),
                                BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 15,
                                    sigmaY: 15,
                                  ),
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                ),
                                Image.file(
                                  widget.imageFile,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ),
                        ..._textItems.map(
                          (item) => DraggableText(
                            item: item,
                            isSelected: _selectedItem == item,
                            onTap: () => setState(() => _selectedItem = item),
                            onUpdate: () => setState(() {}),
                            onDelete: () {
                              setState(() {
                                _textItems.remove(item);
                                _selectedItem = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_selectedItem != null) _buildPropertyPanel(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _addText,
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Add Text'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _fonts.map((font) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('Abc', style: font),
                    selected: _selectedItem!.fontStyle == font,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedItem!.fontStyle = font);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _colors.map((color) {
              return GestureDetector(
                onTap: () => setState(() => _selectedItem!.color = color),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedItem!.color == color
                          ? Colors.blue
                          : Colors.grey,
                      width: 2,
                    ),
                    boxShadow: [
                      if (color.a < 1)
                        BoxShadow(color: Colors.white24, blurRadius: 2),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
