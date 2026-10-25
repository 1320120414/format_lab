import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings_controller.dart';
import '../../application/task_queue.dart';
import '../../core/glass_kit.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../infrastructure/desktop_paths.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _editFolder(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).outputFolder;
    final controller = TextEditingController(text: current);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.cardColor,
        title: Text(
          '输出目录',
          style: AppType.headline.copyWith(color: dialogContext.inkColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: controller,
              autofocus: true,
              placeholder: 'FormatLab',
              textStyle: AppType.body.copyWith(color: dialogContext.inkColor),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
            const SizedBox(height: 12),
            Text(
              isDesktopPlatform
                  ? '图片存到「图片」文件夹，视频存到「视频」，音频存到「音乐」，'
                      '都在各自的 <目录> 子文件夹里。'
                  : '图片存到 Pictures/<目录>，视频存到 Movies/<目录>，音频存到 Music/<目录>。',
              style: AppType.caption.copyWith(color: dialogContext.subInkColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null) {
      await ref.read(settingsProvider.notifier).setOutputFolder(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ffmpeg = ref.watch(ffmpegVersionProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          const LargeHeader(
            title: '设置',
            subtitle: '输出位置和引擎状态都在这里',
          ),
          const SizedBox(height: 24),
          const SectionLabel('外观'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '主题',
                        style: AppType.body.copyWith(color: context.inkColor),
                      ),
                      const SizedBox(height: 10),
                      AppSegmented(
                        labels: const ['跟随系统', '浅色', '深色'],
                        selectedIndex: _themeIndex(settings.themeMode),
                        onSelected: (i) => ref
                            .read(settingsProvider.notifier)
                            .setThemeMode(_themeModes[i]),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.lineColor, indent: 16),
                _SwitchRow(
                  title: '液态玻璃',
                  subtitle: '半透明模糊的毛玻璃质感，关掉就是纯色卡片',
                  value: settings.glass,
                  onChanged: (enabled) =>
                      ref.read(settingsProvider.notifier).setGlass(enabled),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('输出'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(
                  label: '输出目录',
                  value: settings.outputFolder,
                  badge: '编辑',
                  badgeColor: context.accentColor,
                  onTap: () => _editFolder(context, ref),
                ),
                Divider(height: 1, color: context.lineColor, indent: 16),
                _InfoRow(label: '命名规则', value: '原名.输出格式'),
                Divider(height: 1, color: context.lineColor, indent: 16),
                _InfoRow(label: '覆盖同名文件', value: '自动加序号'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('引擎'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(
                  label: '图片引擎',
                  value: isDesktopPlatform
                      ? 'Dart · JPG / PNG / WEBP / BMP'
                      : '原生 · JPG / PNG / WEBP / BMP',
                  badge: '就绪',
                  badgeColor: AppPalette.success,
                ),
                Divider(height: 1, color: context.lineColor, indent: 16),
                _InfoRow(
                  label: '动图引擎',
                  value: '逐帧解码 · 重编码 GIF',
                  badge: '就绪',
                  badgeColor: AppPalette.success,
                ),
                Divider(height: 1, color: context.lineColor, indent: 16),
                _InfoRow(
                  label: '音视频引擎',
                  value: ffmpeg.when(
                    data: (version) => version == null
                        ? 'FFmpeg 不可用'
                        : 'FFmpeg ${version.split('-').first}',
                    loading: () => '正在检测…',
                    error: (_, _) => 'FFmpeg 不可用',
                  ),
                  badge: ffmpeg.hasValue && ffmpeg.value != null ? '就绪' : '检测中',
                  badgeColor: ffmpeg.hasValue && ffmpeg.value != null
                      ? AppPalette.success
                      : AppPalette.warning,
                ),
                Divider(height: 1, color: context.lineColor, indent: 16),
                _InfoRow(
                  label: '文档引擎',
                  value: '本阶段不做',
                  badge: '未实现',
                  badgeColor: context.subInkColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('关于'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _InfoRow(label: '版本', value: '0.1.0 (1)'),
                Divider(height: 1, color: context.lineColor, indent: 16),
                _InfoRow(label: '网络', value: '转换全程不联网'),
                Divider(height: 1, color: context.lineColor, indent: 16),
                _InfoRow(
                  label: isDesktopPlatform ? '保存位置' : '相册权限',
                  value: isDesktopPlatform
                      ? '本机 图片 / 视频 / 音乐 文件夹'
                      : 'Android 10+ 免权限写入',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '所有转换都在本机完成，文件不会上传到任何服务器。',
            textAlign: TextAlign.center,
            style: AppType.caption.copyWith(color: context.subInkColor),
          ),
        ],
      ),
    );
  }
}

const _themeModes = ['system', 'light', 'dark'];

int _themeIndex(String mode) => switch (mode) {
      'light' => 1,
      'dark' => 2,
      _ => 0,
    };

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.body.copyWith(color: context.inkColor)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppType.caption.copyWith(color: context.subInkColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppPalette.accent,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.badge,
    this.badgeColor,
    this.onTap,
  });

  final String label;
  final String value;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: AppType.footnote.copyWith(color: context.subInkColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppType.footnote.copyWith(color: context.inkColor),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Pill(badge!, color: badgeColor),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      child: content,
    );
  }
}
