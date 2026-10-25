import 'dart:io';

import '../domain/models.dart';

/// 桌面端（Windows / macOS / Linux）判定。移动端继续走原生通道。
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

bool get isWindows => Platform.isWindows;

String get _home {
  final env = Platform.environment;
  return env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
}

/// 桌面端没有相册，按系统的媒体库目录放：图片 / 视频 / 音乐。
String _mediaRoot(MediaKind kind) {
  switch (kind) {
    case MediaKind.image:
      return '$_home${Platform.pathSeparator}Pictures';
    case MediaKind.video:
      return '$_home${Platform.pathSeparator}Videos';
    case MediaKind.audio:
      return '$_home${Platform.pathSeparator}Music';
  }
}

/// 取（并创建）输出目录，folder 是设置里的子目录名。
String mediaDirectory(MediaKind kind, String folder) {
  final cleaned = folder
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '')
      .trim();
  final root = _mediaRoot(kind);
  final target = cleaned.isEmpty
      ? root
      : '$root${Platform.pathSeparator}$cleaned';
  Directory(target).createSync(recursive: true);
  return target;
}

/// 同名文件自动加序号，和安卓端 MediaStore 的行为保持一致。
String uniquePath(String directory, String fileName) {
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '';
  var candidate = '$directory${Platform.pathSeparator}$fileName';
  var index = 1;
  while (File(candidate).existsSync()) {
    candidate = '$directory${Platform.pathSeparator}$stem ($index)$ext';
    index++;
  }
  return candidate;
}
