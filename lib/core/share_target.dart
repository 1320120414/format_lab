import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../infrastructure/desktop_paths.dart';

/// 移动端弹系统分享；桌面端没有统一分享面板，改成在资源管理器里定位文件。
Future<void> shareFile({required String path, required String text}) async {
  if (isDesktopPlatform) {
    if (!File(path).existsSync()) {
      throw Exception('文件不在本地了');
    }
    await Process.run('explorer.exe', ['/select,', path]);
    return;
  }
  await SharePlus.instance.share(
    ShareParams(files: [XFile(path)], text: text),
  );
}
