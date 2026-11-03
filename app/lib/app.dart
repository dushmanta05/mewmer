import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/sticker_provider.dart';
import 'screens/home_page.dart';
import 'theme.dart';

class MewmerApp extends StatelessWidget {
  const MewmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StickerProvider()..init(),
      child: MaterialApp(
        title: 'mewmer',
        debugShowCheckedModeBanner: false,
        theme: MewmerTheme.darkTheme,
        home: const HomePage(),
      ),
    );
  }
}
