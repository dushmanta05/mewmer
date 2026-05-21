import 'package:flutter/material.dart';

class TextItem {
  String text;
  Offset position;
  Color color;
  TextStyle fontStyle;
  double scale;
  double rotation;

  TextItem({
    required this.text,
    required this.position,
    required this.color,
    required this.fontStyle,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}
