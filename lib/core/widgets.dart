import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import '../application/settings_controller.dart';
import 'theme.dart';

/// 大标题 + 副标题，苹果式页头。
class LargeHeader extends StatelessWidget {
  const LargeHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.largeTitle.copyWith(color: context.inkColor)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: AppType.footnote.copyWith(color: context.subInkColor),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text,
        style: AppType.caption.copyWith(
          color: context.subInkColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// 背景配色：多块不同色相的光斑，玻璃卡片透出来才会"一块一个颜色"。
class AmbientTheme {
  const AmbientTheme({required this.colors, required this.blobs});

  final List<Color> colors;
  final List<AmbientBlob> blobs;

  static const light = AmbientTheme(
    colors: [Color(0xFFF5F7FF), Color(0xFFFAF2FF), Color(0xFFF2FBFF)],
    blobs: [
      AmbientBlob(Alignment(-1.1, -1.0), 340, Color(0xCCFF8FC0)),
      AmbientBlob(Alignment(0, -1.15), 320, Color(0xC0B98CFF)),
      AmbientBlob(Alignment(1.1, -0.95), 340, Color(0xC07FB8FF)),
      AmbientBlob(Alignment(-1.2, 0.0), 320, Color(0xB36FD9FF)),
      AmbientBlob(Alignment(1.2, 0.05), 340, Color(0xB38FB4FF)),
      AmbientBlob(Alignment(-0.9, 1.0), 320, Color(0xB37FE8CE)),
      AmbientBlob(Alignment(0, 1.15), 340, Color(0xB3FFD97F)),
      AmbientBlob(Alignment(0.95, 0.95), 320, Color(0xB3FFA98F)),
    ],
  );

  static const dark = AmbientTheme(
    colors: [Color(0xFF0A0A18), Color(0xFF120A20), Color(0xFF06121A)],
    blobs: [
      AmbientBlob(Alignment(-1.1, -1.0), 340, Color(0x997A1E52)),
      AmbientBlob(Alignment(0, -1.15), 320, Color(0x994A1E8C)),
      AmbientBlob(Alignment(1.1, -0.95), 340, Color(0x991E3A8C)),
      AmbientBlob(Alignment(-1.2, 0.0), 320, Color(0x990E5A6E)),
      AmbientBlob(Alignment(1.2, 0.05), 340, Color(0x992A2E8C)),
      AmbientBlob(Alignment(-0.9, 1.0), 320, Color(0x99145A46)),
      AmbientBlob(Alignment(0, 1.15), 340, Color(0x996B5414)),
      AmbientBlob(Alignment(0.95, 0.95), 320, Color(0x997A2E1E)),
    ],
  );

  static AmbientTheme of(bool dark) => dark ? AmbientTheme.dark : AmbientTheme.light;
}

class AmbientBlob {
  const AmbientBlob(this.alignment, this.size, this.color);

  final Alignment alignment;
  final double size;
  final Color color;
}

/// 在任意 canvas 上按「整页坐标」画背景。
///
/// 卡片内部也用它：先抵消自身在页面里的偏移，再画同一份背景，
/// 于是玻璃卡片透出的颜色永远和它背后那块背景对得上。
class AmbientPainter extends CustomPainter {
  AmbientPainter({
    required this.theme,
    required this.pageSize,
    this.saturation = 1,
    this.followPageOrigin = false,
  });

  final AmbientTheme theme;
  final Size pageSize;

  /// 玻璃里提高一点饱和度（参考库的 vibrancy），颜色更透得出来。
  final double saturation;

  /// true 时先抵消自身在页面里的偏移，用于"贴在页面上"的局部(如导航栏)；
  /// 整页背景本身用 false，按自身局部坐标画就行。
  final bool followPageOrigin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (followPageOrigin) {
      final matrix = canvas.getTransform();
      final origin = Offset(matrix[12], matrix[13]);
      if (origin != Offset.zero) {
        canvas.translate(-origin.dx, -origin.dy);
      }
    }

    final page = Offset.zero & pageSize;
    if (saturation != 1) {
      canvas.saveLayer(
        page,
        Paint()..colorFilter = ColorFilter.matrix(_saturationMatrix(saturation)),
      );
    }

    canvas.drawRect(
      page,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.colors,
        ).createShader(page),
    );

    for (final blob in theme.blobs) {
      final center = blob.alignment.withinRect(page);
      final radius = blob.size / 2;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [blob.color, blob.color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    if (saturation != 1) {
      canvas.restore();
    }
    canvas.restore();
  }

  static List<double> _saturationMatrix(double s) {
    final ir = 0.2126 * (1 - s);
    final ig = 0.7152 * (1 - s);
    final ib = 0.0722 * (1 - s);
    return <double>[
      ir + s, ig, ib, 0, 0, //
      ir, ig + s, ib, 0, 0, //
      ir, ig, ib + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  @override
  bool shouldRepaint(covariant AmbientPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.pageSize != pageSize ||
      oldDelegate.saturation != saturation ||
      oldDelegate.followPageOrigin != followPageOrigin;
}

/// 整页柔光背景。玻璃卡片要有东西可"透"，靠它提供色彩层次。
class AmbientBackground extends ConsumerWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(settingsProvider.select((s) => s.glass));
    if (!enabled) return ColoredBox(color: context.pageColor);

    return RepaintBoundary(
      child: CustomPaint(
        painter: AmbientPainter(
          theme: AmbientTheme.of(context.isDark),
          pageSize: MediaQuery.sizeOf(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 桌面窗口很宽，内容居中限宽，避免卡片被拉成一条。
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 860});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 带柔光背景的页面骨架，二级页面用它才能让玻璃卡片透出层次。
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return lgw.GlassPage(
      background: const AmbientBackground(),
      settings: glassSettings,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: ContentWidth(child: body),
        // 这里不能再套 ContentWidth：Center 会撑满可用高度，
        // 底部栏一旦拿到整页高度，内容区就被挤成 0 高，只剩按钮。
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

/// 全 App 统一的玻璃参数：模糊、厚度、饱和度。
const glassSettings = lgw.LiquidGlassSettings(
  blur: 8,
  thickness: 28,
  saturation: 1.6,
  lightIntensity: 0.6,
);

/// 是否开启液态玻璃。带玻璃的控件都读这个值切换纯色版本。
bool glassOn(WidgetRef ref) =>
    ref.watch(settingsProvider.select((s) => s.glass));

/// 玻璃版和纯色版之间淡入淡出，切换设置时不会硬切。
class GlassOrSolid extends StatelessWidget {
  const GlassOrSolid({
    super.key,
    required this.on,
    required this.glass,
    required this.solid,
  });

  final bool on;
  final Widget glass;
  final Widget solid;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: KeyedSubtree(
        key: ValueKey<bool>(on),
        child: on ? glass : solid,
      ),
    );
  }
}

/// 页面底部的主操作按钮，玻璃质感，独占一行。
class GlassPrimaryButton extends ConsumerWidget {
  const GlassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = glassOn(ref);
    final enabled = onPressed != null;
    final text = Text(
      label,
      style: AppType.bodyStrong.copyWith(
        color: enabled
            ? (on ? context.accentColor : Colors.white)
            : context.subInkColor.withValues(alpha: 0.7),
      ),
    );

    return GlassOrSolid(
      on: on,
      glass: lgw.GlassButton.custom(
        onTap: onPressed ?? () {},
        enabled: enabled,
        width: double.infinity,
        height: 54,
        stretch: 0.15,
        shape: lgw.LiquidRoundedSuperellipse(borderRadius: 18),
        style: lgw.GlassButtonStyle.prominent,
        child: text,
      ),
      solid: SizedBox(
        height: 54,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: context.accentColor,
            disabledBackgroundColor: context.insetColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: text,
        ),
      ),
    );
  }
}

/// 液态玻璃面板：交给 liquid_glass_widgets 的 GlassContainer 做真实
/// 背景采样、模糊、折射与高光，背景由外层 GlassPage 提供。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 24,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = lgw.GlassContainer.card(
      padding: EdgeInsets.zero,
      shape: lgw.LiquidRoundedSuperellipse(borderRadius: radius),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: panel,
      ),
    );
  }
}

/// 统一的白/深色卡片；开启液态玻璃时自动换成 [GlassPanel]。
class SurfaceCard extends ConsumerWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = ref.watch(settingsProvider.select((s) => s.glass));

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.lineColor),
      ),
      child: child,
    );

    final solid = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: content,
            ),
          );

    return GlassOrSolid(
      on: glass,
      glass: GlassPanel(
        padding: padding,
        radius: radius,
        onTap: onTap,
        child: child,
      ),
      solid: solid,
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.background});

  final String text;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.subInkColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? foreground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppType.caption.copyWith(color: foreground, letterSpacing: 0.2),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 30, color: context.subInkColor.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(title, style: AppType.bodyStrong.copyWith(color: context.inkColor)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.footnote.copyWith(color: context.subInkColor),
          ),
        ],
      ),
    );
  }
}

/// 一条带右侧箭头的设置/入口行。
class ArrowRow extends StatelessWidget {
  const ArrowRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailingText,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppType.body.copyWith(color: context.inkColor),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppType.caption.copyWith(color: context.subInkColor),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: AppType.footnote.copyWith(color: context.subInkColor),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.subInkColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
