import 'dart:io';

enum MediaKind { image, audio, video }

/// 输出图片格式。jpeg / png / webp / bmp 走原生编码器，gif 走 Dart 侧的动图引擎。
enum TargetFormat { jpeg, png, webp, bmp, gif }

extension TargetFormatX on TargetFormat {
  String get label {
    switch (this) {
      case TargetFormat.jpeg:
        return 'JPG';
      case TargetFormat.png:
        return 'PNG';
      case TargetFormat.webp:
        return 'WEBP';
      case TargetFormat.bmp:
        return 'BMP';
      case TargetFormat.gif:
        return 'GIF';
    }
  }

  String get apiName => name;

  String get extension => this == TargetFormat.jpeg ? 'jpg' : name;

  String get mime {
    switch (this) {
      case TargetFormat.jpeg:
        return 'image/jpeg';
      case TargetFormat.png:
        return 'image/png';
      case TargetFormat.webp:
        return 'image/webp';
      case TargetFormat.bmp:
        return 'image/bmp';
      case TargetFormat.gif:
        return 'image/gif';
    }
  }

  /// 只有 GIF 需要走动图引擎，其余交给原生编码。
  bool get isAnimated => this == TargetFormat.gif;

  bool get supportsQuality =>
      this == TargetFormat.jpeg || this == TargetFormat.webp;
}

enum AudioFormat { mp3, m4a, wav, aac, ogg }

extension AudioFormatX on AudioFormat {
  String get label {
    switch (this) {
      case AudioFormat.mp3:
        return 'MP3';
      case AudioFormat.m4a:
        return 'M4A';
      case AudioFormat.wav:
        return 'WAV';
      case AudioFormat.aac:
        return 'AAC';
      case AudioFormat.ogg:
        return 'OGG';
    }
  }

  String get extension => name;

  String get mime {
    switch (this) {
      case AudioFormat.mp3:
        return 'audio/mpeg';
      case AudioFormat.m4a:
        return 'audio/mp4';
      case AudioFormat.wav:
        return 'audio/wav';
      case AudioFormat.aac:
        return 'audio/aac';
      case AudioFormat.ogg:
        return 'audio/ogg';
    }
  }

  String get codec {
    switch (this) {
      case AudioFormat.mp3:
        return 'libmp3lame';
      case AudioFormat.m4a:
      case AudioFormat.aac:
        return 'aac';
      case AudioFormat.wav:
        return 'pcm_s16le';
      case AudioFormat.ogg:
        return 'libvorbis';
    }
  }

  bool get supportsBitrate => this != AudioFormat.wav;
}

enum VideoContainer { mp4, mkv, mov }

extension VideoContainerX on VideoContainer {
  String get label => name.toUpperCase();

  String get extension => name;

  String get mime => 'video/mp4';
}

enum VideoPreset { high, balanced, small }

extension VideoPresetX on VideoPreset {
  String get label {
    switch (this) {
      case VideoPreset.high:
        return '高质量';
      case VideoPreset.balanced:
        return '均衡';
      case VideoPreset.small:
        return '小体积';
    }
  }

  /// x264 的 CRF：数值越小越清晰、文件越大。
  int get crf {
    switch (this) {
      case VideoPreset.high:
        return 20;
      case VideoPreset.balanced:
        return 24;
      case VideoPreset.small:
        return 29;
    }
  }
}

enum VideoResolution { original, p1080, p720, p480 }

extension VideoResolutionX on VideoResolution {
  String get label {
    switch (this) {
      case VideoResolution.original:
        return '原分辨率';
      case VideoResolution.p1080:
        return '1080p';
      case VideoResolution.p720:
        return '720p';
      case VideoResolution.p480:
        return '480p';
    }
  }

  /// 长边上限，0 表示不缩放。
  int get maxEdge {
    switch (this) {
      case VideoResolution.original:
        return 0;
      case VideoResolution.p1080:
        return 1920;
      case VideoResolution.p720:
        return 1280;
      case VideoResolution.p480:
        return 854;
    }
  }
}

/// 一条任务的转换参数。用密封类区分图片 / 音频 / 视频，队列里按类型分流。
sealed class TaskSpec {
  const TaskSpec();

  MediaKind get kind;

  /// 任务列表里显示的短标签，例如 JPG、MP3、MP4 压缩。
  String get badge;

  String get extension;

  String get mime;

  Map<String, dynamic> toJson();

  static TaskSpec fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'audio':
        return AudioConvertSpec(
          format: AudioFormat.values.firstWhere(
            (value) => value.name == json['format'],
            orElse: () => AudioFormat.mp3,
          ),
          bitrateKbps: json['bitrateKbps'] as int? ?? 192,
        );
      case 'extractAudio':
        return ExtractAudioSpec(
          format: AudioFormat.values.firstWhere(
            (value) => value.name == json['format'],
            orElse: () => AudioFormat.mp3,
          ),
          bitrateKbps: json['bitrateKbps'] as int? ?? 192,
        );
      case 'videoCompress':
        return VideoCompressSpec(
          preset: VideoPreset.values.firstWhere(
            (value) => value.name == json['preset'],
            orElse: () => VideoPreset.balanced,
          ),
          resolution: VideoResolution.values.firstWhere(
            (value) => value.name == json['resolution'],
            orElse: () => VideoResolution.p720,
          ),
        );
      case 'videoRemux':
        return VideoRemuxSpec(
          container: VideoContainer.values.firstWhere(
            (value) => value.name == json['container'],
            orElse: () => VideoContainer.mp4,
          ),
        );
      default:
        return ImageSpec(
          format: TargetFormat.values.firstWhere(
            (value) => value.name == json['format'],
            orElse: () => TargetFormat.jpeg,
          ),
          width: json['width'] as int? ?? 0,
          height: json['height'] as int? ?? 0,
          quality: json['quality'] as int? ?? 92,
        );
    }
  }
}

class ImageSpec extends TaskSpec {
  const ImageSpec({
    this.format = TargetFormat.jpeg,
    this.width = 0,
    this.height = 0,
    this.quality = 92,
  });

  final TargetFormat format;

  /// 0 表示自动：都为 0 保持原尺寸，只填一个按原比例推算。
  final int width;
  final int height;
  final int quality;

  @override
  MediaKind get kind => MediaKind.image;

  @override
  String get badge => format.label;

  @override
  String get extension => format.extension;

  @override
  String get mime => format.mime;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image',
        'format': format.name,
        'width': width,
        'height': height,
        'quality': quality,
      };
}

class AudioConvertSpec extends TaskSpec {
  const AudioConvertSpec({
    this.format = AudioFormat.mp3,
    this.bitrateKbps = 192,
  });

  final AudioFormat format;
  final int bitrateKbps;

  @override
  MediaKind get kind => MediaKind.audio;

  @override
  String get badge => format.label;

  @override
  String get extension => format.extension;

  @override
  String get mime => format.mime;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'audio',
        'format': format.name,
        'bitrateKbps': bitrateKbps,
      };
}

class ExtractAudioSpec extends TaskSpec {
  const ExtractAudioSpec({
    this.format = AudioFormat.mp3,
    this.bitrateKbps = 192,
  });

  final AudioFormat format;
  final int bitrateKbps;

  @override
  MediaKind get kind => MediaKind.audio;

  @override
  String get badge => '${format.label}（提取）';

  @override
  String get extension => format.extension;

  @override
  String get mime => format.mime;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'extractAudio',
        'format': format.name,
        'bitrateKbps': bitrateKbps,
      };
}

class VideoCompressSpec extends TaskSpec {
  const VideoCompressSpec({
    this.preset = VideoPreset.balanced,
    this.resolution = VideoResolution.p720,
  });

  final VideoPreset preset;
  final VideoResolution resolution;

  @override
  MediaKind get kind => MediaKind.video;

  @override
  String get badge => 'MP4 · ${preset.label}';

  @override
  String get extension => 'mp4';

  @override
  String get mime => 'video/mp4';

  @override
  Map<String, dynamic> toJson() => {
        'type': 'videoCompress',
        'preset': preset.name,
        'resolution': resolution.name,
      };
}

class VideoRemuxSpec extends TaskSpec {
  const VideoRemuxSpec({this.container = VideoContainer.mp4});

  final VideoContainer container;

  @override
  MediaKind get kind => MediaKind.video;

  @override
  String get badge => '${container.label} · 转封装';

  @override
  String get extension => container.extension;

  @override
  String get mime => container.mime;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'videoRemux',
        'container': container.name,
      };
}

enum TaskStatus { pending, running, done, failed }

extension TaskStatusX on TaskStatus {
  bool get isFinished => this == TaskStatus.done || this == TaskStatus.failed;
}

/// 一条转换任务。字段可变，队列只负责整体替换状态列表来触发刷新。
class ConvertTask {
  ConvertTask({
    required this.id,
    required this.sourcePath,
    required this.sourceName,
    required this.sourceBytes,
    required this.spec,
    required this.createdAt,
    this.status = TaskStatus.pending,
    this.progress = 0,
  });

  final String id;
  final String sourcePath;
  final String sourceName;
  final int sourceBytes;
  final TaskSpec spec;
  final DateTime createdAt;

  TaskStatus status;
  double progress;
  String? outputPath;
  String? outputUri;
  int? outputBytes;
  int? outputWidth;
  int? outputHeight;
  String? error;
  DateTime? finishedAt;

  MediaKind get kind => spec.kind;

  String get sourceFormat => sourceName.contains('.')
      ? sourceName.split('.').last.toUpperCase()
      : '未知';

  File get sourceFile => File(sourcePath);

  static String idFor(String path) =>
      '${DateTime.now().microsecondsSinceEpoch}_${path.hashCode}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'sourceName': sourceName,
        'sourceBytes': sourceBytes,
        'spec': spec.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'progress': progress,
        'outputPath': outputPath,
        'outputUri': outputUri,
        'outputBytes': outputBytes,
        'outputWidth': outputWidth,
        'outputHeight': outputHeight,
        'error': error,
        'finishedAt': finishedAt?.toIso8601String(),
      };

  factory ConvertTask.fromJson(Map<String, dynamic> json) {
    final task = ConvertTask(
      id: json['id'] as String,
      sourcePath: json['sourcePath'] as String,
      sourceName: json['sourceName'] as String,
      sourceBytes: json['sourceBytes'] as int? ?? 0,
      spec: TaskSpec.fromJson(
        (json['spec'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
    task
      ..status = TaskStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => TaskStatus.done,
      )
      ..progress = (json['progress'] as num?)?.toDouble() ?? 1
      ..outputPath = json['outputPath'] as String?
      ..outputUri = json['outputUri'] as String?
      ..outputBytes = json['outputBytes'] as int?
      ..outputWidth = json['outputWidth'] as int?
      ..outputHeight = json['outputHeight'] as int?
      ..error = json['error'] as String?
      ..finishedAt = DateTime.tryParse(json['finishedAt'] as String? ?? '');
    return task;
  }
}
