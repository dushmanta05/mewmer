import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/cloud_provider.dart';
import '../theme.dart';
import 'cloud_packs_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _appVersion = '0.0.1+1';
  late final TextEditingController _serverController;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(
      text: context.read<CloudProvider>().baseUrl,
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _saveServerUrl() async {
    final url = _serverController.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid http(s) URL'),
          backgroundColor: MewmerTheme.rose,
        ),
      );
      return;
    }
    await context.read<CloudProvider>().updateBaseUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server URL updated'),
        backgroundColor: MewmerTheme.whatsappGreen,
      ),
    );
  }

  Future<void> _openLogin() async {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (loggedIn == true && mounted) {
      _serverController.text = context.read<CloudProvider>().baseUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudProvider>();
    final user = cloud.user;

    return Scaffold(
      backgroundColor: MewmerTheme.background,
      appBar: AppBar(
        title: Text(
          'Account & Settings',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MewmerTheme.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MewmerTheme.border),
            ),
            child: user == null
                ? Column(
                    children: [
                      const Icon(
                        Icons.account_circle_outlined,
                        size: 52,
                        color: MewmerTheme.muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Not Signed In',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: MewmerTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to sync your sticker packs to the cloud.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: MewmerTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _openLogin,
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Sign In'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: MewmerTheme.brandViolet.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: MewmerTheme.brandViolet,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: MewmerTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: MewmerTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: MewmerTheme.whatsappGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.role,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: MewmerTheme.whatsappGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: MewmerTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CloudPacksPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.cloud_done_outlined, size: 18),
                          label: const Text('My Cloud Packs'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await cloud.logout();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Signed out')),
                            );
                          },
                          icon: const Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: MewmerTheme.rose,
                          ),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(color: MewmerTheme.rose),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: MewmerTheme.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MewmerTheme.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MewmerTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server Settings',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: MewmerTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'API Base URL',
                    hintText: 'http://localhost:3030/api/v1',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _saveServerUrl,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: MewmerTheme.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Save Server URL',
                      style: TextStyle(color: MewmerTheme.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'Mewmer v$_appVersion',
              style: TextStyle(
                fontSize: 12,
                color: MewmerTheme.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
