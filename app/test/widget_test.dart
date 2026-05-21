// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:mewmer/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MewmerApp());
  });
}
