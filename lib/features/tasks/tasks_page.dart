import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/task_queue.dart';
import '../../core/format.dart';
import '../../core/glass_kit.dart';
import '../../core/share_target.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../preview/preview_page.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  int _segment = 0;

  Future<void> _share(ConvertTask task) async {
    final path = task.outputPath;
    if (path == null) return;
    try {
      await shareFile(path: path, text: task.sourceName);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskQueueProvider);
    final active = tasks
        .where((task) =>
            task.status == TaskStatus.pending || task.status == TaskStatus.running)
        .toList();
    final finished =
        tasks.where((task) => task.status.isFinished).toList();
    final list = _segment == 0 ? active : finished;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          LargeHeader(
            title: '任务',
            subtitle: active.isEmpty ? '当前没有正在转换的文件' : '${active.length} 个任务正在处理',
          ),
          const SizedBox(height: 20),
          AppSegmented(
            labels: const ['进行中', '已完成'],
            selectedIndex: _segment,
            onSelected: (value) => setState(() => _segment = value),
          ),
          const SizedBox(height: 18),
          if (list.isEmpty)
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: EmptyState(
                icon: _segment == 0
                    ? Icons.hourglass_empty_rounded
                    : Icons.inbox_outlined,
                title: _segment == 0 ? '没有排队中的任务' : '还没有完成记录',
                message: _segment == 0
                    ? '去首页选一批图片，任务会出现在这里'
                    : '转换成功后，文件信息和体积对比会保留在这里',
              ),
            )
          else
            for (final task in list) ...[
              _TaskCard(
                task: task,
                onShare: () => _share(task),
                onRetry: () =>
                    ref.read(taskQueueProvider.notifier).retry(task),
                onOpen: task.status == TaskStatus.done && task.outputPath != null
                    ? () => Navigator.of(context).push(
                          PreviewPage.route(task),
                        )
                    : null,
              ),
              const SizedBox(height: 10),
            ],
          if (_segment == 1 && finished.isNotEmpty) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(taskQueueProvider.notifier).clearFinished(),
                child: const Text('清除已完成记录'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onShare,
    required this.onRetry,
    this.onOpen,
  });

  final ConvertTask task;
  final VoidCallback onShare;
  final VoidCallback onRetry;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 50,
              height: 50,
              child: _thumb(context),
            ),
          ),
          const SizedBox(width: 13),
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
                const SizedBox(height: 4),
                _statusLine(context),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _trailing(context),
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    if (task.kind != MediaKind.image) {
      return Container(
        color: context.insetColor,
        child: Icon(
          task.kind == MediaKind.audio
              ? Icons.audiotrack_rounded
              : Icons.movie_outlined,
          size: 20,
          color: context.subInkColor,
        ),
      );
    }
    final path = task.outputPath ?? task.sourcePath;
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: context.insetColor,
        child: Icon(
          Icons.image_outlined,
          size: 20,
          color: context.subInkColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _statusLine(BuildContext context) {
    switch (task.status) {
      case TaskStatus.pending:
        return Text(
          '${task.sourceFormat} → ${task.spec.badge} · 排队中',
          style: AppType.caption.copyWith(color: context.subInkColor),
        );
      case TaskStatus.running:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${task.sourceFormat} → ${task.spec.badge} · 转换中',
              style: AppType.caption.copyWith(color: context.subInkColor),
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: task.progress <= 0.15 ? null : task.progress,
                minHeight: 5,
                backgroundColor: context.insetColor,
                color: AppPalette.accent,
              ),
            ),
          ],
        );
      case TaskStatus.done:
        final percent = savingsPercent(task.sourceBytes, task.outputBytes ?? 0);
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${task.sourceFormat} → ${task.spec.badge} · '
              '${formatDelta(task.sourceBytes, task.outputBytes ?? 0)}',
              style: AppType.caption.copyWith(color: context.subInkColor),
            ),
            if (percent > 0)
              Pill('-$percent%', color: AppPalette.success)
            else if (percent < 0)
              Pill('+${percent.abs()}%', color: AppPalette.warning),
          ],
        );
      case TaskStatus.failed:
        return Text(
          task.error ?? '转换失败',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption.copyWith(color: AppPalette.danger),
        );
    }
  }

  Widget _trailing(BuildContext context) {
    switch (task.status) {
      case TaskStatus.done:
        return IconButton(
          onPressed: onShare,
          icon: Icon(
            Icons.ios_share_rounded,
            size: 19,
            color: context.subInkColor,
          ),
        );
      case TaskStatus.failed:
        return TextButton(
          onPressed: onRetry,
          child: const Text('重试'),
        );
      default:
        return const SizedBox(width: 8);
    }
  }
}
