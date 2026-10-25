import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../domain/models.dart';
import 'desktop_paths.dart';

class ImageConversion {
  const ImageConversion({
    required this.path,
    required this.uri,
    required this.width,
    required this.height,
    required this.bytes,
  });

  final String path;
  final String uri;
  final int width;
  final int height;
  final int bytes;
}

class ImageProbe {
  const ImageProbe({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final int bytes;
}

/// 图片引擎。Android 走原生（MediaStore + 系统解码器），
/// 桌面端没有这套东西，改用纯 Dart 的 image 包解码/缩放/编码。
class ImageEngine {
  static const MethodChannel _channel = MethodChannel('formatlab/image');

  Future<ImageConversion> convert({
    required String inputPath,
    required TargetFormat format,
    required int width,
    required int height,
    required int quality,
    required String folder,
  }) async {
    if (isDesktopPlatform) {
      final payload = await compute(_convertOnDesktop, <String, Object?>{
        'inputPath': inputPath,
        'format': format.name,
        'width': width,
        'height': height,
        'quality': quality,
        'folder': folder,
      });
      final error = payload['error'] as String?;
      if (error != null) throw Exception(error);
      final path = payload['path']! as String;
      return ImageConversion(
        path: path,
        uri: path,
        width: payload['width']! as int,
        height: payload['height']! as int,
        bytes: payload['bytes']! as int,
      );
    }

    try {
      final payload = await _channel.invokeMapMethod<String, dynamic>('convert', {
        'inputPath': inputPath,
        'format': format.apiName,
        'width': width,
        'height': height,
        'quality': quality,
        'folder': folder,
      });
      if (payload == null) {
        throw Exception('转换没有返回结果');
      }
      return ImageConversion(
        path: payload['path'] as String,
        uri: payload['uri'] as String,
        width: payload['width'] as int,
        height: payload['height'] as int,
        bytes: payload['bytes'] as int,
      );
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '转换失败');
    }
  }

  Future<ImageProbe> probe(String inputPath) async {
    if (isDesktopPlatform) {
      final payload = await compute(_probeOnDesktop, inputPath);
      final error = payload['error'] as String?;
      if (error != null) throw Exception(error);
      return ImageProbe(
        width: payload['width']! as int,
        height: payload['height']! as int,
        bytes: payload['bytes']! as int,
      );
    }

    final payload = await _channel.invokeMapMethod<String, dynamic>('probe', {
      'inputPath': inputPath,
    });
    if (payload == null) {
      throw Exception('无法读取图片信息');
    }
    return ImageProbe(
      width: payload['width'] as int,
      height: payload['height'] as int,
      bytes: payload['bytes'] as int,
    );
  }

  /// 把 Dart 侧生成的文件（动图 GIF、FFmpeg 产物）放进相册对应目录。
  /// 桌面端没有相册，直接复制到系统的图片 / 视频 / 音乐文件夹。
  Future<String> saveMedia({
    required String path,
    required String displayName,
    required String mime,
    required MediaKind kind,
    required String folder,
  }) async {
    if (isDesktopPlatform) {
      final dir = mediaDirectory(kind, folder);
      final target = uniquePath(dir, displayName);
      await File(path).copy(target);
      return target;
    }

    try {
      final payload =
          await _channel.invokeMapMethod<String, dynamic>('saveMedia', {
        'path': path,
        'displayName': displayName,
        'mime': mime,
        'kind': kind.name,
        'folder': folder,
      });
      if (payload == null) {
        throw Exception('保存没有返回结果');
      }
      return payload['uri'] as String;
    } on PlatformException catch (error) {
      throw Exception(error.message ?? '保存失败');
    }
  }
}

Map<String, Object?> _convertOnDesktop(Map<String, Object?> args) {
  final inputPath = args['inputPath']! as String;
  final format = TargetFormat.values.firstWhere(
    (value) => value.name == args['format'],
    orElse: () => TargetFormat.jpeg,
  );
  final requestedWidth = args['width']! as int;
  final requestedHeight = args['height']! as int;
  final quality = args['quality']! as int;
  final folder = args['folder']! as String;

  final file = File(inputPath);
  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    return {
      'error': '无法解码这个文件。桌面版暂不支持 HEIC/HEIF，'
          '可以先转成 JPG 再处理',
    };
  }

  final (targetWidth, targetHeight) = _resolveSize(
    decoded.width,
    decoded.height,
    requestedWidth,
    requestedHeight,
  );
  if (targetWidth * targetHeight > 100000000) {
    return {'error': '输出尺寸过大（$targetWidth×$targetHeight），请调小一点'};
  }

  final resized = (targetWidth == decoded.width &&
          targetHeight == decoded.height)
      ? decoded
      : img.copyResize(
          decoded,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.average,
        );

  final bytes = switch (format) {
    TargetFormat.jpeg => img.encodeJpg(resized, quality: quality),
    TargetFormat.png => img.encodePng(resized),
    TargetFormat.webp => img.encodeWebP(
        resized,
        lossless: quality >= 100,
        quality: quality,
      ),
    TargetFormat.bmp => img.encodeBmp(resized),
    TargetFormat.gif => img.encodeGif(resized),
  };

  final name = file.uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final dir = mediaDirectory(MediaKind.image, folder);
  final target = uniquePath(dir, '$stem.${format.extension}');
  final output = File(target)..writeAsBytesSync(bytes, flush: true);

  return {
    'path': output.path,
    'width': targetWidth,
    'height': targetHeight,
    'bytes': output.lengthSync(),
  };
}

Map<String, Object?> _probeOnDesktop(String inputPath) {
  final file = File(inputPath);
  if (!file.existsSync()) {
    return {'error': '源文件不在了'};
  }
  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    return {'error': '无法解码这个文件'};
  }
  return {
    'width': decoded.width,
    'height': decoded.height,
    'bytes': file.lengthSync(),
  };
}

/// 和安卓端一致：都填按精确尺寸，只填一边按原比例补另一边，都不填保持原图。
(int, int) _resolveSize(
  int sourceWidth,
  int sourceHeight,
  int requestedWidth,
  int requestedHeight,
) {
  var width = requestedWidth;
  var height = requestedHeight;
  if (width > 0 && height > 0) {
    // 精确输出。
  } else if (width > 0) {
    height = (width * sourceHeight / sourceWidth).round();
  } else if (height > 0) {
    width = (height * sourceWidth / sourceHeight).round();
  } else {
    width = sourceWidth;
    height = sourceHeight;
  }
  return (width.clamp(1, 20000), height.clamp(1, 20000));
}
