import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_stickers_injector/whatsapp_stickers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'meme_editor_page.dart';
import 'pack_details_page.dart';
import '../models/sticker_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  bool _isExporting = false;
  bool _isPickingImage = false;

  Future<void> _pickImage() async {
    if (_isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemeEditorPage(imageFile: File(image.path)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Picker Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _showCreatePackDialog(BuildContext context) {
    final provider = context.read<StickerProvider>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Sticker Pack'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter pack name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await provider.createPack(name);
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pack "$name" created successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToWhatsApp(BuildContext context, StickerPack pack) async {
    if (_isExporting) return;

    if (pack.stickerPaths.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Need ${3 - pack.stickerPaths.length} more stickers to create a pack (min 3)!',
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

      var stickerPack = WhatsappStickers(
        identifier: pack.identifier,
        name: pack.name,
        publisher: pack.publisher,
        trayImageFileName: WhatsappStickerImage.fromFile(trayFile.path),
        publisherWebsite: 'https://mewmer.com',
        privacyPolicyWebsite: 'https://mewmer.com/privacy',
        licenseAgreementWebsite: 'https://mewmer.com/license',
        animatedStickerPack: isAnimated,
      );

      for (var path in pack.stickerPaths) {
        stickerPack.addSticker(WhatsappStickerImage.fromFile(path), ['✨']);
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

  Widget _buildPackPreview(List<String> paths) {
    if (paths.isEmpty) {
      return Container(
        color: Colors.white10,
        child: const Center(
          child: Icon(
            Icons.photo_library_outlined,
            color: Colors.white24,
            size: 40,
          ),
        ),
      );
    }

    if (paths.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(paths[0]),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    final displayCount = paths.length.clamp(0, 4);
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: displayCount,
      itemBuilder: (context, idx) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(File(paths[idx]), fit: BoxFit.cover),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stickerProvider = context.watch<StickerProvider>();
    final recentStickers = stickerProvider.recentStickers;
    final packs = stickerProvider.packs;
    final isBusy = _isExporting || _isPickingImage || stickerProvider.isLoading;

    return Scaffold(
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
                  ).colorScheme.primaryContainer.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.deepPurpleAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'mewmer',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.create_new_folder,
                            color: Colors.deepPurpleAccent,
                          ),
                          tooltip: 'Create New Pack',
                          onPressed: () => _showCreatePackDialog(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (stickerProvider.isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sticker Packs',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showCreatePackDialog(context),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text(
                                      'Add Pack',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (packs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.folder_open,
                                        size: 48,
                                        color: Colors.white24,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No Sticker Packs Created Yet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Create a pack to organize your custom stickers.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 210,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: packs.length,
                                  itemBuilder: (context, index) {
                                    final pack = packs[index];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PackDetailsPage(
                                                  packIdentifier:
                                                      pack.identifier,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        width: 150,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.white10,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Container(
                                                margin: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black26,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: _buildPackPreview(
                                                  pack.stickerPaths,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    pack.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${pack.stickerPaths.length} stickers',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                      if (pack
                                                              .stickerPaths
                                                              .length >=
                                                          3)
                                                        GestureDetector(
                                                          onTap: () =>
                                                              _exportToWhatsApp(
                                                                context,
                                                                pack,
                                                              ),
                                                          child: const Icon(
                                                            Icons
                                                                .share_arrival_time_outlined,
                                                            size: 16,
                                                            color: Colors
                                                                .greenAccent,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 28),

                            if (recentStickers.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  'Recent Creations',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: recentStickers.length,
                                  itemBuilder: (context, index) {
                                    final sticker = recentStickers[index];
                                    final file = File(sticker.imagePath);

                                    return GestureDetector(
                                      onLongPress: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Sticker'),
                                            content: const Text(
                                              'Delete this sticker permanently from storage and all packs?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await stickerProvider
                                              .deleteRecentSticker(
                                                sticker.imagePath,
                                              );
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        width: 100,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          image: DecorationImage(
                                            image: FileImage(file),
                                            fit: BoxFit.cover,
                                          ),
                                          border: Border.all(
                                            color: Colors.white10,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],

                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_photo_alternate,
                                    size: 64,
                                    color: Colors.white24,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Start your next meme',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: isBusy ? null : _pickImage,
                                    icon: const Icon(Icons.add),
                                    label: const Text('New Sticker'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isBusy)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
