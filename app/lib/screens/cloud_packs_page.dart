import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/cloud_models.dart';
import '../models/cloud_provider.dart';
import '../theme.dart';
import '../widgets/mewmer_toast.dart';
import 'cloud_pack_details_page.dart';
import 'login_page.dart';

class CloudPacksPage extends StatefulWidget {
  const CloudPacksPage({super.key});

  @override
  State<CloudPacksPage> createState() => _CloudPacksPageState();
}

class _CloudPacksPageState extends State<CloudPacksPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _rawQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cloud = context.read<CloudProvider>();
      if (cloud.isAuthenticated) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<CloudProvider>().loadMorePacks();
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _rawQuery = value);
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && trimmed.length < 3) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _refresh(query: trimmed);
    });
  }

  Future<void> _refresh({String? query}) async {
    try {
      await context.read<CloudProvider>().refreshPacks(
            query: query ?? (_rawQuery.trim().length >= 3 ? _rawQuery.trim() : ''),
          );
    } catch (e) {
      if (!mounted) return;
      MewmerToast.error(context, 'Sync failed: $e');
    }
  }

  Future<void> _openLogin() async {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (loggedIn == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _logout() async {
    await context.read<CloudProvider>().logout();
    if (!mounted) return;
    MewmerToast.info(context, 'Signed out of cloud');
  }

  Widget _buildTrayThumbnail(CloudProvider cloud, CloudPack pack) {
    final localPath = cloud.localTrayPath(pack.id);
    if (localPath != null && File(localPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(localPath),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: MewmerTheme.cardHover,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.cloud_outlined,
        color: MewmerTheme.brandViolet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudProvider>();
    final trimmed = _rawQuery.trim();
    final needsMoreChars = trimmed.isNotEmpty && trimmed.length < 3;

    return Scaffold(
      backgroundColor: MewmerTheme.background,
      appBar: AppBar(
        title: Text(
          'My Cloud Packs',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (cloud.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: MewmerTheme.textMuted),
              tooltip: 'Sign Out',
              onPressed: _logout,
            ),
        ],
      ),
      body: !cloud.isAuthenticated
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: MewmerTheme.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MewmerTheme.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: MewmerTheme.brandViolet,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Cloud Sync Not Signed In',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: MewmerTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in with your admin account to view and restore your cloud sticker packs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: MewmerTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _openLogin,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign In'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search packs by title or tags',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _rawQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                if (needsMoreChars)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Type at least 3 letters to search',
                        style: TextStyle(
                          fontSize: 11,
                          color: MewmerTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: MewmerTheme.brandViolet,
                    child: cloud.packs.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              if (cloud.user != null)
                                _buildAccountBanner(cloud.user!),
                              const SizedBox(height: 36),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: MewmerTheme.cardSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: MewmerTheme.border),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.cloud_queue_rounded,
                                      size: 48,
                                      color: MewmerTheme.muted,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      cloud.isSyncing
                                          ? 'Syncing cloud packs...'
                                          : (trimmed.length >= 3
                                              ? 'No matching cloud packs'
                                              : 'No Cloud Packs Yet'),
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: MewmerTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Generate a sticker in the Studio and choose "Cloud" to create your first cloud pack.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: MewmerTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: cloud.packs.length +
                                1 +
                                (cloud.isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return cloud.user != null
                                    ? _buildAccountBanner(cloud.user!)
                                    : const SizedBox.shrink();
                              }
                              if (index == cloud.packs.length + 1) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: MewmerTheme.brandViolet,
                                    ),
                                  ),
                                );
                              }
                              final pack = cloud.packs[index - 1];
                              return InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CloudPackDetailsPage(
                                        packId: pack.id,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: MewmerTheme.cardSurface,
                                    borderRadius: BorderRadius.circular(18),
                                    border:
                                        Border.all(color: MewmerTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildTrayThumbnail(cloud, pack),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pack.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: MewmerTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              pack.publisher,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: MewmerTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: pack.isAnimated
                                                        ? MewmerTheme
                                                            .brandViolet
                                                            .withValues(
                                                              alpha: 0.2,
                                                            )
                                                        : MewmerTheme
                                                            .whatsappGreen
                                                            .withValues(
                                                              alpha: 0.15,
                                                            ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    pack.typeLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: pack.isAnimated
                                                          ? MewmerTheme
                                                              .brandViolet
                                                          : MewmerTheme
                                                              .whatsappGreen,
                                                    ),
                                                  ),
                                                ),
                                                for (final tag
                                                    in pack.tags.take(3))
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: MewmerTheme
                                                          .cardHover,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '#$tag',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: MewmerTheme
                                                            .textMuted,
                                                      ),
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
                ),
              ],
            ),
    );
  }

  Widget _buildAccountBanner(CloudUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MewmerTheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MewmerTheme.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: MewmerTheme.whatsappGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Signed in as ${user.displayName} (${user.email})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: MewmerTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
