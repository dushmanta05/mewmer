import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mewmer/screens/meme_editor_page.dart';

void main() {
  test('extractWebPFramePayload handles odd-sized final chunk without EOF padding', () {
    final mockWebp = Uint8List.fromList([
      ...WebPMuxer.utf8Encode('RIFF'),
      17, 0, 0, 0,
      ...WebPMuxer.utf8Encode('WEBP'),
      ...WebPMuxer.utf8Encode('VP8L'),
      5, 0, 0, 0,
      1, 2, 3, 4, 5,
    ]);

    final payload = WebPMuxer.extractWebPFramePayload(mockWebp);
    expect(payload.length, 14);
    expect(payload.sublist(0, 4), WebPMuxer.utf8Encode('VP8L'));
    expect(payload.last, 0);
  });
}
