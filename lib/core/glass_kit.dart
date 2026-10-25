import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import 'theme.dart';
import 'widgets.dart';

/// 分段选择：玻璃版 GlassSegmentedControl ↔ 纯色药丸。
class AppSegmented extends ConsumerWidget {
  const AppSegmented({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 44,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = glassOn(ref);
    return GlassOrSolid(
      on: on,
      glass: lgw.GlassSegmentedControl(
        segments: [
          for (final label in labels) lgw.GlassSegment(label: label),
        ],
        selectedIndex: selectedIndex,
        onSegmentSelected: onSelected,
        height: height,
      ),
      solid: Container(
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.insetColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.lineColor),
        ),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == selectedIndex
                          ? context.accentColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      labels[index],
                      style: AppType.footnote.copyWith(
                        fontWeight: FontWeight.w600,
                        color: index == selectedIndex
                            ? Colors.white
                            : context.subInkColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 选择胶囊：玻璃版 GlassChip ↔ 纯色药丸。
class AppChip extends ConsumerWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = glassOn(ref);
    return GlassOrSolid(
      on: on,
      glass: lgw.GlassChip(
        label: label,
        selected: selected,
        selectedColor: context.accentColor,
        labelStyle: AppType.footnote.copyWith(fontWeight: FontWeight.w600),
        onTap: onTap,
      ),
      solid: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? context.accentColor : context.insetColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? context.accentColor : context.lineColor,
            ),
          ),
          child: Text(
            label,
            style: AppType.footnote.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : context.inkColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// 拖动条：玻璃版 GlassSlider ↔ 系统 Slider。
class AppSlider extends ConsumerWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.activeColor,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final Color? activeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = glassOn(ref);
    final accent = activeColor ?? context.accentColor;
    final clamped = value.clamp(min, max).toDouble();
    return GlassOrSolid(
      on: on,
      glass: lgw.GlassSlider(
        value: clamped,
        min: min,
        max: max,
        onChanged: onChanged,
        activeColor: accent,
        inactiveColor: context.lineColor,
        thumbColor: Colors.white,
        trackHeight: 4,
        thumbRadius: 9,
      ),
      solid: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          activeTrackColor: accent,
          inactiveTrackColor: context.lineColor,
          thumbColor: Colors.white,
          overlayColor: accent.withValues(alpha: 0.12),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        ),
        child: Slider(
          value: clamped,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// 输入框：玻璃版 GlassTextField ↔ 纯色描边输入框。
class AppTextField extends ConsumerWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.textStyle,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.height = 44,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextStyle? textStyle;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = glassOn(ref);
    final style = textStyle ?? AppType.body.copyWith(color: context.inkColor);
    return GlassOrSolid(
      on: on,
      glass: lgw.GlassTextField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textStyle: style,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        height: height,
      ),
      solid: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.insetColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.lineColor),
        ),
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          cursorColor: context.accentColor,
          style: style,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: placeholder,
            hintStyle: style.copyWith(color: context.subInkColor),
          ),
        ),
      ),
    );
  }
}

/// 文字按钮：玻璃版 GlassButton.custom ↔ 纯色文字按钮。
class AppTextButton extends ConsumerWidget {
  const AppTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 72,
    this.height = 30,
  });

  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = glassOn(ref);
    return GlassOrSolid(
      on: on,
      glass: lgw.GlassButton.custom(
        onTap: onTap,
        width: width,
        height: height,
        shape: lgw.LiquidRoundedSuperellipse(borderRadius: 10),
        stretch: 0.15,
        child: Text(
          label,
          style: AppType.caption.copyWith(
            color: context.accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      solid: SizedBox(
        width: width,
        height: height,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: context.insetColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: context.lineColor),
            ),
          ),
          child: Text(
            label,
            style: AppType.caption.copyWith(
              color: context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 小图标按钮：玻璃版 GlassButton ↔ 纯色方块。
class AppIconButton extends ConsumerWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize = 18,
    this.iconColor,
    this.radius = 12,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = glassOn(ref);
    return GlassOrSolid(
      on: on,
      glass: lgw.GlassButton(
        onTap: onTap,
        icon: Icon(icon),
        iconSize: iconSize,
        iconColor: iconColor ?? context.inkColor,
        width: size,
        height: size,
        shape: lgw.LiquidRoundedSuperellipse(borderRadius: radius),
        stretch: 0.15,
      ),
      solid: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: context.insetColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: context.lineColor),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? context.inkColor,
            ),
          ),
        ),
      ),
    );
  }
}
