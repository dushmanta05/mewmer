import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:whatsapp_stickers_injector/whatsapp_stickers.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'meme_editor_page.dart';
import '../models/sticker_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _packNameController = TextEditingController();

  @override
  void dispose() {
    _packNameController.dispose();
    super.dispose();
  }

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

  void _showPackNameDialog(BuildContext context) {
    final provider = context.read<StickerProvider>();
    _packNameController.text = provider.currentPackName;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pack Name'),
        content: TextField(
          controller: _packNameController,
          decoration: const InputDecoration(hintText: 'Enter pack name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.setPackName(_packNameController.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToWhatsApp(BuildContext context) async {
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
      
      final firstStickerBytes = await File(packStickers[0].imagePath).readAsBytes();
      final Uint8List trayBytes = await FlutterImageCompress.compressWithList(
        firstStickerBytes,
        minWidth: 96,
        minHeight: 96,
        format: CompressFormat.png,
        quality: 80,
      );
      final trayFile = File('${tempDir.path}/home_tray_${DateTime.now().millisecondsSinceEpoch}.png');
      await trayFile.writeAsBytes(trayBytes);

      var stickerPack = WhatsappStickers(
        identifier: 'mewmer_pack_${DateTime.now().millisecondsSinceEpoch}',
        name: stickerProvider.currentPackName,
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pack shared to WhatsApp!'), backgroundColor: Colors.green),
        );
      }
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
    final stickerProvider = context.watch<StickerProvider>();
    final recentStickers = stickerProvider.recentStickers;
    final currentPack = stickerProvider.currentPack;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                    Text(
                      'mewmer',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    if (currentPack.length >= 3)
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.greenAccent),
                        onPressed: () => _exportToWhatsApp(context),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              if (recentStickers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Creations',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (currentPack.isNotEmpty)
                            GestureDetector(
                              onTap: () => _showPackNameDialog(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: currentPack.length >= 3 ? Colors.green : Colors.orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  stickerProvider.currentPackName,
                                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (currentPack.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, right: 8),
                            child: Text(
                              '${currentPack.length} stickers in pack',
                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recentStickers.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(File(recentStickers[index].imagePath)),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: Colors.white10),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate, size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      Text(
                        'Start your next meme',
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add),
                        label: const Text('New Sticker'),
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
            ],
          ),
        ),
      ),
    );
  }
}
