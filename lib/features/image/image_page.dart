import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import '../../application/task_queue.dart';
import '../../core/glass_kit.dart';
import '../../core/picked_file.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../shell/root_shell.dart';

class ImagePage extends ConsumerStatefulWidget {
  const ImagePage({super.key});

  @override
  ConsumerState<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends ConsumerState<ImagePage> {
  final List<String> _paths = [];
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  TargetFormat _format = TargetFormat.jpeg;
  double _quality = 92;
  bool _lockRatio = true;
  bool _picking = false;
  double? _sourceAspect;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
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
      if (picked.isNotEmpty && _sourceAspect == null) {
        await _probeAspect(picked.first);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _probeAspect(String path) async {
    try {
      final info = await ref.read(imageEngineProvider).probe(path);
      if (!mounted || info.height <= 0) return;
      setState(() => _sourceAspect = info.width / info.height);
    } catch (_) {
      // 拿不到尺寸就只做手动输入，不影响转换。
    }
  }

  void _onWidthChanged(String value) {
    final width = int.tryParse(value);
    final aspect = _sourceAspect;
    if (!_lockRatio || width == null || width <= 0 || aspect == null) return;
    _heightController.text = '${(width / aspect).round()}';
  }

  void _onHeightChanged(String value) {
    final height = int.tryParse(value);
    final aspect = _sourceAspect;
    if (!_lockRatio || height == null || height <= 0 || aspect == null) return;
    _widthController.text = '${(height * aspect).round()}';
  }

  void _resetSize() {
    _widthController.clear();
    _heightController.clear();
  }

  int _parseSize(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim()) ?? 0;
    if (value <= 0) return 0;
    return value.clamp(1, 10000);
  }

  void _start() {
    ref.read(taskQueueProvider.notifier).enqueue(
          paths: List.of(_paths),
          spec: ImageSpec(
            format: _format,
            width: _parseSize(_widthController),
            height: _parseSize(_heightController),
            quality: _quality.round(),
          ),
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
            title: '图片',
            subtitle: '选图 → 选输出格式 → 开始，批量的部分交给队列',
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
                        : Icons.add_photo_alternate_outlined,
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
                        _paths.isEmpty ? '选择图片' : '继续添加',
                        style:
                            AppType.bodyStrong.copyWith(color: context.inkColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '可一次选多张，HEIC / 动图都能直接读',
                        style:
                            AppType.caption.copyWith(color: context.subInkColor),
                      ),
                    ],
                  ),
                ),
                if (_paths.isNotEmpty)
                  Pill('${_paths.length} 张', color: context.accentColor),
              ],
            ),
          ),
          if (_paths.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _paths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => _PickedThumb(
                  path: _paths[index],
                  onRemove: () => setState(() => _paths.removeAt(index)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const SectionLabel('输出格式'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final format in TargetFormat.values)
                _Choice(
                  label: format.label,
                  selected: _format == format,
                  onTap: () => setState(() => _format = format),
                ),
            ],
          ),
          if (_format.isAnimated) ...[
            const SizedBox(height: 10),
            Text(
              '动图保留全部帧；实况照片会取内嵌的那段视频转 GIF；普通静态图只输出一帧。',
              style: AppType.caption.copyWith(color: context.subInkColor),
            ),
          ],
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(child: SectionLabel('尺寸')),
              AppTextButton(label: '原尺寸', onTap: _resetSize),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _SizeField(
                  controller: _widthController,
                  hint: '宽',
                  onChanged: _onWidthChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '×',
                  style: AppType.body.copyWith(color: context.subInkColor),
                ),
              ),
              Expanded(
                child: _SizeField(
                  controller: _heightController,
                  hint: '高',
                  onChanged: _onHeightChanged,
                ),
              ),
              const SizedBox(width: 6),
              _LockButton(
                locked: _lockRatio,
                onTap: () {
                  setState(() => _lockRatio = !_lockRatio);
                  if (_lockRatio) _onWidthChanged(_widthController.text);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _lockRatio
                ? '锁比例：改一边，另一边按第一张图的比例自动算。两个都填则精确输出该尺寸。'
                : '不锁比例：只填一边时，每张图按自己的比例补齐另一边；留空则保持原尺寸。',
            style: AppType.caption.copyWith(color: context.subInkColor),
          ),
          if (_format.supportsQuality) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: SectionLabel('质量')),
                Text(
                  '${_quality.round()}',
                  style: AppType.mono.copyWith(color: context.subInkColor),
                ),
              ],
            ),
            AppSlider(
              value: _quality,
              min: 40,
              max: 100,
              // 不设 divisions：无极拖动，取整只影响显示。
              onChanged: (value) => setState(() => _quality = value),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '结果自动保存到相册的 Pictures/FormatLab，同时保留一份缓存用于预览和分享。',
            style: AppType.caption.copyWith(color: context.subInkColor),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: GlassPrimaryButton(
          label: canStart ? '开始转换 ${_paths.length} 张' : '先选择图片',
          onPressed: canStart ? _start : null,
        ),
      ),
    );
  }
}

class _SizeField extends StatelessWidget {
  const _SizeField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      placeholder: hint,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textStyle: AppType.body.copyWith(color: context.inkColor),
      onChanged: onChanged,
      height: 44,
    );
  }
}

class _LockButton extends StatelessWidget {
  const _LockButton({required this.locked, required this.onTap});

  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      onTap: onTap,
      icon: locked ? Icons.link_rounded : Icons.link_off_rounded,
      iconSize: 18,
      iconColor: locked ? context.accentColor : context.subInkColor,
      size: 44,
      radius: 12,
    );
  }
}

/// 已选图片的缩略图：玻璃相框 + 玻璃移除按钮。
class _PickedThumb extends ConsumerWidget {
  const _PickedThumb({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = glassOn(ref);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.file(
        File(path),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 64,
          height: 64,
          color: context.insetColor,
          child: Icon(
            Icons.broken_image_outlined,
            size: 20,
            color: context.subInkColor,
          ),
        ),
      ),
    );

    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: on
                ? lgw.GlassContainer.card(
                    padding: const EdgeInsets.all(3),
                    shape: lgw.LiquidRoundedSuperellipse(borderRadius: 14),
                    child: image,
                  )
                : Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: context.insetColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.lineColor),
                    ),
                    child: image,
                  ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: AppIconButton(
              onTap: onRemove,
              icon: Icons.close_rounded,
              iconSize: 13,
              iconColor: context.inkColor,
              size: 24,
              radius: 12,
            ),
          ),
        ],
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
