import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';
import 'desktop_paths.dart';

class MediaInfo {
  const MediaInfo({
    required this.duration,
    required this.hasVideo,
    required this.hasAudio,
  });

  final Duration duration;
  final bool hasVideo;
  final bool hasAudio;
}

class FfmpegPlan {
  const FfmpegPlan({
    required this.arguments,
    required this.extension,
    required this.mime,
    required this.kind,
  });

  final List<String> arguments;
  final String extension;
  final String mime;
  final MediaKind kind;
}

/// FFmpeg 的 Dart 侧门面。只负责"探测 + 执行 + 回报进度"，
/// 具体命令由 [planFor] 这类纯函数拼出来，方便单独测。
///
/// Android 走 FFmpegKit；桌面端没有 FFmpegKit，改为直接调 ffmpeg.exe。
class FfmpegEngine {
  Future<String?> version() async {
    if (isDesktopPlatform) return DesktopFfmpeg.version();
    try {
      return await FFmpegKitConfig.getFFmpegVersion();
    } catch (_) {
      return null;
    }
  }

  Future<MediaInfo> probe(String path) async {
    if (isDesktopPlatform) return DesktopFfmpeg.probe(path);

    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) {
      throw Exception('读不出这个文件的媒体信息');
    }
    final seconds = double.tryParse(info.getDuration() ?? '') ?? 0;
    var hasVideo = false;
    var hasAudio = false;
    for (final stream in info.getStreams()) {
      final type = stream.getType();
      if (type == 'video') hasVideo = true;
      if (type == 'audio') hasAudio = true;
    }
    return MediaInfo(
      duration: Duration(milliseconds: (seconds * 1000).round()),
      hasVideo: hasVideo,
      hasAudio: hasAudio,
    );
  }

  Future<void> run(
    List<String> arguments, {
    required Duration duration,
    void Function(double progress)? onProgress,
  }) async {
    if (isDesktopPlatform) {
      return DesktopFfmpeg.run(
        arguments,
        duration: duration,
        onProgress: onProgress,
      );
    }

    final completer = Completer<void>();
    final totalMs = duration.inMilliseconds;

    await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          onProgress?.call(1);
          if (!completer.isCompleted) completer.complete();
          return;
        }
        final output = await session.getOutput();
        debugPrint('FFmpeg 失败: ffmpeg ${arguments.join(' ')}');
        debugPrint(output ?? '(无输出)');
        if (!completer.isCompleted) {
          completer.completeError(Exception(friendlyFfmpegError(output)));
        }
      },
      null,
      (statistics) {
        final time = statistics.getTime();
        if (time > 0 && totalMs > 0 && !completer.isCompleted) {
          final value = (time / totalMs).clamp(0.0, 0.98);
          onProgress?.call(value);
        }
      },
    );

    return completer.future;
  }
}

/// 桌面端没有 FFmpegKit，直接起 ffmpeg.exe 进程，进度从 `-progress` 的
/// `out_time_us` 行里读。
class DesktopFfmpeg {
  static String? _cached;

  /// 查找顺序：环境变量 → 应用目录 → 应用目录/bin → PATH。
  static Future<String> executable() async {
    if (_cached != null && File(_cached!).existsSync()) return _cached!;

    final appDir = File(Platform.resolvedExecutable).parent.path;
    final override = Platform.environment['FORMATLAB_FFMPEG'];
    final candidates = <String>[
      if (override != null && override.trim().isNotEmpty) override.trim(),
      '$appDir${Platform.pathSeparator}ffmpeg.exe',
      '$appDir${Platform.pathSeparator}bin${Platform.pathSeparator}ffmpeg.exe',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        _cached = path;
        return path;
      }
    }

    try {
      final where = await Process.run('where', ['ffmpeg']);
      if (where.exitCode == 0) {
        for (final line in (where.stdout as String).split(RegExp(r'\r?\n'))) {
          final path = line.trim();
          if (path.isNotEmpty && File(path).existsSync()) {
            _cached = path;
            return path;
          }
        }
      }
    } catch (_) {
      // where 不存在就直接往下面的报错走。
    }

    throw Exception(
      '没找到 ffmpeg.exe。把 ffmpeg.exe 放到应用目录，或安装 FFmpeg 后加入 PATH，'
      '也可以用环境变量 FORMATLAB_FFMPEG 指定完整路径。',
    );
  }

  static Future<String?> version() async {
    try {
      final exe = await executable();
      final result = await Process.run(exe, ['-version']);
      if (result.exitCode != 0) return null;
      final first = (result.stdout as String).split('\n').first.trim();
      return first.isEmpty ? null : first;
    } catch (_) {
      return null;
    }
  }

  static Future<MediaInfo> probe(String path) async {
    final exe = await executable();
    // 只用 ffmpeg 就能探测：-i 不带输出时会以 1 退出，信息全在 stderr。
    final result = await Process.run(exe, ['-hide_banner', '-i', path]);
    final output = '${result.stderr}';
    final durationMatch =
        RegExp(r'Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)').firstMatch(output);
    if (durationMatch == null) {
      throw Exception(friendlyFfmpegError(output));
    }
    final hours = int.parse(durationMatch.group(1)!);
    final minutes = int.parse(durationMatch.group(2)!);
    final seconds = double.parse(durationMatch.group(3)!);
    return MediaInfo(
      duration: Duration(
        milliseconds:
            ((hours * 3600 + minutes * 60 + seconds) * 1000).round(),
      ),
      hasVideo: RegExp(r'Stream #\d+:\d+.*: Video:').hasMatch(output),
      hasAudio: RegExp(r'Stream #\d+:\d+.*: Audio:').hasMatch(output),
    );
  }

  static Future<void> run(
    List<String> arguments, {
    required Duration duration,
    void Function(double progress)? onProgress,
  }) async {
    final exe = await executable();
    final args = <String>[
      ...arguments.take(arguments.length - 1),
      '-progress', 'pipe:1',
      '-nostats',
      arguments.last,
    ];

    final process = await Process.start(exe, args);
    final totalMs = duration.inMilliseconds;
    final errors = StringBuffer();

    final progressSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final match = RegExp(r'^out_time_us=(\d+)').firstMatch(line.trim());
      if (match == null || totalMs <= 0) return;
      final microseconds = int.tryParse(match.group(1)!);
      if (microseconds == null) return;
      final value = (microseconds / 1000 / totalMs).clamp(0.0, 0.98);
      onProgress?.call(value);
    });
    final errorSub = process.stderr.transform(utf8.decoder).listen(errors.write);

    final code = await process.exitCode;
    await progressSub.cancel();
    await errorSub.cancel();

    if (code == 0) {
      onProgress?.call(1);
      return;
    }

    final output = errors.toString();
    debugPrint('FFmpeg 失败: ffmpeg ${args.join(' ')}');
    debugPrint(output.isEmpty ? '(无输出)' : output);
    throw Exception(friendlyFfmpegError(output));
  }
}

String friendlyFfmpegError(String? output) {
  if (output == null || output.trim().isEmpty) return '转换失败';
  final lower = output.toLowerCase();

  if (lower.contains('unknown encoder')) {
    final match = RegExp(r"Unknown encoder '([^']+)'").firstMatch(output);
    final name = match?.group(1) ?? '所需';
    return '当前引擎缺少 $name 编码器';
  }
  if (lower.contains('no such file or directory')) {
    return '读写文件失败，源文件可能已被移动或删除';
  }
  if (lower.contains('permission denied')) {
    return '没有权限读取这个文件';
  }
  if (lower.contains('invalid data found')) {
    return '文件内容无法解析，可能已损坏或格式不受支持';
  }
  if (lower.contains('no space left')) {
    return '存储空间不足';
  }

  final lines = output
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final tail = lines.reversed.take(3).toList().reversed.join(' | ');
  return '转换失败：$tail';
}

/// 把 spec 翻译成 FFmpeg 参数。纯函数，方便写单测。
FfmpegPlan planFor(
  TaskSpec spec, {
  required String inputPath,
  required String outputPath,
}) {
  switch (spec) {
    case AudioConvertSpec(:final format, :final bitrateKbps):
    case ExtractAudioSpec(:final format, :final bitrateKbps):
      final args = <String>[
        '-y',
        '-i', inputPath,
        '-vn',
        '-c:a', format.codec,
        if (format.supportsBitrate) ...['-b:a', '${bitrateKbps}k'],
        if (format == AudioFormat.wav) ...['-ar', '44100', '-ac', '2'],
        if (format == AudioFormat.mp3) ...['-ar', '44100'],
        outputPath,
      ];
      return FfmpegPlan(
        arguments: args,
        extension: format.extension,
        mime: format.mime,
        kind: MediaKind.audio,
      );

    case VideoCompressSpec(:final preset, :final resolution):
      final edge = resolution.maxEdge;
      final filters = <String>[
        if (edge > 0)
          "scale=w='min(iw,$edge)':h='min(ih,$edge)':force_original_aspect_ratio=decrease",
        'scale=w=trunc(iw/2)*2:h=trunc(ih/2)*2',
      ];
      final args = <String>[
        '-y',
        '-i', inputPath,
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-crf', '${preset.crf}',
        '-pix_fmt', 'yuv420p',
        if (filters.isNotEmpty) ...['-vf', filters.join(',')],
        '-c:a', 'aac',
        '-b:a', '128k',
        '-movflags', '+faststart',
        outputPath,
      ];
      return FfmpegPlan(
        arguments: args,
        extension: 'mp4',
        mime: 'video/mp4',
        kind: MediaKind.video,
      );

    case VideoRemuxSpec(:final container):
      return FfmpegPlan(
        arguments: <String>[
          '-y',
          '-i', inputPath,
          '-c', 'copy',
          if (container == VideoContainer.mp4) ...['-movflags', '+faststart'],
          outputPath,
        ],
        extension: container.extension,
        mime: container.mime,
        kind: MediaKind.video,
      );

    case ImageSpec():
      throw StateError('图片任务不应该走 FFmpeg');
  }
}

/// 实况照片里抽出来的视频转 GIF：两遍调色板，颜色比直接转准很多。
FfmpegPlan planGifFromVideo({
  required String inputPath,
  required String outputPath,
  required int width,
  required int height,
  int fps = 12,
}) {
  final String scale;
  if (width > 0 && height > 0) {
    scale = 'scale=$width:$height';
  } else if (width > 0) {
    scale = 'scale=w=$width:h=-2';
  } else if (height > 0) {
    scale = 'scale=w=-2:h=$height';
  } else {
    scale =
        "scale=w='min(iw,480)':h='min(ih,480)':force_original_aspect_ratio=decrease";
  }

  final filter = '[0:v]fps=$fps,$scale,split[a][b];'
      '[a]palettegen=stats_mode=diff[p];'
      '[b][p]paletteuse=dither=bayer:bayer_scale=3';

  return FfmpegPlan(
    arguments: <String>[
      '-y',
      '-i', inputPath,
      '-filter_complex', filter,
      '-loop', '0',
      outputPath,
    ],
    extension: 'gif',
    mime: 'image/gif',
    kind: MediaKind.image,
  );
}

/// 转换产物先写到这里，再由原生复制进相册。
Future<File> createOutputFile(String inputPath, String extension) async {
  // 放应用支持目录而不是缓存目录：系统清缓存、覆盖安装都不会让历史预览失效。
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}outputs');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final name = inputPath.split(Platform.pathSeparator).last;
  final stem =
      name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
  return File('${dir.path}${Platform.pathSeparator}$stem.$extension');
}
