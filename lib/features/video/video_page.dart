import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/task_queue.dart';
import '../../core/glass_kit.dart';
import '../../core/picked_file.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../shell/root_shell.dart';

enum _VideoMode { compress, remux, extract }

class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key});

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  final List<String> _paths = [];
  _VideoMode _mode = _VideoMode.compress;
  VideoPreset _preset = VideoPreset.balanced;
  VideoResolution _resolution = VideoResolution.p720;
  VideoContainer _container = VideoContainer.mp4;
  AudioFormat _audioFormat = AudioFormat.mp3;
  int _bitrate = 192;
  bool _picking = false;

  static const _bitrates = [128, 192, 256, 320];

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.video);
      final picked = <String>[];
      for (final file in files) {
        final path = await materializePicked(file);
        if (path != null) picked.add(path);
      }
      if (!mounted) return;
      setState(() {
        for (final path in picked) {
          if (!_paths.contains(path)) _paths.add(path);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  TaskSpec _currentSpec() {
    switch (_mode) {
      case _VideoMode.compress:
        return VideoCompressSpec(preset: _preset, resolution: _resolution);
      case _VideoMode.remux:
        return VideoRemuxSpec(container: _container);
      case _VideoMode.extract:
        return ExtractAudioSpec(format: _audioFormat, bitrateKbps: _bitrate);
    }
  }

  void _start() {
    ref.read(taskQueueProvider.notifier).enqueue(
          paths: List.of(_paths),
          spec: _currentSpec(),
        );
    ref.read(selectedTabProvider.notifier).state = 1;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canStart = _paths.isNotEmpty;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const LargeHeader(
            title: '视频',
            subtitle: '压缩、换封装、抽音轨，全部在本机用 FFmpeg 完成',
          ),
          const SizedBox(height: 22),
          SurfaceCard(
            onTap: _picking ? null : _pick,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.insetColor,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _picking
                        ? Icons.hourglass_empty_rounded
                        : Icons.video_library_outlined,
                    size: 21,
                    color: context.accentColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _paths.isEmpty ? '选择视频' : '继续添加',
                        style:
                            AppType.bodyStrong.copyWith(color: context.inkColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'MP4 / MKV / MOV / AVI 都可以读',
                        style:
                            AppType.caption.copyWith(color: context.subInkColor),
                      ),
                    ],
                  ),
                ),
                if (_paths.isNotEmpty)
                  Pill('${_paths.length} 个', color: context.accentColor),
              ],
            ),
          ),
          if (_paths.isNotEmpty) ...[
            const SizedBox(height: 14),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var index = 0; index < _paths.length; index++) ...[
                    if (index > 0)
                      Divider(height: 1, color: context.lineColor, indent: 14),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                      child: Row(
                        children: [
                          Icon(Icons.movie_outlined,
                              size: 18, color: context.subInkColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _paths[index].split(Platform.pathSeparator).last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.footnote
                                  .copyWith(color: context.inkColor),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _paths.removeAt(index)),
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: context.subInkColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          const SectionLabel('要做什么'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Choice(
                label: '压缩',
                selected: _mode == _VideoMode.compress,
                onTap: () => setState(() => _mode = _VideoMode.compress),
              ),
              _Choice(
                label: '转格式',
                selected: _mode == _VideoMode.remux,
                onTap: () => setState(() => _mode = _VideoMode.remux),
              ),
              _Choice(
                label: '提取音频',
                selected: _mode == _VideoMode.extract,
                onTap: () => setState(() => _mode = _VideoMode.extract),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (_mode == _VideoMode.compress) ...[
            const SectionLabel('压缩档位'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final preset in VideoPreset.values)
                  _Choice(
                    label: preset.label,
                    selected: _preset == preset,
                    onTap: () => setState(() => _preset = preset),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionLabel('输出分辨率'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final resolution in VideoResolution.values)
                  _Choice(
                    label: resolution.label,
                    selected: _resolution == resolution,
                    onTap: () => setState(() => _resolution = resolution),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '重新编码为 H.264 + AAC 的 MP4，画质和体积按档位取舍；分辨率只会缩小不会放大。',
              style: AppType.caption.copyWith(color: context.subInkColor),
            ),
          ],
          if (_mode == _VideoMode.remux) ...[
            const SectionLabel('目标格式'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final container in VideoContainer.values)
                  _Choice(
                    label: container.label,
                    selected: _container == container,
                    onTap: () => setState(() => _container = container),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '转封装只换容器，不重新编码，画质和体积基本不变，速度最快。',
              style: AppType.caption.copyWith(color: context.subInkColor),
            ),
          ],
          if (_mode == _VideoMode.extract) ...[
            const SectionLabel('音频格式'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final format in AudioFormat.values)
                  _Choice(
                    label: format.label,
                    selected: _audioFormat == format,
                    onTap: () => setState(() => _audioFormat = format),
                  ),
              ],
            ),
            if (_audioFormat.supportsBitrate) ...[
              const SizedBox(height: 22),
              const SectionLabel('码率'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final bitrate in _bitrates)
                    _Choice(
                      label: '$bitrate kbps',
                      selected: _bitrate == bitrate,
                      onTap: () => setState(() => _bitrate = bitrate),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '会丢掉画面只保留音轨，保存到 Music 目录。',
              style: AppType.caption.copyWith(color: context.subInkColor),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '长视频耗时较长，转换期间请保持应用在前台。',
            style: AppType.caption.copyWith(color: context.subInkColor),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: GlassPrimaryButton(
          label: canStart ? '开始处理 ${_paths.length} 个' : '先选择视频',
          onPressed: canStart ? _start : null,
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: label,
      selected: selected,
      onTap: onTap,
    );
  }
}
