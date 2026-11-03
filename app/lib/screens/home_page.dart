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
import '../widgets/cat_branding.dart';
import '../theme.dart';

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
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: MewmerTheme.textMuted)),
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
                    backgroundColor: MewmerTheme.whatsappGreen,
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
          backgroundColor: MewmerTheme.amber,
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
      );

      for (var path in pack.stickerPaths) {
        stickerPack.addSticker(WhatsappStickerImage.fromFile(path), ['✨']);
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

  Widget _buildPackPreview(List<String> paths) {
    if (paths.isEmpty) {
      return Container(
        color: MewmerTheme.cardHover,
        child: const Center(
          child: Icon(
            Icons.photo_library_outlined,
            color: MewmerTheme.muted,
            size: 32,
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
      backgroundColor: MewmerTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const MewmerBrandHeader(iconSize: 36, fontSize: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: MewmerTheme.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MewmerTheme.border),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            color: MewmerTheme.brandViolet,
                            size: 20,
                          ),
                          tooltip: 'Create New Pack',
                          onPressed: () => _showCreatePackDialog(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (stickerProvider.isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: MewmerTheme.brandViolet),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sticker Packs',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: MewmerTheme.textPrimary,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showCreatePackDialog(context),
                                  icon: const Icon(Icons.add, size: 15, color: MewmerTheme.brandViolet),
                                  label: const Text(
                                    'Add Pack',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: MewmerTheme.brandViolet,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (packs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: MewmerTheme.cardSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: MewmerTheme.border),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        color: MewmerTheme.cardHover,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.folder_open_rounded,
                                        size: 32,
                                        color: MewmerTheme.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No Sticker Packs Yet',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: MewmerTheme.textPrimary,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Create a pack to organize your custom stickers.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: MewmerTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 215,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: packs.length,
                                itemBuilder: (context, index) {
                                  final pack = packs[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PackDetailsPage(
                                            packIdentifier: pack.identifier,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      width: 155,
                                      decoration: BoxDecoration(
                                        color: MewmerTheme.cardSurface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: MewmerTheme.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: MewmerTheme.cardHover,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: _buildPackPreview(pack.stickerPaths),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  pack.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: MewmerTheme.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      '${pack.stickerPaths.length} stickers',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: MewmerTheme.textMuted,
                                                      ),
                                                    ),
                                                    if (pack.stickerPaths.length >= 3)
                                                      GestureDetector(
                                                        onTap: () => _exportToWhatsApp(context, pack),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(4),
                                                          decoration: BoxDecoration(
                                                            color: MewmerTheme.whatsappGreen.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: const Icon(
                                                            Icons.send_rounded,
                                                            size: 13,
                                                            color: MewmerTheme.whatsappGreen,
                                                          ),
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
                          const SizedBox(height: 24),

                          if (recentStickers.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Recent Creations',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: MewmerTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 110,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel', style: TextStyle(color: MewmerTheme.textMuted)),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: MewmerTheme.rose,
                                              ),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await stickerProvider.deleteRecentSticker(sticker.imagePath);
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      width: 95,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        image: DecorationImage(
                                          image: FileImage(file),
                                          fit: BoxFit.cover,
                                        ),
                                        border: Border.all(color: MewmerTheme.border),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                              decoration: BoxDecoration(
                                color: MewmerTheme.cardSurface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: MewmerTheme.border),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: MewmerTheme.brandViolet.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 36,
                                      color: MewmerTheme.brandViolet,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Create New Sticker',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: MewmerTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Import photos or GIFs and caption them.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: MewmerTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: isBusy ? null : _pickImage,
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Open Studio'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MewmerTheme.brandViolet,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isBusy)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: MewmerTheme.brandViolet),
              ),
            ),
        ],
      ),
    );
  }
}
