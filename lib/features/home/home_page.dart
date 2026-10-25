import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/task_queue.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../image/image_page.dart';
import '../audio/audio_page.dart';
import '../video/video_page.dart';
import '../preview/preview_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskQueueProvider);
    final recent = tasks
        .where((task) => task.status == TaskStatus.done)
        .take(3)
        .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          const LargeHeader(
            title: '格式坊',
            subtitle: '图片与视频转换，全部在这台手机上完成',
            trailing: Pill('纯本地'),
          ),
          const SizedBox(height: 26),
          _EntryCard(
            icon: Icons.photo_library_outlined,
            title: '图片',
            subtitle: 'HEIC · JPG · PNG · WEBP · BMP · GIF',
            footer: '批量转换 · 自定义宽高 · 动图转 GIF · 自动存入相册',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ImagePage()),
            ),
          ),
          const SizedBox(height: 12),
          _EntryCard(
            icon: Icons.audiotrack_rounded,
            title: '音频',
            subtitle: 'MP3 · M4A · WAV · AAC 互转',
            footer: '从音频文件或视频音轨提取',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AudioPage()),
            ),
          ),
          const SizedBox(height: 12),
          _EntryCard(
            icon: Icons.movie_creation_outlined,
            title: '视频',
            subtitle: '压缩 · 转格式 · 提取音频',
            footer: 'FFmpeg 引擎 · 转封装不损画质',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const VideoPage()),
            ),
          ),
          const SizedBox(height: 30),
          const SectionLabel('最近完成'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: recent.isEmpty
                ? const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: '还没有转换记录',
                    message: '从上面的入口选几张图片试试，结果会自动出现在这里',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < recent.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: context.lineColor, indent: 74),
                        _RecentRow(
                          task: recent[i],
                          onTap: () => Navigator.of(context)
                              .push(PreviewPage.route(recent[i])),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String footer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.insetColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: context.accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppType.title.copyWith(color: context.inkColor),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppType.footnote.copyWith(color: context.subInkColor),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: context.subInkColor.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: context.lineColor),
          const SizedBox(height: 12),
          Text(
            footer,
            style: AppType.caption.copyWith(color: context.subInkColor),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.task, required this.onTap});

  final ConvertTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outputPath = task.outputPath;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 46,
              height: 46,
              child: task.kind != MediaKind.image
                  ? Container(
                      color: context.insetColor,
                      child: Icon(
                        task.kind == MediaKind.audio
                            ? Icons.audiotrack_rounded
                            : Icons.movie_outlined,
                        size: 20,
                        color: context.subInkColor,
                      ),
                    )
                  : outputPath != null
                      ? Image.file(
                          File(outputPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(context),
                        )
                      : _placeholder(context),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: context.inkColor),
                ),
                const SizedBox(height: 3),
                Text(
                  '${task.sourceFormat} → ${task.spec.badge} · ${formatDelta(task.sourceBytes, task.outputBytes ?? 0)}',
                  style: AppType.caption.copyWith(color: context.subInkColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoment(task.finishedAt ?? task.createdAt),
            style: AppType.caption.copyWith(color: context.subInkColor),
          ),
        ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: context.insetColor,
      child: Icon(
        Icons.image_outlined,
        size: 20,
        color: context.subInkColor.withValues(alpha: 0.7),
      ),
    );
  }
}
