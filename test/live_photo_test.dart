import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:format_lab/domain/models.dart';
import 'package:format_lab/infrastructure/ffmpeg_engine.dart';
import 'package:format_lab/infrastructure/motion_photo.dart';

Uint8List _photoWithAppendedVideo() {
  final photo = List<int>.filled(300 * 1024, 0xFF);
  final video = <int>[
    0, 0, 0, 32, // box 长度
    0x66, 0x74, 0x79, 0x70, // ftyp
    ...List<int>.filled(120 * 1024, 0),
  ];
  return Uint8List.fromList([...photo, ...video]);
}

Uint8List _plainHeic() {
  return Uint8List.fromList([
    0, 0, 0, 24,
    0x66, 0x74, 0x79, 0x70, // ftyp 在文件开头
    ...List<int>.filled(300 * 1024, 0),
  ]);
}

void main() {
  group('实况照片识别', () {
    test('能找到尾部追加的 MP4 起点', () {
      final bytes = _photoWithAppendedVideo();
      final offset = MotionPhoto.findEmbeddedVideoOffset(bytes);

      expect(offset, isNotNull);
      expect(offset, 300 * 1024);
      expect(bytes.length - offset!, greaterThan(100 * 1024));
    });

    test('普通 HEIC 的 ftyp 在开头，不会被误判', () {
      expect(MotionPhoto.findEmbeddedVideoOffset(_plainHeic()), isNull);
    });

    test('太小的文件直接跳过', () {
      final small = Uint8List.fromList([
        0, 0, 0, 32,
        0x66, 0x74, 0x79, 0x70,
        ...List<int>.filled(1024, 0),
      ]);
      expect(MotionPhoto.findEmbeddedVideoOffset(small), isNull);
    });
  });

  group('实况照片转 GIF', () {
    test('用取色板两遍转换并循环播放', () {
      final plan = planGifFromVideo(
        inputPath: '/tmp/motion.mp4',
        outputPath: '/tmp/motion.gif',
        width: 320,
        height: 0,
      );
      final args = plan.arguments.join(' ');

      expect(plan.extension, 'gif');
      expect(plan.mime, 'image/gif');
      expect(plan.kind, MediaKind.image);
      expect(args, contains('palettegen'));
      expect(args, contains('paletteuse'));
      expect(args, contains('-loop 0'));
      expect(args, contains('scale=w=320:h=-2'));
      expect(args, contains('fps=12'));
    });

    test('没设尺寸时限制在 480 以内', () {
      final plan = planGifFromVideo(
        inputPath: '/tmp/motion.mp4',
        outputPath: '/tmp/motion.gif',
        width: 0,
        height: 0,
      );

      expect(plan.arguments.join(' '), contains('min(iw,480)'));
    });
  });
}
