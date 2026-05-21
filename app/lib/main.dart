import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whatsapp_stickers_injector/whatsapp_stickers.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

void main() {
  runApp(const MewmerApp());
}

class MewmerApp extends StatelessWidget {
  const MewmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mewmer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemeEditorPage(imageFile: File(image.path)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 20),
              Text(
                'mewmer',
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create magic stickers',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 60),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Pick Image'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

  Future<void> _exportSticker() async {
    setState(() {
      _selectedItem = null;
    });

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
      final stickerFile = File('${tempDir.path}/sticker.webp');
      await stickerFile.writeAsBytes(webpBytes);

      final Uint8List trayBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 96,
        minHeight: 96,
        format: CompressFormat.png,
        quality: 80,
      );
      final trayFile = File('${tempDir.path}/tray.png');
      await trayFile.writeAsBytes(trayBytes);

      var stickerPack = WhatsappStickers(
        identifier: 'mewmer_pack_${DateTime.now().millisecondsSinceEpoch}',
        name: 'mewmer',
        publisher: 'mewmer.com',
        trayImageFileName: WhatsappStickerImage.fromFile(trayFile.path),
        publisherWebsite: 'https://mewmer.com',
        privacyPolicyWebsite: 'https://mewmer.com/privacy',
        licenseAgreementWebsite: 'https://mewmer.com/license',
      );

      stickerPack.addSticker(WhatsappStickerImage.fromFile(stickerFile.path), [
        '😊',
      ]);
      stickerPack.addSticker(WhatsappStickerImage.fromFile(stickerFile.path), [
        '😎',
      ]);
      stickerPack.addSticker(WhatsappStickerImage.fromFile(stickerFile.path), [
        '🔥',
      ]);

      await stickerPack.sendToWhatsApp();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Meme'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _exportSticker),
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

class TextItem {
  String text;
  Offset position;
  Color color;
  TextStyle fontStyle;
  double scale;
  double rotation;

  TextItem({
    required this.text,
    required this.position,
    required this.color,
    required this.fontStyle,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

class DraggableText extends StatefulWidget {
  final TextItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const DraggableText({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<DraggableText> createState() => _DraggableTextState();
}

class _DraggableTextState extends State<DraggableText> {
  bool _isEditing = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.item.text;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.item.position.dx,
      top: widget.item.position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleUpdate: (details) {
          widget.onTap();
          setState(() {
            if (details.pointerCount == 1) {
              widget.item.position += details.focalPointDelta;
            } else if (details.pointerCount > 1) {
              widget.item.scale *= details.scale;
              widget.item.rotation += details.rotation;
            }
          });
          widget.onUpdate();
        },
        onDoubleTap: () {
          setState(() {
            _isEditing = true;
          });
        },
        onLongPress: widget.onDelete,
        child: Container(
          decoration: BoxDecoration(
            border: widget.isSelected
                ? Border.all(
                    color: Colors.blue.withValues(alpha: 0.5),
                    width: 1,
                  )
                : null,
          ),
          child: Transform.rotate(
            angle: widget.item.rotation,
            child: Transform.scale(
              scale: widget.item.scale,
              child: _isEditing
                  ? IntrinsicWidth(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: widget.item.fontStyle.copyWith(
                          color: widget.item.color,
                          fontSize: 24,
                        ),
                        onSubmitted: (val) {
                          setState(() {
                            widget.item.text = val;
                            _isEditing = false;
                          });
                          widget.onUpdate();
                        },
                      ),
                    )
                  : Text(
                      widget.item.text,
                      style: widget.item.fontStyle.copyWith(
                        color: widget.item.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
