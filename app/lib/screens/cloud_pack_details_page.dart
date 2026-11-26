import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_stickers_injector/whatsapp_stickers.dart';
import '../models/cloud_models.dart';
import '../models/cloud_provider.dart';
import '../theme.dart';
import '../widgets/mewmer_toast.dart';

class CloudPackDetailsPage extends StatefulWidget {
  final String packId;

  const CloudPackDetailsPage({super.key, required this.packId});

  @override
  State<CloudPackDetailsPage> createState() => _CloudPackDetailsPageState();
}

class _CloudPackDetailsPageState extends State<CloudPackDetailsPage> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    try {
      await context.read<CloudProvider>().fetchPackDetails(widget.packId);
    } catch (e) {
      if (!mounted) return;
      MewmerToast.error(context, 'Failed to load pack: $e');
    }
  }

  Future<void> _exportToWhatsApp(CloudProvider cloud, CloudPack pack) async {
    if (_isExporting) return;

    if (pack.stickers.length < 3) {
      MewmerToast.warning(
        context,
        'Need ${3 - pack.stickers.length} more stickers to add to WhatsApp (min 3)!',
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final localStickers = <({String path, List<String> emojis})>[];
      for (final sticker in pack.stickers) {
        final localPath = cloud.localStickerPath(sticker.id);
        if (localPath == null || !File(localPath).existsSync()) {
          throw 'Sticker media is still downloading. Pull to refresh and try again.';
        }
        localStickers.add((
          path: localPath,
          emojis: sticker.emojis.isEmpty ? const ['✨'] : sticker.emojis,
        ));
      }

      String? trayPath = cloud.localTrayPath(pack.id);
      if (trayPath == null || !File(trayPath).existsSync()) {
        final tempDir = await getTemporaryDirectory();
        final firstBytes = await File(localStickers.first.path).readAsBytes();
        final decoded = img.decodeImage(firstBytes);
        if (decoded == null) {
          throw 'Could not decode sticker for tray icon';
        }
        final firstFrame = decoded.numFrames > 1 ? decoded.frames[0] : decoded;
        final staticFrame = img.Image(
          width: firstFrame.width,
          height: firstFrame.height,
          numChannels: 4,
        );
        img.compositeImage(staticFrame, firstFrame);
        final trayResized = img.copyResize(staticFrame, width: 96, height: 96);
        final trayBytes = Uint8List.fromList(img.encodePng(trayResized));
        final trayFile = File(
          '${tempDir.path}/cloud_tray_${pack.id}_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await trayFile.writeAsBytes(trayBytes);
        trayPath = trayFile.path;
      }

      final whatsappPack = WhatsappStickers(
        identifier: 'cloud_${pack.id}',
        name: pack.title,
        publisher: pack.publisher,
        trayImageFileName: WhatsappStickerImage.fromFile(trayPath),
        animatedStickerPack: pack.isAnimated,
        publisherWebsite: 'https://mewmer.com',
        privacyPolicyWebsite: 'https://mewmer.com/privacy',
        licenseAgreementWebsite: 'https://mewmer.com/license',
      );

      for (final item in localStickers) {
        whatsappPack.addSticker(
          WhatsappStickerImage.fromFile(item.path),
          item.emojis,
        );
      }

      await whatsappPack.sendToWhatsApp();

      if (!mounted) return;
      MewmerToast.success(context, 'Pack added to WhatsApp!');
    } catch (e) {
      if (!mounted) return;
      MewmerToast.error(context, 'Export Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _deleteSticker(CloudProvider cloud, CloudSticker sticker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cloud Sticker'),
        content: const Text('Remove this sticker from your cloud pack?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: MewmerTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: MewmerTheme.rose),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await cloud.deleteSticker(widget.packId, sticker.id);
      if (!mounted) return;
      MewmerToast.info(context, 'Sticker deleted from cloud');
    } catch (e) {
      if (!mounted) return;
      MewmerToast.error(context, 'Delete failed: $e');
    }
  }

  Future<void> _deletePack(CloudProvider cloud) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cloud Pack'),
        content: const Text('Permanently delete this cloud pack and all its stickers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: MewmerTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: MewmerTheme.rose),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await cloud.deletePack(widget.packId);
      if (!mounted) return;
      Navigator.pop(context);
      MewmerToast.info(context, 'Cloud pack deleted');
    } catch (e) {
      if (!mounted) return;
      MewmerToast.error(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudProvider>();
    final pack = cloud.packDetail(widget.packId) ??
        cloud.packs.where((p) => p.id == widget.packId).firstOrNull;

    if (pack == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cloud Pack')),
        body: const Center(
          child: CircularProgressIndicator(color: MewmerTheme.brandViolet),
        ),
      );
    }

    final stickers = pack.stickers;
    final canExport = stickers.length >= 3;

    return Scaffold(
      backgroundColor: MewmerTheme.background,
      appBar: AppBar(
        title: Text(
          pack.title,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined, color: MewmerTheme.muted),
            tooltip: 'Delete Cloud Pack',
            onPressed: () => _deletePack(cloud),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MewmerTheme.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MewmerTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                                  color: pack.isAnimated
                                      ? MewmerTheme.brandViolet.withValues(alpha: 0.2)
                                      : MewmerTheme.whatsappGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  pack.typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: pack.isAnimated
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
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (canExport ? MewmerTheme.whatsappGreen : MewmerTheme.amber)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (canExport ? MewmerTheme.whatsappGreen : MewmerTheme.amber)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          canExport ? 'Ready for WhatsApp' : 'Need ${3 - stickers.length} more',
                          style: TextStyle(
                            color: canExport ? MewmerTheme.whatsappGreen : MewmerTheme.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: MewmerTheme.brandViolet,
                  child: stickers.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 48),
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 52,
                              color: MewmerTheme.muted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              cloud.isSyncing ? 'Loading stickers...' : 'No stickers yet',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: MewmerTheme.textPrimary,
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                          itemCount: stickers.length,
                          itemBuilder: (context, index) {
                            final sticker = stickers[index];
                            final localPath = cloud.localStickerPath(sticker.id);
                            return GestureDetector(
                              onLongPress: () => _deleteSticker(cloud, sticker),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: MewmerTheme.cardSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: MewmerTheme.border),
                                ),
                                child: localPath != null && File(localPath).existsSync()
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(13),
                                        child: Image.file(
                                          File(localPath),
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: MewmerTheme.brandViolet,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              if (stickers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: const BoxDecoration(
                    color: MewmerTheme.cardSurface,
                    border: Border(top: BorderSide(color: MewmerTheme.border)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: canExport && !_isExporting
                          ? () => _exportToWhatsApp(cloud, pack)
                          : null,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        canExport ? 'Add to WhatsApp' : 'Add ${3 - stickers.length} more stickers',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canExport
                            ? MewmerTheme.whatsappGreen
                            : MewmerTheme.cardHover,
                        foregroundColor: Colors.white,
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
                child: CircularProgressIndicator(color: MewmerTheme.brandViolet),
              ),
            ),
        ],
      ),
    );
  }
}
