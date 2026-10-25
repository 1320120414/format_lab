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

class AudioPage extends ConsumerStatefulWidget {
  const AudioPage({super.key});

  @override
  ConsumerState<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends ConsumerState<AudioPage> {
  final List<String> _paths = [];
  AudioFormat _format = AudioFormat.mp3;
  int _bitrate = 192;
  bool _picking = false;

  static const _bitrates = [128, 192, 256, 320];

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
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

  void _start() {
    ref.read(taskQueueProvider.notifier).enqueue(
          paths: List.of(_paths),
          spec: AudioConvertSpec(format: _format, bitrateKbps: _bitrate),
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
            title: '音频',
            subtitle: '音频之间互转；想从视频里取音轨，去「视频」页选提取',
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
                        : Icons.library_music_outlined,
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
                        _paths.isEmpty ? '选择音频' : '继续添加',
                        style:
                            AppType.bodyStrong.copyWith(color: context.inkColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'MP3 / M4A / WAV / AAC / FLAC 都可以读',
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
                          Icon(Icons.audiotrack_rounded,
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
          const SectionLabel('输出格式'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final format in AudioFormat.values)
                _Choice(
                  label: format.label,
                  selected: _format == format,
                  onTap: () => setState(() => _format = format),
                ),
            ],
          ),
          if (_format.supportsBitrate) ...[
            const SizedBox(height: 24),
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
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'WAV 是无损 PCM，不设码率，文件会比 MP3 大很多。',
              style: AppType.caption.copyWith(color: context.subInkColor),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '结果保存到相册的 Music 目录下，文件夹在「设置」里改。',
            style: AppType.caption.copyWith(color: context.subInkColor),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: GlassPrimaryButton(
          label: canStart ? '开始转换 ${_paths.length} 个' : '先选择音频',
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
