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
  bool _useTransparentPadding = true;
  bool _hideBackgroundForCapture = false;

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

  img.Image _processFrame(img.Image frame, img.Image textOverlay) {
    final int w = frame.width;
    final int h = frame.height;
    
    int newWidth = 512;
    int newHeight = 512;
    int xOffset = 0;
    int yOffset = 0;
    
    if (w > h) {
      newWidth = 512;
      newHeight = (h * 512 / w).round();
      yOffset = (512 - newHeight) ~/ 2;
    } else if (h > w) {
      newHeight = 512;
      newWidth = (w * 512 / h).round();
      xOffset = (512 - newWidth) ~/ 2;
    }
    
    final img.Image resizedFrame = img.copyResize(
      frame,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
    
    final img.Image baseImage = img.Image(width: 512, height: 512, numChannels: 4);
    
    if (!_useTransparentPadding) {
      final img.Image bg = img.copyResize(
        frame,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );
      img.gaussianBlur(bg, radius: 5);
      
      img.compositeImage(baseImage, bg);
      final darkOverlay = img.Image(width: 512, height: 512, numChannels: 4);
      img.fill(darkOverlay, color: img.ColorRgba8(0, 0, 0, 50));
      img.compositeImage(baseImage, darkOverlay);
    } else {
      img.fill(baseImage, color: img.ColorRgba8(0, 0, 0, 0));
    }
    
    img.compositeImage(baseImage, resizedFrame, dstX: xOffset, dstY: yOffset);
    img.compositeImage(baseImage, textOverlay);
    
    return baseImage;
  }

  Future<void> _captureSticker() async {
    setState(() => _selectedItem = null);
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final Uint8List sourceBytes = await widget.imageFile.readAsBytes();
      if (!mounted) return;
      final img.Image? decodedSource = img.decodeImage(sourceBytes);
      final bool isAnimated = decodedSource != null && decodedSource.numFrames > 1;
      Uint8List webpBytes;

      if (isAnimated) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing animation frames...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          setState(() {
            _hideBackgroundForCapture = true;
          });
          await Future.delayed(const Duration(milliseconds: 100));
          final Uint8List? textOverlayPngBytes = await _screenshotController.capture();
          setState(() {
            _hideBackgroundForCapture = false;
          });

          if (textOverlayPngBytes == null) {
            if (mounted) Navigator.pop(context);
            return;
          }

          final img.Image? textOverlay = img.decodePng(textOverlayPngBytes);
          if (textOverlay == null) {
            if (mounted) Navigator.pop(context);
            return;
          }

          final List<Uint8List> frameWebPs = [];
          final List<int> frameDurations = [];

          int step = 1;
          if (decodedSource.numFrames > 20) {
            step = (decodedSource.numFrames / 20).ceil();
          }

          int accumulatedDuration = 0;
          for (int i = 0; i < decodedSource.frames.length; i += step) {
            final frame = decodedSource.frames[i];
            final duration = frame.frameDuration > 0 ? frame.frameDuration : 100;

            if (accumulatedDuration + duration * step > 3000) {
              break;
            }

            final img.Image processedFrame = _processFrame(frame, textOverlay);

            final Uint8List pngBytes = Uint8List.fromList(img.encodePng(processedFrame));
            final Uint8List webpFrameBytes = await FlutterImageCompress.compressWithList(
              pngBytes,
              format: CompressFormat.webp,
              quality: 30,
            );

            frameWebPs.add(webpFrameBytes);
            frameDurations.add(duration * step);
            accumulatedDuration += duration * step;

            if (frameWebPs.length >= 20) {
              break;
            }
          }

          webpBytes = WebPMuxer.assembleAnimatedWebP(frameWebPs, frameDurations);
          
          if (mounted) {
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context);
          }
          rethrow;
        }
      } else {
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

        webpBytes = await FlutterImageCompress.compressWithList(
          rawResizedBytes,
          format: CompressFormat.webp,
          quality: 40,
        );
      }

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
                ChoiceChip(
                  avatar: Icon(
                    _useTransparentPadding ? Icons.check_box_outlined : Icons.blur_on,
                    size: 18,
                  ),
                  label: const Text('Transparent Padding'),
                  selected: _useTransparentPadding,
                  onSelected: (val) {
                    setState(() {
                      _useTransparentPadding = val;
                    });
                  },
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
          if (_hideBackgroundForCapture)
            Container(color: Colors.transparent)
          else if (!_useTransparentPadding) ...[
            Image.file(widget.imageFile, fit: BoxFit.cover),
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.2)),
            ),
          ] else
            Container(color: Colors.transparent),
          if (!_hideBackgroundForCapture)
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

class WebPMuxer {
  static Uint8List assembleAnimatedWebP(List<Uint8List> frameWebPs, List<int> durationsMs) {
    final List<int> builder = [];

    builder.addAll(utf8Encode('RIFF'));
    builder.addAll([0, 0, 0, 0]);
    builder.addAll(utf8Encode('WEBP'));

    builder.addAll(utf8Encode('VP8X'));
    builder.addAll(uint32ToBytes(10));
    builder.add(0x12);
    builder.addAll([0, 0, 0]);
    builder.addAll(uint24ToBytes(511));
    builder.addAll(uint24ToBytes(511));

    builder.addAll(utf8Encode('ANIM'));
    builder.addAll(uint32ToBytes(6));
    builder.addAll([0, 0, 0, 0]);
    builder.addAll(uint16ToBytes(0));

    for (int i = 0; i < frameWebPs.length; i++) {
      final frameBytes = frameWebPs[i];
      final durationMs = durationsMs[i];
      final framePayload = extractWebPFramePayload(frameBytes);

      final int anmfPayloadSize = 16 + framePayload.length;
      
      builder.addAll(utf8Encode('ANMF'));
      builder.addAll(uint32ToBytes(anmfPayloadSize));
      builder.addAll(uint24ToBytes(0));
      builder.addAll(uint24ToBytes(0));
      builder.addAll(uint24ToBytes(511));
      builder.addAll(uint24ToBytes(511));
      builder.addAll(uint24ToBytes(durationMs));
      builder.add(0x03);

      builder.addAll(framePayload);
      
      if (anmfPayloadSize % 2 == 1) {
        builder.add(0);
      }
    }

    final Uint8List result = Uint8List.fromList(builder);
    final int fileSize = result.length - 8;
    final ByteData sizeBytes = ByteData(4)..setUint32(0, fileSize, Endian.little);
    result.setRange(4, 8, sizeBytes.buffer.asUint8List());

    return result;
  }

  static Uint8List extractWebPFramePayload(Uint8List bytes) {
    final List<int> payload = [];
    int offset = 12;
    
    while (offset < bytes.length) {
      if (offset + 8 > bytes.length) break;
      final String tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      
      final int size = ByteData.sublistView(bytes, offset + 4, offset + 8).getUint32(0, Endian.little);
      final int padding = size % 2 == 1 ? 1 : 0;
      final int totalChunkSize = 8 + size + padding;
      
      if (offset + totalChunkSize > bytes.length) break;

      if (tag == 'VP8 ' || tag == 'VP8L' || tag == 'ALPH') {
        payload.addAll(bytes.sublist(offset, offset + 8 + size));
        if (padding == 1) {
          payload.add(0);
        }
      }
      
      offset += totalChunkSize;
    }
    return Uint8List.fromList(payload);
  }

  static List<int> utf8Encode(String str) => str.codeUnits;

  static List<int> uint32ToBytes(int value) {
    final List<int> bytes = List.filled(4, 0);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    bytes[2] = (value >> 16) & 0xFF;
    bytes[3] = (value >> 24) & 0xFF;
    return bytes;
  }

  static List<int> uint24ToBytes(int value) {
    final List<int> bytes = List.filled(3, 0);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    bytes[2] = (value >> 16) & 0xFF;
    return bytes;
  }

  static List<int> uint16ToBytes(int value) {
    final List<int> bytes = List.filled(2, 0);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    return bytes;
  }
}
