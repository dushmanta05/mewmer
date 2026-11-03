import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: MewmerTheme.background,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: MewmerTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MewmerApp());
}
