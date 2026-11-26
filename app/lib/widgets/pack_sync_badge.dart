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
      if (!showLabel) {
        return const Icon(
          Icons.cloud_done_outlined,
          size: 16,
          color: MewmerTheme.whatsappGreen,
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: MewmerTheme.whatsappGreen.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done_outlined,
              size: 14,
              color: MewmerTheme.whatsappGreen,
            ),
            SizedBox(width: 5),
            Text(
              'Synced',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MewmerTheme.whatsappGreen,
              ),
            ),
          ],
        ),
      );
    }

    if (!showLabel) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _syncPack(context),
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(
            Icons.cloud_upload_outlined,
            size: 16,
            color: MewmerTheme.amber,
          ),
        ),
      );
    }

    final pending = pack.pendingSyncCount;
    final label = pending > 0 ? 'Sync ($pending)' : 'Sync';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _syncPack(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: MewmerTheme.brandViolet.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: MewmerTheme.brandViolet.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              size: 14,
              color: MewmerTheme.brandViolet,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MewmerTheme.brandViolet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
