import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cloud_provider.dart';
import '../models/sticker_provider.dart';
import '../theme.dart';

class PackSyncBadge extends StatelessWidget {
  final StickerPack pack;
  final bool showLabel;

  const PackSyncBadge({
    super.key,
    required this.pack,
    this.showLabel = false,
  });

  Future<void> _syncPack(BuildContext context) async {
    final cloud = context.read<CloudProvider>();
    final local = context.read<StickerProvider>();
    try {
      await cloud.syncLocalPack(local, pack);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced "${pack.name}" to cloud'),
          backgroundColor: MewmerTheme.whatsappGreen,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: MewmerTheme.rose,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudProvider>();
    if (!cloud.isAuthenticated) return const SizedBox.shrink();

    if (cloud.isPackSyncing(pack.identifier)) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: MewmerTheme.brandViolet,
        ),
      );
    }

    if (!pack.hasPendingSync) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: MewmerTheme.whatsappGreen.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_done_outlined,
              size: 14,
              color: MewmerTheme.whatsappGreen,
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              const Text(
                'Synced',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MewmerTheme.whatsappGreen,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final pending = pack.pendingSyncCount;
    final label = pending > 0 ? '$pending pending' : 'Sync';

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _syncPack(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: MewmerTheme.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MewmerTheme.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              size: 14,
              color: MewmerTheme.amber,
            ),
            if (showLabel || pending > 0) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: MewmerTheme.amber,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
