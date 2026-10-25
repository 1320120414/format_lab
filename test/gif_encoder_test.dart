import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:format_lab/infrastructure/animation_engine.dart';
import 'package:image/image.dart' as img;

void main() {
  test('两帧动图能重编码成指定尺寸的 GIF', () {
    final animated = img.Image(width: 8, height: 8, numChannels: 3);
    for (var index = 0; index < 2; index++) {
      final frame = img.Image(width: 8, height: 8, numChannels: 3);
      img.fill(
        frame,
        color: index == 0 ? img.ColorRgb8(255, 0, 0) : img.ColorRgb8(0, 0, 255),
      );
      animated.addFrame(frame);
    }

    final sourceEncoder = img.GifEncoder();
    for (final frame in animated.frames) {
      sourceEncoder.addFrame(frame, duration: 10);
    }
    final sourceBytes = sourceEncoder.finish()!;
    final decodedSource = img.decodeImage(sourceBytes)!;

    final outPath = '${Directory.systemTemp.path}/format_lab_gif_test.gif';
    final result = encodeAnimatedGif(<String, Object?>{
      'bytes': Uint8List.fromList(sourceBytes),
      'out': outPath,
      'width': 4,
      'height': 4,
    });

    expect(result['error'], isNull);
    expect(result['frames'], decodedSource.numFrames);
    expect(result['width'], 4);
    expect(result['height'], 4);

    final output = File(outPath).readAsBytesSync();
    expect(String.fromCharCodes(output.take(6)), 'GIF89a');

    final decodedOutput = img.decodeImage(output)!;
    expect(decodedOutput.width, 4);
    expect(decodedOutput.height, 4);
    expect(decodedOutput.numFrames, greaterThanOrEqualTo(2));

    File(outPath).deleteSync();
  });

  test('只填宽度时按原比例推算高度', () {
    final frame = img.Image(width: 8, height: 4, numChannels: 3);
    img.fill(frame, color: img.ColorRgb8(10, 20, 30));

    final outPath = '${Directory.systemTemp.path}/format_lab_gif_ratio.gif';
    final result = encodeAnimatedGif(<String, Object?>{
      'bytes': Uint8List.fromList(img.encodePng(frame)),
      'out': outPath,
      'width': 16,
      'height': 0,
    });

    expect(result['error'], isNull);
    expect(result['width'], 16);
    expect(result['height'], 8);

    File(outPath).deleteSync();
  });
}
