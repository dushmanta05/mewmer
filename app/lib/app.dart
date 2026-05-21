import 'package:flutter/material.dart';
import 'screens/home_page.dart';

class MewmerApp extends StatelessWidget {
  const MewmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
