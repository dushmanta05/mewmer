import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
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

  final List<TextStyle> _fonts = [GoogleFonts.poppins(), GoogleFonts.caveat()];

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
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes == null) return;

      img.Image? decoded = img.decodeImage(imageBytes);
      if (decoded == null) return;

      img.Image resized = img.copyResize(
        decoded,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );

      final Uint8List rawResizedBytes = Uint8List.fromList(
        img.encodePng(resized),
      );

      final Uint8List webpBytes = await FlutterImageCompress.compressWithList(
        rawResizedBytes,
        format: CompressFormat.webp,
        quality: 40,
      );

      final tempDir = await getTemporaryDirectory();
      final String fileName = 's_${DateTime.now().millisecondsSinceEpoch}.webp';
      final stickerFile = File('${tempDir.path}/$fileName');
      await stickerFile.writeAsBytes(webpBytes);

      if (mounted) {
        await _showSavePackDialog(stickerFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showSavePackDialog(String tempStickerPath) async {
    final stickerProvider = context.read<StickerProvider>();
    final packs = stickerProvider.packs;

    String? selectedPackId = packs.isNotEmpty ? packs.first.identifier : null;
    final textController = TextEditingController();
    bool createNew = packs.isEmpty;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Save to Sticker Pack'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (packs.isNotEmpty) ...[
                      const Text(
                        'Choose an existing pack:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedPackId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: packs.map((pack) {
                          return DropdownMenuItem<String>(
                            value: pack.identifier,
                            child: Text(
                              '${pack.name} (${pack.stickerPaths.length} stickers)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: createNew
                            ? null
                            : (val) {
                                setDialogState(() {
                                  selectedPackId = val;
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: createNew,
                            onChanged: (val) {
                              setDialogState(() {
                                createNew = val ?? false;
                                if (createNew) selectedPackId = null;
                              });
                            },
                          ),
                          const Text('Or create a new pack'),
                        ],
                      ),
                    ],
                    if (createNew) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'New Pack Name:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        decoration: const InputDecoration(
                          hintText: 'Enter pack name',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        autofocus: true,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final packName = textController.text.trim();
                    if (createNew && packName.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a pack name'),
                        ),
                      );
                      return;
                    }
                    if (!createNew && selectedPackId == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Please select a pack')),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      String targetPackId;
                      if (createNew) {
                        await stickerProvider.createPack(packName);
                        targetPackId = stickerProvider.packs.first.identifier;
                      } else {
                        targetPackId = selectedPackId!;
                      }

                      await stickerProvider.addStickerToPack(
                        targetPackId,
                        tempStickerPath,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sticker saved and added to pack!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save sticker: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Meme'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 28),
            onPressed: _captureSticker,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedItem = null),
              child: Center(
                child: AspectRatio(aspectRatio: 1, child: _buildEditorCanvas()),
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

  Widget _buildEditorCanvas() {
    return Screenshot(
      controller: _screenshotController,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(widget.imageFile, fit: BoxFit.cover),
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
          Image.file(widget.imageFile, fit: BoxFit.contain),

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
    );
  }

  Widget _buildPropertyPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.rotate_left),
                onPressed: () {
                  setState(() {
                    _selectedItem!.rotation -= 0.15;
                  });
                },
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        if (_selectedItem!.fontSize > 8) {
                          _selectedItem!.fontSize -= 2;
                        }
                      });
                    },
                  ),
                  Text(
                    'Size: ${_selectedItem!.fontSize.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      setState(() {
                        if (_selectedItem!.fontSize < 100) {
                          _selectedItem!.fontSize += 2;
                        }
                      });
                    },
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.rotate_right),
                onPressed: () {
                  setState(() {
                    _selectedItem!.rotation += 0.15;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: const Text('Meme Style'),
                  selected: _selectedItem!.isMemeStyle,
                  onSelected: (val) {
                    setState(() {
                      _selectedItem!.isMemeStyle = val;
                      if (val) {
                        _selectedItem!.useCaps = true;
                        _selectedItem!.hasShadow = true;
                        _selectedItem!.color = Colors.white;
                        _selectedItem!.outlineColor = Colors.black;
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('ALL CAPS'),
                  selected: _selectedItem!.useCaps,
                  onSelected: (val) {
                    setState(() {
                      _selectedItem!.useCaps = val;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Drop Shadow'),
                  selected: _selectedItem!.hasShadow,
                  onSelected: (val) {
                    setState(() {
                      _selectedItem!.hasShadow = val;
                    });
                  },
                ),
              ],
            ),
          ),

          if (_selectedItem!.isMemeStyle) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  const Text(
                    'Outline: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Slider(
                      value: _selectedItem!.outlineWidth,
                      min: 1.0,
                      max: 12.0,
                      divisions: 11,
                      onChanged: (val) {
                        setState(() {
                          _selectedItem!.outlineWidth = val;
                        });
                      },
                    ),
                  ),
                  Text(
                    '${_selectedItem!.outlineWidth.toInt()} px',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

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
