import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 部分机型 picker 回来的是 content://，引擎只认真实路径，这里落一份到缓存。
Future<String?> materializePicked(PlatformFile file) async {
  final direct = file.path;
  if (direct != null) return direct;
  final dir = await getTemporaryDirectory();
  final target = File(
    '${dir.path}/picked_${DateTime.now().microsecondsSinceEpoch}_${file.name}',
  );
  await file.xFile.saveTo(target.path);
  return target.path;
}
