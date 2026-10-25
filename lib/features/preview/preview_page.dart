import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:video_player/video_player.dart';

import '../../core/format.dart';
import '../../core/share_target.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../../infrastructure/desktop_paths.dart';

/// 转换结果预览：图片可缩放，视频和音频可在应用内直接播放。
class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key, required this.task});

  final ConvertTask task;

  static Route<void> route(ConvertTask task) => MaterialPageRoute<void>(
        builder: (_) => PreviewPage(task: task),
      );

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  VideoPlayerController? _video;
  AudioPlayer? _audio;
  bool _loading = true;
  String? _error;

  String? get _path => widget.task.outputPath;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final path = _path;
    if (path == null || !File(path).existsSync()) {
      setState(() {
        _loading = false;
        _error = '文件已不在本地缓存里，可以到相册中查看原件';
      });
      return;
    }

    try {
      switch (widget.task.kind) {
        case MediaKind.image:
          break;
        case MediaKind.video:
          final controller = VideoPlayerController.file(File(path));
          await controller.initialize();
          await controller.setLooping(true);
          _video = controller;
        case MediaKind.audio:
          // 桌面端没有可用的 just_audio 实现，改成「用系统播放器打开」。
          if (isDesktopPlatform) {
            if (!mounted) return;
            setState(() => _loading = false);
            return;
          }

          // 不申请音频焦点的话，MIUI 等系统会把播放静音，表现为「在走但没声音」。
          final session = await AudioSession.instance;
          await session.configure(const AudioSessionConfiguration.music());
          await session.setActive(true);

          final player = AudioPlayer();
          player.playbackEventStream.listen(
            (_) {},
            onError: (Object error, StackTrace _) {
              if (mounted) {
                setState(() => _error = '播放失败：$error');
              }
            },
          );
          await player.setFilePath(path);
          await player.setVolume(1);
          _audio = player;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '无法打开这个文件：$error';
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _audio?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final path = _path;
    if (path == null) return;
    try {
      await shareFile(path: path, text: widget.task.sourceName);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return lgw.GlassPage(
      // 预览区压暗，玻璃控件才有明暗层次可折射
      background: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackground(),
          Container(color: Colors.black.withValues(alpha: 0.62)),
        ],
      ),
      settings: glassSettings,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leadingWidth: 62,
          leading: Center(
            child: lgw.GlassButton(
              onTap: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              iconSize: 18,
              iconColor: Colors.white,
              width: 40,
              height: 40,
              stretch: 0.15,
            ),
          ),
          titleSpacing: 2,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.sourceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.footnote.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${task.spec.badge} · ${formatDelta(task.sourceBytes, task.outputBytes ?? 0)}',
                style: AppType.caption.copyWith(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            if (_path != null) ...[
              Center(
                child: lgw.GlassButton(
                  onTap: _share,
                  icon: const Icon(Icons.ios_share_rounded),
                  iconSize: 18,
                  iconColor: Colors.white,
                  width: 40,
                  height: 40,
                  stretch: 0.15,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 30, color: Colors.white38),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppType.footnote.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    switch (widget.task.kind) {
      case MediaKind.image:
        return _buildImage();
      case MediaKind.video:
        return _buildVideo();
      case MediaKind.audio:
        if (isDesktopPlatform) return _buildDesktopAudio();
        return _buildAudio();
    }
  }

  /// 桌面端不做应用内播放，给个入口交给系统播放器。
  Widget _buildDesktopAudio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: lgw.GlassContainer.card(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
          shape: lgw.LiquidRoundedSuperellipse(borderRadius: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.audiotrack_rounded,
                  size: 46, color: Colors.white70),
              const SizedBox(height: 18),
              Text(
                widget.task.sourceName,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: AppType.bodyStrong.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.task.spec.badge} · '
                '${formatBytes(widget.task.outputBytes ?? 0)}',
                style: AppType.caption.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 22),
              lgw.GlassButton.custom(
                onTap: _openExternally,
                width: 208,
                height: 44,
                stretch: 0.15,
                shape: lgw.LiquidRoundedSuperellipse(borderRadius: 16),
                child: Text(
                  '用系统播放器打开',
                  style: AppType.footnote.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '桌面版暂不支持应用内试听',
                style: AppType.caption.copyWith(color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openExternally() async {
    final path = _path;
    if (path == null) return;
    try {
      await Process.start(
        'explorer.exe',
        [path],
        mode: ProcessStartMode.detached,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败：$error')),
      );
    }
  }

  Widget _buildImage() {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.file(
          File(_path!),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Text(
            '图片无法显示',
            style: AppType.footnote.copyWith(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _video!;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              // 播放状态存在 controller 里，不监听就永远停在"暂停"那一帧的
              // 界面，中间的大播放按钮也就一直挂着。
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(controller),
                      if (!value.isPlaying)
                        _PlayBadge(onTap: controller.play),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        _VideoControls(controller: controller),
      ],
    );
  }

  Widget _buildAudio() {
    final player = _audio!;
    final total = player.duration ?? Duration.zero;

    return Column(
      children: [
        const Spacer(),
        lgw.GlassContainer.card(
          padding: const EdgeInsets.all(22),
          shape: lgw.LiquidRoundedSuperellipse(borderRadius: 28),
          child: const Icon(Icons.audiotrack_rounded,
              size: 48, color: Colors.white70),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            widget.task.sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.bodyStrong.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.task.spec.badge} · ${formatBytes(widget.task.outputBytes ?? 0)}',
          style: AppType.caption.copyWith(color: Colors.white54),
        ),
        const Spacer(),
        StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final max = total.inMilliseconds.toDouble();
            final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  lgw.GlassSlider(
                    value: max <= 0 ? 0 : value,
                    max: max <= 0 ? 1 : max,
                    onChanged: (next) =>
                        player.seek(Duration(milliseconds: next.round())),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    thumbColor: Colors.white,
                    trackHeight: 3,
                    thumbRadius: 8,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_clock(position),
                            style: AppType.caption
                                .copyWith(color: Colors.white54)),
                        Text(_clock(total),
                            style: AppType.caption
                                .copyWith(color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playing = snapshot.data?.playing ?? false;
            return _PlayBadge(
              size: 60,
              onTap: () => playing ? player.pause() : player.play(),
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            );
          },
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge({
    required this.onTap,
    this.size = 54,
    this.icon = Icons.play_arrow_rounded,
  });

  final VoidCallback onTap;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return lgw.GlassButton(
      onTap: onTap,
      icon: Icon(icon),
      iconSize: size * 0.45,
      iconColor: Colors.white,
      width: size,
      height: size,
      stretch: 0.2,
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final total = value.duration;
        final position = value.position;
        final max = total.inMilliseconds.toDouble();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: lgw.GlassContainer.card(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
            shape: lgw.LiquidRoundedSuperellipse(borderRadius: 22),
            child: Row(
              children: [
                lgw.GlassButton(
                  onTap: () =>
                      value.isPlaying ? controller.pause() : controller.play(),
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  iconSize: 18,
                  iconColor: Colors.white,
                  width: 38,
                  height: 38,
                  stretch: 0.15,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: lgw.GlassSlider(
                    value: max <= 0
                        ? 0
                        : position.inMilliseconds
                            .clamp(0, total.inMilliseconds)
                            .toDouble(),
                    max: max <= 0 ? 1 : max,
                    onChanged: (next) =>
                        controller.seekTo(Duration(milliseconds: next.round())),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    thumbColor: Colors.white,
                    trackHeight: 3,
                    thumbRadius: 8,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_clock(position)} / ${_clock(total)}',
                  style: AppType.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
