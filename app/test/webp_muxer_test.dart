import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mewmer/screens/meme_editor_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('assembleAnimatedWebP decodes all frames via Skia multi_frame_codec', () async {
    final frame0 = Uint8List.fromList([
      82, 73, 70, 70, 116, 2, 0, 0, 87, 69, 66, 80, 86, 80, 56, 88, 10, 0, 0, 0, 16, 0, 0, 0, 255, 1, 0, 255, 1, 0, 65, 76, 80, 72, 28, 0, 0, 0, 1, 7, 80, 192, 136, 8, 8, 4, 146, 253, 189, 103, 40, 162, 255, 25, 255, 249, 207, 127, 254, 243, 159, 255, 252, 231, 255, 0, 86, 80, 56, 32, 50, 2, 0, 0, 144, 59, 0, 157, 1, 42, 0, 2, 0, 2, 63, 17, 136, 193, 90, 44, 41, 39, 36, 32, 8, 1, 128, 34, 9, 105, 110, 225, 119, 97, 30, 220, 0, 0, 19, 216, 7, 190, 217, 57, 15, 125, 178, 114, 30, 251, 100, 228, 61, 246, 201, 200, 123, 237, 147, 144, 247, 219, 39, 33, 239, 182, 78, 71, 252, 243, 25, 106, 7, 233, 122, 195, 132, 181, 145, 16, 60, 156, 143, 249, 230, 50, 212, 15, 210, 245, 135, 9, 107, 34, 32, 121, 57, 31, 243, 246, 66, 243, 95, 108, 162, 79, 139, 8, 51, 3, 54, 188, 112, 32, 30, 251, 100, 228, 61, 246, 201, 200, 123, 237, 147, 145, 16, 60, 156, 135, 190, 217, 57, 15, 125, 178, 114, 30, 251, 101, 3, 47, 23, 39, 33, 239, 182, 78, 67, 223, 108, 156, 135, 191, 0, 64, 61, 246, 201, 200, 123, 237, 147, 144, 247, 219, 39, 34, 32, 121, 57, 15, 125, 178, 114, 30, 251, 100, 228, 61, 246, 202, 6, 94, 46, 78, 67, 223, 108, 156, 135, 190, 217, 57, 15, 126, 0, 128, 123, 237, 147, 144, 247, 219, 39, 33, 239, 182, 78, 68, 64, 242, 114, 30, 251, 100, 228, 61, 246, 201, 200, 123, 237, 148, 12, 188, 92, 156, 135, 190, 217, 57, 15, 125, 178, 114, 30, 252, 1, 0, 247, 219, 39, 33, 239, 182, 78, 67, 223, 108, 156, 136, 129, 228, 228, 61, 246, 201, 200, 123, 237, 147, 144, 247, 219, 40, 25, 120, 185, 57, 15, 125, 178, 114, 30, 251, 100, 228, 61, 248, 2, 1, 239, 182, 78, 67, 223, 108, 156, 135, 190, 217, 57, 17, 3, 201, 200, 123, 237, 147, 144, 247, 219, 39, 33, 239, 182, 80, 50, 241, 114, 114, 30, 251, 100, 228, 61, 246, 201, 200, 123, 240, 4, 3, 223, 108, 156, 135, 190, 217, 57, 15, 125, 178, 114, 34, 7, 147, 144, 247, 219, 39, 33, 239, 182, 78, 67, 223, 108, 160, 101, 226, 228, 228, 61, 246, 201, 200, 123, 237, 147, 144, 247, 224, 8, 7, 190, 217, 57, 15, 125, 178, 114, 30, 251, 100, 228, 68, 15, 39, 33, 239, 182, 78, 67, 223, 108, 156, 135, 190, 217, 64, 203, 197, 201, 200, 123, 237, 147, 144, 247, 219, 39, 33, 239, 192, 16, 15, 125, 178, 114, 30, 251, 100, 228, 61, 246, 201, 200, 136, 30, 78, 67, 223, 108, 156, 135, 190, 217, 57, 15, 125, 178, 129, 151, 139, 147, 144, 247, 219, 39, 33, 239, 182, 78, 67, 223, 128, 32, 30, 251, 100, 228, 61, 246, 201, 200, 123, 237, 147, 145, 16, 60, 156, 135, 190, 217, 57, 15, 125, 178, 114, 30, 251, 101, 3, 47, 23, 39, 33, 239, 182, 78, 67, 223, 108, 156, 127, 0, 0, 254, 255, 138, 157, 255, 225, 181, 86, 86, 223, 255, 252, 179, 254, 242, 189, 16, 239, 244, 145, 144, 157, 248, 250, 100, 39, 126, 62, 153, 9, 223, 143, 166, 66, 119, 227, 233, 144, 157, 248, 250, 100, 39, 126, 54, 54, 133, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ]);
    final muxed = WebPMuxer.assembleAnimatedWebP([frame0, frame0, frame0], [100, 100, 100]);
    expect(muxed.length, greaterThan(40));
    final codec = await ui.instantiateImageCodec(muxed);
    expect(codec.frameCount, 3);
    for (int i = 0; i < 3; i++) {
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 512);
    }

    final vp8Chunk = frame0.sublist(66);
    final vp8OnlyFrame = Uint8List.fromList([
      ...WebPMuxer.utf8Encode('RIFF'),
      ...WebPMuxer.uint32ToBytes(4 + vp8Chunk.length),
      ...WebPMuxer.utf8Encode('WEBP'),
      ...vp8Chunk,
    ]);
    final mixedMuxed = WebPMuxer.assembleAnimatedWebP(
      [vp8OnlyFrame, frame0, vp8OnlyFrame],
      [100, 100, 100],
    );
    final mixedCodec = await ui.instantiateImageCodec(mixedMuxed);
    expect(mixedCodec.frameCount, 3);
    for (int i = 0; i < 3; i++) {
      final frame = await mixedCodec.getNextFrame();
      expect(frame.image.width, 512);
      frame.image.dispose();
    }
    mixedCodec.dispose();
  });
}
