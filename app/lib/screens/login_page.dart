import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/cloud_provider.dart';
import '../theme.dart';
import '../widgets/cat_branding.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TextEditingController _serverUrlController;
  bool _obscurePassword = true;
  bool _showServerConfig = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final baseUrl = context.read<CloudProvider>().baseUrl;
    _serverUrlController = TextEditingController(text: baseUrl);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final cloudProvider = context.read<CloudProvider>();

    try {
      await cloudProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        serverUrl: _serverUrlController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cloudProvider.errorMessage ?? 'Login failed: $e'),
          backgroundColor: MewmerTheme.rose,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MewmerTheme.background,
      appBar: AppBar(
        title: Text(
          'Cloud Sign In',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Center(
                  child: MewmerBrandHeader(iconSize: 44, fontSize: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign in with your admin account to sync sticker packs to the cloud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MewmerTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MewmerTheme.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MewmerTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'admin@mewmer.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty || !trimmed.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () => _showServerConfig = !_showServerConfig,
                          ),
                          icon: Icon(
                            _showServerConfig
                                ? Icons.expand_less
                                : Icons.settings_outlined,
                            size: 16,
                            color: MewmerTheme.textMuted,
                          ),
                          label: const Text(
                            'Server URL',
                            style: TextStyle(
                              fontSize: 12,
                              color: MewmerTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                      if (_showServerConfig) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _serverUrlController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'API Base URL',
                            hintText: 'http://localhost:3030/api/v1',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty ||
                                (!trimmed.startsWith('http://') &&
                                    !trimmed.startsWith('https://'))) {
                              return 'Enter a valid http(s) URL';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Sign In'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
