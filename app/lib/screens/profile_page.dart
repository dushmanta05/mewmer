import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/cloud_provider.dart';
import '../theme.dart';
import 'cloud_packs_page.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const String _appVersion = '0.0.1+1';

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudProvider>();
    final user = cloud.user;

    return Scaffold(
      backgroundColor: MewmerTheme.background,
      appBar: AppBar(
        title: Text(
          'Account',
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
                        Icons.account_circle,
                        size: 52,
                        color: MewmerTheme.brandViolet,
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
                          onPressed: () => _openLogin(context),
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
