import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cloud_provider.dart';
import '../screens/login_page.dart';
import '../theme.dart';

Future<bool> showSaveToCloudFlow(
  BuildContext context, {
  required File stickerFile,
  required bool isAnimated,
}) async {
  final byteSize = await stickerFile.length();
  final maxBytes = isAnimated ? 500 * 1024 : 100 * 1024;
  if (byteSize >= maxBytes) {
    if (context.mounted) {
      final limitKb = isAnimated ? 500 : 100;
      final actualKb = (byteSize / 1024).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sticker is $actualKb KB, exceeding the $limitKb KB WhatsApp limit.',
          ),
          backgroundColor: MewmerTheme.rose,
        ),
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  final cloud = context.read<CloudProvider>();
  if (!cloud.isAuthenticated) {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (loggedIn != true || !context.mounted) return false;
  }

  try {
    await cloud.refreshPacks();
  } catch (_) {}

  if (!context.mounted) return false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SaveToCloudDialog(
      stickerFile: stickerFile,
      isAnimated: isAnimated,
    ),
  );
  return result == true;
}

class _SaveToCloudDialog extends StatefulWidget {
  final File stickerFile;
  final bool isAnimated;

  const _SaveToCloudDialog({
    required this.stickerFile,
    required this.isAnimated,
  });

  @override
  State<_SaveToCloudDialog> createState() => _SaveToCloudDialogState();
}

class _SaveToCloudDialogState extends State<_SaveToCloudDialog> {
  String? _selectedPackId;
  bool _createNew = false;
  bool _isUploading = false;
  final _titleController = TextEditingController();
  final _emojisController = TextEditingController(text: '✨');

  @override
  void initState() {
    super.initState();
    final cloud = context.read<CloudProvider>();
    final compatible = cloud.packs
        .where((p) => p.isAnimated == widget.isAnimated)
        .toList();
    if (compatible.isNotEmpty) {
      _selectedPackId = compatible.first.id;
    } else {
      _createNew = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _emojisController.dispose();
    super.dispose();
  }

  List<String> _parseEmojis(String raw) {
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? const ['✨'] : parts;
  }

  Future<void> _submit() async {
    if (_isUploading) return;

    final cloud = context.read<CloudProvider>();
    if (_createNew && _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a cloud pack title')),
      );
      return;
    }
    if (!_createNew && _selectedPackId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cloud pack')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      String targetPackId;
      if (_createNew) {
        final trayFile = await cloud.buildTrayIconFromSticker(widget.stickerFile);
        final created = await cloud.createPack(
          title: _titleController.text.trim(),
          trayFile: trayFile,
        );
        targetPackId = created.id;
      } else {
        targetPackId = _selectedPackId!;
      }

      await cloud.uploadStickerToPack(
        packId: targetPackId,
        stickerFile: widget.stickerFile,
        isAnimated: widget.isAnimated,
        emojis: _parseEmojis(_emojisController.text),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sticker uploaded to cloud pack!'),
          backgroundColor: MewmerTheme.whatsappGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cloud upload failed: $e'),
          backgroundColor: MewmerTheme.rose,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudProvider>();
    final compatible = cloud.packs
        .where((p) => p.isAnimated == widget.isAnimated)
        .toList();

    return AlertDialog(
      title: const Text('Save to Cloud Pack'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compatible.isNotEmpty) ...[
              const Text(
                'Choose a cloud pack:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedPackId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: compatible
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          '${p.title} (${p.typeLabel})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _createNew || _isUploading
                    ? null
                    : (val) => setState(() => _selectedPackId = val),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _createNew,
                    onChanged: _isUploading
                        ? null
                        : (val) {
                            setState(() {
                              _createNew = val ?? false;
                              if (!_createNew && compatible.isNotEmpty) {
                                _selectedPackId = compatible.first.id;
                              }
                            });
                          },
                  ),
                  const Text('Or create a new cloud pack'),
                ],
              ),
            ],
            if (_createNew) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                enabled: !_isUploading,
                decoration: const InputDecoration(
                  labelText: 'New Cloud Pack Title',
                  hintText: 'e.g. Reaction Cats',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _emojisController,
              enabled: !_isUploading,
              decoration: const InputDecoration(
                labelText: 'Emojis (comma-separated)',
                hintText: '😂,👍',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: MewmerTheme.textMuted),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _submit,
          icon: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(_isUploading ? 'Uploading...' : 'Upload'),
        ),
      ],
    );
  }
}
