import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/cloud_provider.dart';
import '../models/sticker_provider.dart';
import '../theme.dart';
import '../widgets/mewmer_toast.dart';
import 'pack_details_page.dart';

class AllPacksPage extends StatefulWidget {
  const AllPacksPage({super.key});

  @override
  State<AllPacksPage> createState() => _AllPacksPageState();
}

class _AllPacksPageState extends State<AllPacksPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildPackPreview(List<String> paths) {
    if (paths.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: MewmerTheme.cardHover,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.photo_library_outlined,
          color: MewmerTheme.muted,
          size: 24,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(paths.first),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 56,
          height: 56,
          color: MewmerTheme.cardHover,
          child: const Icon(
            Icons.photo_library_outlined,
            color: MewmerTheme.muted,
            size: 24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stickerProvider = context.watch<StickerProvider>();
    final cloud = context.watch<CloudProvider>();
    final trimmed = _query.trim().toLowerCase();
    final filtered = trimmed.isEmpty
        ? stickerProvider.packs
        : stickerProvider.packs
            .where((p) => p.name.toLowerCase().contains(trimmed))
            .toList();

    return Scaffold(
      backgroundColor: MewmerTheme.background,
      appBar: AppBar(
        title: Text(
          'All Sticker Packs',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (cloud.isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: cloud.isSyncing
                    ? null
                    : () async {
                        try {
                          await cloud.syncAll(stickerProvider);
                          if (!context.mounted) return;
                          MewmerToast.success(
                            context,
                            'All packs synced with cloud',
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          MewmerToast.error(context, 'Sync failed: $e');
                        }
                      },
                icon: cloud.isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MewmerTheme.brandViolet,
                        ),
                      )
                    : const Icon(
                        Icons.sync_rounded,
                        size: 16,
                        color: MewmerTheme.brandViolet,
                      ),
                label: Text(
                  cloud.isSyncing ? 'Syncing' : 'Sync All',
                  style: const TextStyle(
                    color: MewmerTheme.brandViolet,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: MewmerTheme.brandViolet.withValues(alpha: 0.14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search packs by name',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: MewmerTheme.muted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            trimmed.isEmpty
                                ? 'No Sticker Packs Yet'
                                : 'No packs matching "$_query"',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: MewmerTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final pack = filtered[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PackDetailsPage(
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
                              _buildPackPreview(pack.stickerPaths),
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
                                                ? MewmerTheme.brandViolet
                                                    .withValues(alpha: 0.2)
                                                : MewmerTheme.whatsappGreen
                                                    .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                                          '${pack.stickerPaths.length} / 30 stickers',
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
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: MewmerTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
