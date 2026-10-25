import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class GifResult {
  const GifResult({
    required this.path,
    required this.width,
    required this.height,
    required this.bytes,
    required this.frames,
  });

  final String path;
  final int width;
  final int height;
  final int bytes;
  final int frames;
}

/// 动图转 GIF：Android 没有内置 GIF 编码器，这里用纯 Dart 的 image 包
/// 逐帧解码（GIF / 动态 WebP / APNG 都吃）再重编码，放在 isolate 里跑不卡界面。
class AnimationEngine {
  Future<GifResult> toGif({
    required String inputPath,
    required int width,
    required int height,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final support = await getApplicationSupportDirectory();
    final outDir = Directory('${support.path}/outputs')..createSync(recursive: true);

    final fileName = inputPath.split(Platform.pathSeparator).last;
    final stem = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final outFile = File('${outDir.path}/$stem.gif');

    final result = await compute(
      encodeAnimatedGif,
      <String, Object?>{
        'bytes': bytes,
        'out': outFile.path,
        'width': width,
        'height': height,
      },
    );

    final error = result['error'] as String?;
    if (error != null) throw Exception(error);

    return GifResult(
      path: result['path']! as String,
      width: result['width']! as int,
      height: result['height']! as int,
      bytes: result['bytes']! as int,
      frames: result['frames']! as int,
    );
  }
}

/// 运行在后台 isolate 里，返回值必须是可跨 isolate 传输的普通类型。
Map<String, Object?> encodeAnimatedGif(Map<String, Object?> args) {
  final bytes = args['bytes']! as Uint8List;
  final outPath = args['out']! as String;
  final requestedWidth = args['width']! as int;
  final requestedHeight = args['height']! as int;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return {'error': '无法解码这个文件，可能是不支持的图片格式'};
  }

  final frames = decoded.frames.isEmpty ? <img.Image>[decoded] : decoded.frames;
  if (frames.length > 300) {
    return {'error': '动图帧数过多（${frames.length} 帧），请先裁剪时长再转'};
  }

  var targetWidth = requestedWidth;
  var targetHeight = requestedHeight;
  if (targetWidth > 0 && targetHeight > 0) {
    // 两个都填：按用户要求精确输出。
  } else if (targetWidth > 0) {
    targetHeight = (targetWidth * decoded.height / decoded.width).round();
  } else if (targetHeight > 0) {
    targetWidth = (targetHeight * decoded.width / decoded.height).round();
  } else {
    targetWidth = decoded.width;
    targetHeight = decoded.height;
  }
  targetWidth = targetWidth.clamp(1, 4096);
  targetHeight = targetHeight.clamp(1, 4096);

  if (targetWidth * targetHeight > 4000000) {
    return {'error': '输出尺寸过大，动图建议控制在 1080 以内'};
  }

  final encoder = img.GifEncoder(repeat: 0);
  for (final frame in frames) {
    final resized = (frame.width == targetWidth && frame.height == targetHeight)
        ? frame
        : img.copyResize(
            frame,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.average,
          );
    // frameDuration 是毫秒，GIF 的 delay 单位是 1/100 秒。
    final centiseconds = frame.frameDuration > 0
        ? (frame.frameDuration / 10).round()
        : 8;
    encoder.addFrame(resized, duration: centiseconds.clamp(2, 200));
  }

  final output = encoder.finish();
  if (output == null) {
    return {'error': 'GIF 编码失败，请换一张图再试'};
  }
  final file = File(outPath)..writeAsBytesSync(output, flush: true);

  return {
    'path': outPath,
    'width': targetWidth,
    'height': targetHeight,
    'frames': frames.length,
    'bytes': file.lengthSync(),
  };
}
