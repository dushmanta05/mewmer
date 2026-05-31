import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/sticker_provider.dart';
import 'screens/home_page.dart';

class MewmerApp extends StatelessWidget {
  const MewmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StickerProvider()..init(),
      child: MaterialApp(
        title: 'mewmer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
