import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mewmer/models/cloud_models.dart';
import 'package:mewmer/models/cloud_provider.dart';
import 'package:mewmer/models/sticker_provider.dart';
import 'package:mewmer/screens/all_packs_page.dart';
import 'package:mewmer/screens/cloud_packs_page.dart';
import 'package:mewmer/screens/home_page.dart';
import 'package:mewmer/screens/login_page.dart';
import 'package:mewmer/screens/meme_editor_page.dart';
import 'package:mewmer/screens/profile_page.dart';
import 'package:mewmer/services/api_client.dart';
import 'package:mewmer/services/media_cache_service.dart';
import 'package:mewmer/services/session_store.dart';
import 'package:mewmer/theme.dart';
import 'package:provider/provider.dart';

class FakeSessionStore implements SessionStore {
  String? token;
  CloudUser? user;
  String? baseUrl;

  @override
  Future<void> clearSession() async {
    token = null;
    user = null;
  }

  @override
  Future<String?> readBaseUrl() async => baseUrl;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<CloudUser?> readUser() async => user;

  @override
  Future<void> writeBaseUrl(String value) async {
    baseUrl = value;
  }

  @override
  Future<void> writeToken(String value) async {
    token = value;
  }

  @override
  Future<void> writeUser(CloudUser value) async {
    user = value;
  }
}

Future<StickerProvider> createLoadedStickerProvider(Directory tempDir) async {
  final provider = StickerProvider(
    metadataFileProvider: () async => File('${tempDir.path}/stickers_metadata.json'),
  );
  await provider.init();
  return provider;
}

Widget wrapWithProviders({
  required Widget child,
  CloudProvider? cloudProvider,
  required StickerProvider stickerProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<StickerProvider>.value(value: stickerProvider),
      ChangeNotifierProvider<CloudProvider>(
        create: (_) => cloudProvider ?? CloudProvider(sessionStore: FakeSessionStore()),
      ),
    ],
    child: MaterialApp(
      theme: MewmerTheme.darkTheme,
      home: child,
    ),
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late Directory tempDir;
  late StickerProvider stickers;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mewmer_ui_test_');
    stickers = await createLoadedStickerProvider(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HomePage & AllPacksPage widget tests', () {
    testWidgets('shows stacked studio/gallery buttons and opens Not Signed In modal', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const HomePage(), stickerProvider: stickers),
      );
      await tester.pump();

      expect(find.text('Open Studio'), findsOneWidget);
      expect(find.text('From Gallery'), findsOneWidget);

      await tester.tap(find.byTooltip('Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Not Signed In'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('HomePage shows max 4 pack rows and View All searches by name', (tester) async {
      await tester.runAsync(() async {
        for (final name in ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon']) {
          await stickers.createPack(name);
        }
      });

      await tester.pumpWidget(
        wrapWithProviders(child: const HomePage(), stickerProvider: stickers),
      );
      await tester.pump();

      expect(find.text('View All'), findsOneWidget);
      expect(find.text('Epsilon'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);

      await tester.ensureVisible(find.text('View All'));
      await tester.tap(find.text('View All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AllPacksPage), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AllPacksPage), matching: find.text('Alpha')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AllPacksPage), matching: find.text('Epsilon')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'gam');
      await tester.pump();

      expect(
        find.descendant(of: find.byType(AllPacksPage), matching: find.text('Gamma')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AllPacksPage), matching: find.text('Alpha')),
        findsNothing,
      );
    });
  });

  group('LoginPage widget tests', () {
    testWidgets('validates email and password fields', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(child: const LoginPage(), stickerProvider: stickers),
      );

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('logs in successfully with valid credentials', (tester) async {
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(
            json.encode({
              'user': {
                'id': 'u1',
                'email': 'admin@mewmer.com',
                'username': 'admin',
                'displayName': 'Admin Cat',
                'role': 'admin',
              },
              'token': 'tok_test',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/v1/me/packs') {
          return http.Response(json.encode({'packs': []}), 200);
        }
        return http.Response('Not found', 404);
      });

      final apiClient = MewmerApiClient(httpClient: mockHttp);
      final cloud = CloudProvider(
        apiClient: apiClient,
        sessionStore: FakeSessionStore(),
        mediaCache: MediaCacheService(
          apiClient: apiClient,
          directoryProvider: () async => tempDir,
        ),
      );

      await tester.pumpWidget(
        wrapWithProviders(
          child: const LoginPage(),
          cloudProvider: cloud,
          stickerProvider: stickers,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'admin@mewmer.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'supersecret',
      );
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(cloud.isAuthenticated, isTrue);
      expect(cloud.user?.displayName, 'Admin Cat');
    });
  });

  group('ProfilePage & CloudPacksPage widget tests', () {
    testWidgets('ProfilePage renders signed-in user details and version', (tester) async {
      final store = FakeSessionStore()
        ..token = 'tok_1'
        ..user = const CloudUser(
          id: 'u1',
          email: 'admin@mewmer.com',
          username: 'admin',
          displayName: 'Admin Cat',
          role: 'admin',
        );
      final mockHttp = MockClient((request) async {
        return http.Response(
          json.encode(store.user!.toJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final cloud = CloudProvider(
        apiClient: MewmerApiClient(httpClient: mockHttp),
        sessionStore: store,
      );
      await cloud.init();

      await tester.pumpWidget(
        wrapWithProviders(
          child: const ProfilePage(),
          cloudProvider: cloud,
          stickerProvider: stickers,
        ),
      );
      await tester.pump();

      expect(find.text('Admin Cat'), findsOneWidget);
      expect(find.text('admin@mewmer.com'), findsOneWidget);
      expect(find.text('@admin'), findsOneWidget);
      expect(find.text('Sync All Now'), findsOneWidget);
      expect(find.text('Mewmer v0.0.1+1'), findsOneWidget);
    });

    testWidgets('CloudPacksPage prompts sign in when logged out', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const CloudPacksPage(),
          stickerProvider: stickers,
        ),
      );
      await tester.pump();

      expect(find.text('Cloud Sync Not Signed In'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });

  group('MemeEditorPage widget tests', () {
    testWidgets('renders studio controls and toggles Transparent / Blur BG', (tester) async {
      await tester.pumpWidget(
        wrapWithProviders(
          child: const MemeEditorPage(),
          stickerProvider: stickers,
        ),
      );
      await tester.pump();

      expect(find.text('Canvas Ready'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('GIF'), findsOneWidget);
      expect(find.text('Add Text'), findsOneWidget);
      expect(find.text('Image'), findsOneWidget);
      expect(find.text('Transparent'), findsOneWidget);

      await tester.tap(find.text('Transparent'));
      await tester.pump();

      expect(find.text('Blur BG'), findsOneWidget);
    });
  });
}
