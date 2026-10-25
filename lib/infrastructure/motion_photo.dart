import 'dart:io';
import 'dart:typed_data';

/// 实况照片（Motion Photo）本质是「一张静态图 + 尾部追加的一段 MP4」。
/// Android 的动图解码器只会读到那张静态图，所以转 GIF 前要先把尾部视频抠出来。
///
/// 这里不解析 XMP 里的 MicroVideoOffset（新旧规范格式不同），
/// 直接在文件里从后往前找最后一个 `ftyp` 盒子——追加的 MP4 一定在文件尾部，
/// 这样新旧两种实况照片都能覆盖。
class MotionPhoto {
  static const _minVideoBytes = 100 * 1024;
  static const _minFileBytes = 200 * 1024;

  static bool _looksLikePhoto(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  /// 返回内嵌视频的临时文件路径；不是实况照片就返回 null。
  /// 是否真的含视频轨，交给调用方用 ffprobe 再确认一次。
  static Future<String?> extractVideo(String sourcePath) async {
    if (!_looksLikePhoto(sourcePath)) return null;

    final file = File(sourcePath);
    final length = await file.length();
    if (length < _minFileBytes) return null;

    final bytes = await file.readAsBytes();
    final offset = findEmbeddedVideoOffset(bytes);
    if (offset == null) return null;

    final tail = Uint8List.sublistView(bytes, offset);
    final out = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'motion_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    await out.writeAsBytes(tail, flush: true);
    return out.path;
  }

  /// 找到尾部 MP4 的起始位置（`ftyp` 前 4 字节是 box 长度）。
  /// 返回 null 表示没有内嵌视频。
  static int? findEmbeddedVideoOffset(Uint8List bytes) {
    if (bytes.length < _minFileBytes) return null;

    // 普通 HEIC/AVIF 的 ftyp 在文件开头，只有出现在后半段才是追加的视频。
    final searchFloor = (bytes.length * 0.5).floor();

    for (var i = bytes.length - 8; i >= searchFloor; i--) {
      if (bytes[i] == 0x66 && // f
          bytes[i + 1] == 0x74 && // t
          bytes[i + 2] == 0x79 && // y
          bytes[i + 3] == 0x70) {
        final start = i - 4;
        if (start <= 0) return null;
        if (bytes.length - start < _minVideoBytes) return null;
        return start;
      }
    }
    return null;
  }
}
