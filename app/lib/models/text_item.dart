import 'package:flutter/material.dart';

class TextItem {
  String text;
  Offset position;
  Color color;
  TextStyle fontStyle;
  double scale;
  double rotation;
  double fontSize;

  bool isMemeStyle;
  double outlineWidth;
  Color outlineColor;
  bool useCaps;
  bool hasShadow;

  TextItem({
    required this.text,
    required this.position,
    required this.color,
    required this.fontStyle,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.fontSize = 24.0,
    this.isMemeStyle = false,
    this.outlineWidth = 4.0,
    this.outlineColor = Colors.black,
    this.useCaps = false,
    this.hasShadow = false,
  });
}
