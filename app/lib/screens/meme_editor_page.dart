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
import '../widgets/cat_branding.dart';
import '../widgets/mewmer_toast.dart';
import '../theme.dart';
import 'gallery_picker_page.dart';

class MemeEditorPage extends StatefulWidget {
  final File? imageFile;
  final String? initialPackId;
  const MemeEditorPage({super.key, this.imageFile, this.initialPackId});

  @override
  State<MemeEditorPage> createState() => _MemeEditorPageState();
}

class _MemeEditorPageState extends State<MemeEditorPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final List<TextItem> _textItems = [];
  TextItem? _selectedItem;
  bool _useTransparentPadding = true;
  bool _hideBackgroundForCapture = false;
  bool _isCapturingStatic = false;
  File? _currentImageFile;

  double _imageScale = 1.0;
  Offset _imageOffset = Offset.zero;
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  double _canvasDisplaySize = 340.0;

  @override
  void initState() {
    super.initState();
    _currentImageFile = widget.imageFile;
  }

  Future<void> _handleKeyboardContent(KeyboardInsertedContent content) async {
    if (content.data == null || content.data!.isEmpty) return;

    final tempDir = await getTemporaryDirectory();
    final mime = content.mimeType.toLowerCase();
    final ext = mime.contains('gif')
        ? 'gif'
        : (mime.contains('webp') ? 'webp' : (mime.contains('png') ? 'png' : 'jpg'));
    final file = File('${tempDir.path}/keyboard_insert_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(content.data!);

    setState(() {
      _currentImageFile = file;
      _imageScale = 1.0;
      _imageOffset = Offset.zero;
    });

    if (mounted) {
      MewmerToast.success(
        context,
        'Inserted ${ext.toUpperCase()} from keyboard!',
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final File? file = await Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (_) => const GalleryPickerPage()),
      );
      if (file != null && mounted) {
        setState(() {
          _currentImageFile = file;
          _imageScale = 1.0;
          _imageOffset = Offset.zero;
        });
      }
    } catch (e) {
      if (mounted) {
        MewmerToast.error(context, 'Error picking image: $e');
      }
    }
  }

  void _showKeyboardGifModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MewmerTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: MewmerTheme.border),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'GIF',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: MewmerTheme.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    style: TextButton.styleFrom(
                      backgroundColor: MewmerTheme.brandViolet.withValues(alpha: 0.14),
                      foregroundColor: MewmerTheme.brandViolet,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Open your keyboard\'s GIF tab and tap any animation.',
                style: TextStyle(
                  fontSize: 13,
                  color: MewmerTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                autofocus: true,
                style: const TextStyle(color: MewmerTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Choose a GIF',
                  prefixIcon: Icon(Icons.gif_box_rounded, color: MewmerTheme.brandViolet),
                ),
                contentInsertionConfiguration: ContentInsertionConfiguration(
                  allowedMimeTypes: const <String>[
                    'image/gif',
                    'image/webp',
                    'image/png',
                    'image/jpeg',
                  ],
                  onContentInserted: (data) {
                    Navigator.pop(bottomSheetContext);
                    _handleKeyboardContent(data);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  final List<Color> _colors = [
    Colors.white,
    const Color(0xFF9CA3AF),
    Colors.black,
    MewmerTheme.brandViolet,
    MewmerTheme.whatsappGreen,
    MewmerTheme.amber,
    MewmerTheme.rose,
    const Color(0xFF38BDF8),
  ];

  final List<TextStyle> _fonts = [
    GoogleFonts.anton(),
    GoogleFonts.poppins(),
    GoogleFonts.caveat(),
  ];

  void _addText() {
    final newItem = TextItem(
      text: 'mewmer.com',
      position: const Offset(100, 100),
      color: Colors.white,
      fontStyle: _fonts[2],
      fontSize: 30.0,
      isMemeStyle: false,
      useCaps: false,
    );
    setState(() {
      _textItems.add(newItem);
      _selectedItem = newItem;
    });
  }

  img.Image _processFrame(img.Image frame, img.Image textOverlay) {
    final int w = frame.width;
    final int h = frame.height;

    double fitWidth = 512;
    double fitHeight = 512;

    if (w > h) {
      fitHeight = 512.0 * h / w;
    } else {
      fitWidth = 512.0 * w / h;
    }

    final int targetWidth = (fitWidth * _imageScale).round().clamp(1, 4096);
    final int targetHeight = (fitHeight * _imageScale).round().clamp(1, 4096);

    final img.Image resizedFrame = img.copyResize(
      frame,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    final img.Image baseImage = img.Image(
      width: 512,
      height: 512,
      numChannels: 4,
    );

    if (!_useTransparentPadding) {
      final img.Image bg = img.copyResize(
        frame,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.linear,
      );
      img.gaussianBlur(bg, radius: 8);
      img.compositeImage(baseImage, bg);

      final darkOverlay = img.Image(width: 512, height: 512, numChannels: 4);
      img.fill(darkOverlay, color: img.ColorRgba8(0, 0, 0, 60));
      img.compositeImage(baseImage, darkOverlay);
    } else {
      img.fill(baseImage, color: img.ColorRgba8(0, 0, 0, 0));
    }

    final double scaleFactor = 512.0 / (_canvasDisplaySize > 0 ? _canvasDisplaySize : 512.0);
    final double finalOffsetX = (512 - targetWidth) / 2 + (_imageOffset.dx * scaleFactor);
    final double finalOffsetY = (512 - targetHeight) / 2 + (_imageOffset.dy * scaleFactor);

    int destX = finalOffsetX.round();
    int destY = finalOffsetY.round();
    int srcX = 0;
    int srcY = 0;
    int srcW = targetWidth;
    int srcH = targetHeight;

    if (destX < 0) {
      srcX = -destX;
      srcW = (srcW - srcX).clamp(0, targetWidth);
      destX = 0;
    }
    if (destY < 0) {
      srcY = -destY;
      srcH = (srcH - srcY).clamp(0, targetHeight);
      destY = 0;
    }
    if (destX + srcW > 512) {
      srcW = (512 - destX).clamp(0, targetWidth);
    }
    if (destY + srcH > 512) {
      srcH = (512 - destY).clamp(0, targetHeight);
    }

    if (srcW > 0 && srcH > 0) {
      img.compositeImage(
        baseImage,
        resizedFrame,
        dstX: destX,
        dstY: destY,
        srcX: srcX,
        srcY: srcY,
        srcW: srcW,
        srcH: srcH,
      );
    }

    img.compositeImage(baseImage, textOverlay);

    return baseImage;
  }

  Future<void> _captureSticker() async {
    if (_currentImageFile == null) {
      MewmerToast.warning(context, 'Please add an image or GIF first!');
      return;
    }

    setState(() => _selectedItem = null);
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final Uint8List sourceBytes = await _currentImageFile!.readAsBytes();
      if (!mounted) return;
      final img.Image? decodedSource = img.decodeImage(sourceBytes);
      final bool isAnimated =
          decodedSource != null && decodedSource.numFrames > 1;
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
          final Uint8List? textOverlayPngBytes = await _screenshotController
              .capture();
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

          final List<Uint8List> processedPngFrames = [];
          final List<int> frameDurations = [];

          int step = 1;
          if (decodedSource.numFrames > 20) {
            step = (decodedSource.numFrames / 20).ceil();
          }

          int accumulatedDuration = 0;
          for (int i = 0; i < decodedSource.frames.length; i += step) {
            final frame = decodedSource.frames[i];
            final duration = frame.frameDuration > 0
                ? frame.frameDuration
                : 100;

            if (accumulatedDuration + duration * step > 3000) {
              break;
            }

            final img.Image processedFrame = _processFrame(frame, textOverlay);
            processedPngFrames.add(
              Uint8List.fromList(img.encodePng(processedFrame)),
            );
            frameDurations.add(duration * step);
            accumulatedDuration += duration * step;

            if (processedPngFrames.length >= 20) {
              break;
            }
          }

          webpBytes = Uint8List(0);
          for (final quality in [45, 30, 18, 10]) {
            final List<Uint8List> frameWebPs = [];
            for (final pngBytes in processedPngFrames) {
              final Uint8List webpFrameBytes =
                  await FlutterImageCompress.compressWithList(
                    pngBytes,
                    format: CompressFormat.webp,
                    quality: quality,
                  );
              frameWebPs.add(webpFrameBytes);
            }
            webpBytes = WebPMuxer.assembleAnimatedWebP(
              frameWebPs,
              frameDurations,
            );
            if (webpBytes.length < 500 * 1024) {
              break;
            }
          }

          if (mounted) {
            Navigator.pop(context);
          }

          if (webpBytes.length >= 500 * 1024) {
            if (mounted) {
              final kb = (webpBytes.length / 1024).toStringAsFixed(0);
              MewmerToast.error(
                context,
                'Animated sticker is $kb KB (max 500 KB). Pick a shorter or simpler GIF.',
              );
            }
            return;
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context);
          }
          rethrow;
        }
      } else {
        setState(() {
          _isCapturingStatic = true;
        });
        await Future.delayed(const Duration(milliseconds: 50));
        final Uint8List? imageBytes = await _screenshotController.capture();
        setState(() {
          _isCapturingStatic = false;
        });
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

        webpBytes = Uint8List(0);
        for (final quality in [75, 55, 35, 20]) {
          webpBytes = await FlutterImageCompress.compressWithList(
            rawResizedBytes,
            format: CompressFormat.webp,
            quality: quality,
          );
          if (webpBytes.length < 100 * 1024) {
            break;
          }
        }

        if (webpBytes.length >= 100 * 1024) {
          if (mounted) {
            final kb = (webpBytes.length / 1024).toStringAsFixed(0);
            MewmerToast.error(
              context,
              'Static sticker is $kb KB (max 100 KB). Simplify the image or captions.',
            );
          }
          return;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final String fileName = 's_${DateTime.now().millisecondsSinceEpoch}.webp';
      final stickerFile = File('${tempDir.path}/$fileName');
      await stickerFile.writeAsBytes(webpBytes);

      if (mounted) {
        await _showSavePackDialog(stickerFile.path, isAnimated: isAnimated);
      }
    } catch (e) {
      if (mounted) {
        MewmerToast.error(context, 'Error: $e');
      }
    }
  }

  Future<void> _showSavePackDialog(String tempStickerPath, {required bool isAnimated}) async {
    final stickerProvider = context.read<StickerProvider>();
    final compatiblePacks = stickerProvider.packs.where((pack) => pack.isAnimated == null || pack.isAnimated == isAnimated).toList();

    final hasInitial = widget.initialPackId != null &&
        compatiblePacks.any((p) => p.identifier == widget.initialPackId);
    String? selectedPackId = hasInitial
        ? widget.initialPackId
        : (compatiblePacks.isNotEmpty ? compatiblePacks.first.identifier : null);
    final textController = TextEditingController();
    bool createNew = compatiblePacks.isEmpty;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                title: const Text(
                  'Save to Sticker Pack',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                content: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (compatiblePacks.isNotEmpty) ...[
                      const Text(
                        'Choose an existing pack:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('pack_dropdown_${selectedPackId ?? 'none'}'),
                        isExpanded: true,
                        initialValue: selectedPackId,
                        dropdownColor: MewmerTheme.cardSurface,
                        borderRadius: BorderRadius.circular(14),
                        menuMaxHeight: 280,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: MewmerTheme.textMuted,
                        ),
                        style: const TextStyle(
                          color: MewmerTheme.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: compatiblePacks.map((pack) {
                          final String typeLabel = pack.typeLabel;
                          return DropdownMenuItem<String>(
                            value: pack.identifier,
                            child: Text(
                              '${pack.name} ($typeLabel)',
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
                                if (createNew) {
                                  selectedPackId = null;
                                } else if (compatiblePacks.isNotEmpty) {
                                  selectedPackId = compatiblePacks.first.identifier;
                                }
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
                          hintText: 'Mewmer Cat',
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: MewmerTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final packName = textController.text.trim();
                    if (createNew && packName.isEmpty) {
                      MewmerToast.warning(
                        dialogContext,
                        'Please enter a pack name',
                      );
                      return;
                    }
                    if (!createNew && selectedPackId == null) {
                      MewmerToast.warning(
                        dialogContext,
                        'Please select a pack',
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
                        await stickerProvider.createPack(packName, isAnimated: isAnimated);
                        targetPackId = stickerProvider.packs.first.identifier;
                      } else {
                        targetPackId = selectedPackId!;
                      }

                      await stickerProvider.addStickerToPack(
                        targetPackId,
                        tempStickerPath,
                        isAnimated: isAnimated,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        MewmerToast.success(
                          context,
                          'Sticker saved and added to pack!',
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        MewmerToast.error(
                          context,
                          'Failed to save sticker: $e',
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Studio', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _captureSticker,
              icon: const Icon(
                Icons.save_rounded,
                size: 18,
                color: MewmerTheme.brandViolet,
              ),
              label: const Text(
                'Save',
                style: TextStyle(
                  color: MewmerTheme.brandViolet,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedItem = null),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: MewmerTheme.border, width: 1),
                      ),
                      child: _buildEditorCanvas(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_currentImageFile != null && _selectedItem == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              color: MewmerTheme.background,
              child: Row(
                children: [
                  const Icon(Icons.zoom_out, size: 16, color: MewmerTheme.textMuted),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _imageScale,
                        min: 0.4,
                        max: 3.5,
                        activeColor: MewmerTheme.brandViolet,
                        inactiveColor: MewmerTheme.cardHover,
                        onChanged: (val) {
                          setState(() {
                            _imageScale = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const Icon(Icons.zoom_in, size: 16, color: MewmerTheme.textMuted),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _imageScale = 1.0;
                        _imageOffset = Offset.zero;
                      });
                    },
                    child: const Text('Reset', style: TextStyle(fontSize: 12, color: MewmerTheme.brandViolet)),
                  ),
                ],
              ),
            ),
          if (_selectedItem != null) _buildPropertyPanel(),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: MewmerTheme.cardSurface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(top: BorderSide(color: MewmerTheme.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showKeyboardGifModal,
                    icon: const Icon(Icons.gif_box_rounded, size: 18, color: MewmerTheme.textPrimary),
                    label: const Text('GIF', style: TextStyle(color: MewmerTheme.textPrimary)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: MewmerTheme.cardHover,
                      side: const BorderSide(color: MewmerTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18, color: MewmerTheme.textPrimary),
                    label: const Text('Image', style: TextStyle(color: MewmerTheme.textPrimary)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: MewmerTheme.cardHover,
                      side: const BorderSide(color: MewmerTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addText,
                    icon: const Icon(Icons.title_rounded, size: 18, color: MewmerTheme.textPrimary),
                    label: const Text('Add Text', style: TextStyle(color: MewmerTheme.textPrimary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: MewmerTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _useTransparentPadding = !_useTransparentPadding;
                      });
                    },
                    icon: Icon(
                      _useTransparentPadding
                          ? Icons.grid_on_rounded
                          : Icons.blur_on_rounded,
                      size: 17,
                      color: _useTransparentPadding
                          ? MewmerTheme.brandViolet
                          : MewmerTheme.textMuted,
                    ),
                    label: Text(
                      _useTransparentPadding ? 'Transparent' : 'Blur BG',
                      style: TextStyle(
                        color: _useTransparentPadding
                            ? MewmerTheme.brandViolet
                            : MewmerTheme.textPrimary,
                        fontWeight: _useTransparentPadding
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _useTransparentPadding
                          ? MewmerTheme.brandViolet.withValues(alpha: 0.14)
                          : Colors.transparent,
                      side: BorderSide(
                        color: _useTransparentPadding
                            ? MewmerTheme.brandViolet
                            : MewmerTheme.border,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasDisplaySize = constraints.maxWidth;

        return Screenshot(
          controller: _screenshotController,
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_hideBackgroundForCapture)
                  Container(color: Colors.transparent)
                else if (_currentImageFile == null)
                  Container(
                    color: MewmerTheme.cardSurface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CatLogoMark(size: 44),
                          const SizedBox(height: 12),
                          Text(
                            'Canvas Ready',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: MewmerTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap GIF or Image below to start',
                            style: TextStyle(
                              fontSize: 12,
                              color: MewmerTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (_useTransparentPadding)
                    if (_isCapturingStatic)
                      Container(color: Colors.transparent)
                    else
                      const CheckerboardBackground()
                  else
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_currentImageFile!, fit: BoxFit.cover),
                        BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(color: Colors.black.withValues(alpha: 0.25)),
                        ),
                      ],
                    ),

                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onScaleStart: (details) {
                        setState(() {
                          _selectedItem = null;
                          _startScale = _imageScale;
                          _startOffset = _imageOffset;
                          _startFocalPoint = details.focalPoint;
                        });
                      },
                      onScaleUpdate: (details) {
                        setState(() {
                          _imageScale = (_startScale * details.scale).clamp(0.4, 4.0);
                          final focalDelta = details.focalPoint - _startFocalPoint;
                          _imageOffset = _startOffset + focalDelta;
                        });
                      },
                      child: Transform.translate(
                        offset: _imageOffset,
                        child: Transform.scale(
                          scale: _imageScale,
                          child: Image.file(
                            _currentImageFile!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

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
                    onContentInserted: _handleKeyboardContent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPropertyPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: MewmerTheme.cardSurface,
        border: Border(top: BorderSide(color: MewmerTheme.border)),
      ),
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

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _colors.map((color) {
                final isSelected =
                    _selectedItem!.color.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedItem!.color = color),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: _selectedItem!.opacity),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? MewmerTheme.brandViolet
                            : MewmerTheme.border,
                        width: isSelected ? 2.5 : 1.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Text(
                  'Opacity: ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Slider(
                    value: _selectedItem!.opacity,
                    min: 0.2,
                    max: 1.0,
                    divisions: 16,
                    onChanged: (val) {
                      setState(() {
                        _selectedItem!.opacity = val;
                      });
                    },
                  ),
                ),
                Text(
                  '${(_selectedItem!.opacity * 100).round()}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WebPMuxer {
  static Uint8List assembleAnimatedWebP(
    List<Uint8List> frameWebPs,
    List<int> durationsMs,
  ) {
    final List<int> builder = [];

    builder.addAll(utf8Encode('RIFF'));
    builder.addAll([0, 0, 0, 0]);
    builder.addAll(utf8Encode('WEBP'));

    final List<Uint8List> framePayloads = frameWebPs
        .map(extractWebPFramePayload)
        .toList();
    final bool anyHasAlpha = framePayloads.any(_hasAlphaPayload);
    if (anyHasAlpha &&
        framePayloads.isNotEmpty &&
        !_hasAlphaPayload(framePayloads[0]) &&
        _startsWithFourCC(framePayloads[0], 'VP8 ')) {
      framePayloads[0] = _prependOpaqueAlphaChunk(framePayloads[0]);
    }

    builder.addAll(utf8Encode('VP8X'));
    builder.addAll(uint32ToBytes(10));
    builder.add(anyHasAlpha ? 0x12 : 0x02);
    builder.addAll([0, 0, 0]);
    builder.addAll(uint24ToBytes(511));
    builder.addAll(uint24ToBytes(511));

    builder.addAll(utf8Encode('ANIM'));
    builder.addAll(uint32ToBytes(6));
    builder.addAll([0, 0, 0, 0]);
    builder.addAll(uint16ToBytes(0));

    for (int i = 0; i < framePayloads.length; i++) {
      final durationMs = durationsMs[i];
      final framePayload = framePayloads[i];

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
    final ByteData sizeBytes = ByteData(4)
      ..setUint32(0, fileSize, Endian.little);
    result.setRange(4, 8, sizeBytes.buffer.asUint8List());

    return result;
  }

  static Uint8List extractWebPFramePayload(Uint8List bytes) {
    final List<int> payload = [];
    int offset = 12;

    while (offset < bytes.length) {
      if (offset + 8 > bytes.length) break;
      final String tag = String.fromCharCodes(
        bytes.sublist(offset, offset + 4),
      );

      final int size = ByteData.sublistView(
        bytes,
        offset + 4,
        offset + 8,
      ).getUint32(0, Endian.little);
      final int padding = size % 2 == 1 ? 1 : 0;
      final int totalChunkSize = 8 + size + padding;

      if (offset + 8 + size > bytes.length) break;

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

  static const List<int> _opaqueAlphaChunk = [
    65, 76, 80, 72,
    28, 0, 0, 0,
    1, 7, 80, 255, 136, 8, 8, 4, 146, 253, 189, 103, 40, 162, 255, 25,
    255, 249, 207, 127, 254, 243, 159, 255, 252, 231, 255, 0,
  ];

  static bool _startsWithFourCC(Uint8List payload, String fourCC) {
    if (payload.length < 4) return false;
    return String.fromCharCodes(payload.sublist(0, 4)) == fourCC;
  }

  static bool _hasAlphaPayload(Uint8List payload) {
    return _startsWithFourCC(payload, 'ALPH') ||
        _startsWithFourCC(payload, 'VP8L');
  }

  static Uint8List _prependOpaqueAlphaChunk(Uint8List vp8Payload) {
    final result = Uint8List(_opaqueAlphaChunk.length + vp8Payload.length);
    result.setRange(0, _opaqueAlphaChunk.length, _opaqueAlphaChunk);
    result.setRange(_opaqueAlphaChunk.length, result.length, vp8Payload);
    return result;
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

class CheckerboardBackground extends StatelessWidget {
  const CheckerboardBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _CheckerboardPainter(),
      child: SizedBox.expand(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double tileSize = 14.0;
    final paint1 = Paint()..color = const Color(0xFF111827);
    final paint2 = Paint()..color = const Color(0xFF1E293B);

    final int cols = (size.width / tileSize).ceil();
    final int rows = (size.height / tileSize).ceil();

    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        final paint = (i + j) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(
          Rect.fromLTWH(i * tileSize, j * tileSize, tileSize, tileSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
