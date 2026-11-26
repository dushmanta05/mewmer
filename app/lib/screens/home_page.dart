import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_stickers_injector/whatsapp_stickers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'all_packs_page.dart';
import 'login_page.dart';
import 'meme_editor_page.dart';
import 'pack_details_page.dart';
import 'profile_page.dart';
import '../models/cloud_provider.dart';
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
    bool isAnimated = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            title: const Text(
              'Create Sticker Pack',
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
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Pack Name',
                      hintText: 'Mewmer Cat',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pack Type',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: MewmerTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isAnimated = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: !isAnimated
                                  ? MewmerTheme.whatsappGreen.withValues(alpha: 0.2)
                                  : MewmerTheme.cardSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isAnimated
                                    ? MewmerTheme.whatsappGreen
                                    : MewmerTheme.border,
                                width: !isAnimated ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 22,
                                  color: !isAnimated
                                      ? MewmerTheme.whatsappGreen
                                      : MewmerTheme.textMuted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Static',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: !isAnimated
                                        ? MewmerTheme.whatsappGreen
                                        : MewmerTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => isAnimated = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isAnimated
                                  ? MewmerTheme.brandViolet.withValues(alpha: 0.2)
                                  : MewmerTheme.cardSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isAnimated
                                    ? MewmerTheme.brandViolet
                                    : MewmerTheme.border,
                                width: isAnimated ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.animation,
                                  size: 22,
                                  color: isAnimated
                                      ? MewmerTheme.brandViolet
                                      : MewmerTheme.textMuted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Animated',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isAnimated
                                        ? MewmerTheme.brandViolet
                                        : MewmerTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Packs must be all static or all animated.',
                    style: TextStyle(
                      fontSize: 11,
                      color: MewmerTheme.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
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
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    await provider.createPack(name, isAnimated: isAnimated);
                    if (!context.mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${isAnimated ? "Animated" : "Static"} pack "$name" created!'),
                        backgroundColor: MewmerTheme.whatsappGreen,
                      ),
                    );
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
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

  void _showNotLoggedInModal(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: const Text(
            'Not Signed In',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          content: const SizedBox(
            width: 360,
            child: Text(
              'Sign in to sync your sticker packs to the cloud.',
              style: TextStyle(fontSize: 13, color: MewmerTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: const Text(
                'Account',
                style: TextStyle(color: MewmerTheme.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final loggedIn = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                if (loggedIn == true && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                }
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stickerProvider = context.watch<StickerProvider>();
    final cloudProvider = context.watch<CloudProvider>();
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
                      IconButton(
                        icon: Icon(
                          Icons.account_circle,
                          color: cloudProvider.isAuthenticated
                              ? MewmerTheme.whatsappGreen
                              : MewmerTheme.brandViolet,
                          size: 28,
                        ),
                        tooltip: 'Account',
                        onPressed: () {
                          if (cloudProvider.isAuthenticated) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfilePage(),
                              ),
                            );
                          } else {
                            _showNotLoggedInModal(context);
                          }
                        },
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
                          _buildCreateStickerCard(context, isBusy),
                          const SizedBox(height: 16),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: packs.take(4).map((pack) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
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
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: MewmerTheme.cardSurface,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: MewmerTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 56,
                                              height: 56,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: _buildPackPreview(pack.stickerPaths),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    pack.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                      color: MewmerTheme.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
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
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${pack.stickerPaths.length} stickers',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: MewmerTheme.textMuted,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (pack.stickerPaths.length >= 3)
                                              IconButton(
                                                onPressed: () => _exportToWhatsApp(context, pack),
                                                icon: const Icon(
                                                  Icons.send_rounded,
                                                  size: 18,
                                                  color: MewmerTheme.whatsappGreen,
                                                ),
                                                tooltip: 'Add to WhatsApp',
                                              )
                                            else
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: MewmerTheme.textMuted,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          if (packs.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AllPacksPage(),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: MewmerTheme.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    'View All',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: MewmerTheme.textPrimary,
                                    ),
                                  ),
                                ),
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
                              height: 104,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: recentStickers.length,
                                itemBuilder: (context, index) {
                                  final sticker = recentStickers[index];
                                  final file = File(sticker.imagePath);

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MemeEditorPage(imageFile: file),
                                        ),
                                      );
                                    },
                                    onLongPress: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        barrierColor: Colors.black.withValues(alpha: 0.55),
                                        builder: (context) => BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                          child: AlertDialog(
                                            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                            title: const Text(
                                              'Delete Sticker',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                            ),
                                            content: const Text(
                                              'Delete this sticker permanently from storage and all packs?',
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
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      if (confirm == true) {
                                        await stickerProvider.deleteRecentSticker(sticker.imagePath);
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      width: 96,
                                      height: 96,
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: MewmerTheme.cardSurface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: MewmerTheme.border),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          file,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],
                          const SizedBox(height: 12),
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

  Widget _buildCreateStickerCard(BuildContext context, bool isBusy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          color: MewmerTheme.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: MewmerTheme.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MewmerTheme.brandViolet.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 32,
                color: MewmerTheme.brandViolet,
              ),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MemeEditorPage(),
                            ),
                          );
                        },
                  icon: const Icon(Icons.gif_box_rounded, size: 18),
                  label: const Text('Open Studio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MewmerTheme.brandViolet,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 18, color: MewmerTheme.textPrimary),
                  label: const Text('From Gallery', style: TextStyle(color: MewmerTheme.textPrimary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: MewmerTheme.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
