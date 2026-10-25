import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../infrastructure/animation_engine.dart';
import '../infrastructure/ffmpeg_engine.dart';
import '../infrastructure/history_store.dart';
import '../infrastructure/image_engine.dart';
import '../infrastructure/motion_photo.dart';
import 'settings_controller.dart';

final imageEngineProvider = Provider<ImageEngine>((ref) => ImageEngine());

final animationEngineProvider =
    Provider<AnimationEngine>((ref) => AnimationEngine());

final ffmpegEngineProvider = Provider<FfmpegEngine>((ref) => FfmpegEngine());

final ffmpegVersionProvider = FutureProvider<String?>(
  (ref) => ref.read(ffmpegEngineProvider).version(),
);

final historyStoreProvider = Provider<HistoryStore>((ref) => HistoryStore());

final taskQueueProvider =
    NotifierProvider<TaskQueue, List<ConvertTask>>(TaskQueue.new);

/// 队列只做三件事：排队、串行跑、把结果落盘。
/// 图片走原生/动图引擎，音视频走 FFmpeg；串行执行避开内存和 CPU 抢占。
class TaskQueue extends Notifier<List<ConvertTask>> {
  bool _pumping = false;

  @override
  List<ConvertTask> build() {
    _restore();
    return const [];
  }

  Future<void> _restore() async {
    final saved = await ref.read(historyStoreProvider).load();
    if (saved.isEmpty) return;
    state = saved;
  }

  List<ConvertTask> get active =>
      state.where((task) => !task.status.isFinished).toList();

  List<ConvertTask> get finished =>
      state.where((task) => task.status.isFinished).toList();

  void enqueue({
    required List<String> paths,
    required TaskSpec spec,
  }) {
    if (paths.isEmpty) return;
    final now = DateTime.now();
    final created = <ConvertTask>[];

    for (final path in paths) {
      final file = File(path);
      int size = 0;
      try {
        size = file.lengthSync();
      } catch (_) {
        size = 0;
      }
      created.add(
        ConvertTask(
          id: ConvertTask.idFor(path),
          sourcePath: path,
          sourceName: path.split(Platform.pathSeparator).last,
          sourceBytes: size,
          spec: spec,
          createdAt: now,
        ),
      );
    }

    state = [...created, ...state];
    _pump();
  }

  void retry(ConvertTask task) {
    _mutate(() {
      task
        ..status = TaskStatus.pending
        ..progress = 0
        ..error = null;
    });
    _pump();
  }

  void clearFinished() {
    state = state.where((task) => !task.status.isFinished).toList();
    ref.read(historyStoreProvider).save(state);
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (true) {
        final index =
            state.indexWhere((task) => task.status == TaskStatus.pending);
        if (index < 0) break;

        final task = state[index];
        _mutate(() {
          task
            ..status = TaskStatus.running
            ..progress = 0.05;
        });

        try {
          switch (task.spec) {
            case ImageSpec(:final format):
              if (format.isAnimated) {
                await _runGif(task, format);
              } else {
                await _runImage(task, format);
              }
            case AudioConvertSpec():
            case ExtractAudioSpec():
            case VideoCompressSpec():
            case VideoRemuxSpec():
              await _runFfmpeg(task);
          }
        } catch (error) {
          _mutate(() {
            task
              ..status = TaskStatus.failed
              ..progress = 1
              ..error = error.toString().replaceFirst('Exception: ', '')
              ..finishedAt = DateTime.now();
          });
        }

        await ref.read(historyStoreProvider).save(state);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _runImage(ConvertTask task, TargetFormat format) async {
    final spec = task.spec as ImageSpec;
    final result = await ref.read(imageEngineProvider).convert(
          inputPath: task.sourcePath,
          format: format,
          width: spec.width,
          height: spec.height,
          quality: spec.quality,
          folder: _folder,
        );
    _complete(
      task,
      path: result.path,
      uri: result.uri,
      bytes: result.bytes,
      width: result.width,
      height: result.height,
    );
  }

  Future<void> _runGif(ConvertTask task, TargetFormat format) async {
    final spec = task.spec as ImageSpec;

    // 实况照片＝静态图 + 尾部一段视频。直接按图片解码只会拿到一帧，
    // 所以先抽出内嵌视频，交给 FFmpeg 转 GIF。
    final embedded = await _embeddedVideo(task.sourcePath);
    if (embedded != null) {
      try {
        await _videoToGif(task, embedded, spec);
        return;
      } finally {
        await _deleteQuietly(embedded);
      }
    }

    final gif = await ref.read(animationEngineProvider).toGif(
          inputPath: task.sourcePath,
          width: spec.width,
          height: spec.height,
        );
    final uri = await ref.read(imageEngineProvider).saveMedia(
          path: gif.path,
          displayName: _outputName(task, 'gif'),
          mime: format.mime,
          kind: MediaKind.image,
          folder: _folder,
        );
    _complete(
      task,
      path: gif.path,
      uri: uri,
      bytes: gif.bytes,
      width: gif.width,
      height: gif.height,
    );
  }

  Future<void> _videoToGif(
    ConvertTask task,
    String videoPath,
    ImageSpec spec,
  ) async {
    final engine = ref.read(ffmpegEngineProvider);
    final info = await engine.probe(videoPath);

    final output = await createOutputFile(task.sourcePath, 'gif');
    if (await output.exists()) {
      await output.delete();
    }

    final plan = planGifFromVideo(
      inputPath: videoPath,
      outputPath: output.path,
      width: spec.width,
      height: spec.height,
    );

    await engine.run(
      plan.arguments,
      duration: info.duration,
      onProgress: (progress) {
        _mutate(() => task.progress = progress);
      },
    );

    if (!await output.exists() || await output.length() == 0) {
      throw Exception('没有生成 GIF');
    }

    final uri = await ref.read(imageEngineProvider).saveMedia(
          path: output.path,
          displayName: _outputName(task, 'gif'),
          mime: plan.mime,
          kind: MediaKind.image,
          folder: _folder,
        );

    _complete(
      task,
      path: output.path,
      uri: uri,
      bytes: await output.length(),
    );
  }

  /// 只有确认内含视频轨才返回临时文件路径，避免把普通照片误判成实况。
  Future<String?> _embeddedVideo(String sourcePath) async {
    final embedded = await MotionPhoto.extractVideo(sourcePath);
    if (embedded == null) return null;
    try {
      final info = await ref.read(ffmpegEngineProvider).probe(embedded);
      if (info.hasVideo) return embedded;
    } catch (_) {
      // 抽出来的不是有效视频，按普通图片处理。
    }
    await _deleteQuietly(embedded);
    return null;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // 删不掉也无所谓，系统会回收缓存目录。
    }
  }

  Future<void> _runFfmpeg(ConvertTask task) async {
    final engine = ref.read(ffmpegEngineProvider);

    // 实况照片的画面和声音都在尾部视频里，换成内嵌视频再处理。
    final embedded = await _embeddedVideo(task.sourcePath);
    final inputPath = embedded ?? task.sourcePath;

    try {
      final info = await engine.probe(inputPath);

      if (task.spec is ExtractAudioSpec && !info.hasAudio) {
        throw Exception('这个文件里没有音轨');
      }

      final output = await createOutputFile(task.sourcePath, task.spec.extension);
      if (await output.exists()) {
        await output.delete();
      }

      final plan = planFor(
        task.spec,
        inputPath: inputPath,
        outputPath: output.path,
      );

      await engine.run(
        plan.arguments,
        duration: info.duration,
        onProgress: (progress) {
          _mutate(() => task.progress = progress);
        },
      );

      if (!await output.exists() || await output.length() == 0) {
        throw Exception('没有生成输出文件');
      }

      final uri = await ref.read(imageEngineProvider).saveMedia(
            path: output.path,
            displayName: _outputName(task, plan.extension),
            mime: plan.mime,
            kind: plan.kind,
            folder: _folder,
          );

      _complete(
        task,
        path: output.path,
        uri: uri,
        bytes: await output.length(),
      );
    } finally {
      if (embedded != null) {
        await _deleteQuietly(embedded);
      }
    }
  }

  void _complete(
    ConvertTask task, {
    required String path,
    required String uri,
    required int bytes,
    int? width,
    int? height,
  }) {
    _mutate(() {
      task
        ..status = TaskStatus.done
        ..progress = 1
        ..outputPath = path
        ..outputUri = uri
        ..outputBytes = bytes
        ..outputWidth = width
        ..outputHeight = height
        ..finishedAt = DateTime.now();
    });
  }

  String get _folder => ref.read(settingsProvider).outputFolder;

  String _outputName(ConvertTask task, String extension) {
    final name = task.sourceName;
    final stem =
        name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    return '$stem.$extension';
  }

  void _mutate(void Function() change) {
    change();
    state = [...state];
  }
}
