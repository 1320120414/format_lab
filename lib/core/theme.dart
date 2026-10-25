import 'package:flutter/material.dart';

/// 苹果风的关键不在装饰，而在留白、层级和克制的颜色。
/// 这里只定义一个强调色，其余全部走中性灰。
class AppPalette {
  static const accent = Color(0xFF0A7AFF);
  static const warning = Color(0xFFE5A00D);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF17A673);
}

class AppType {
  static const largeTitle = TextStyle(
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );
  static const title = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );
  static const headline = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const body = TextStyle(fontSize: 16, height: 1.45);
  static const bodyStrong = TextStyle(
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );
  static const footnote = TextStyle(fontSize: 13, height: 1.4);
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );
  static const mono = TextStyle(
    fontSize: 13,
    height: 1.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: const Color(0xFFF7F7F8),
        ink: const Color(0xFF111113),
        line: const Color(0xFFE6E6EB),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: const Color(0xFF000000),
        ink: const Color(0xFFF2F2F7),
        line: const Color(0xFF2C2C2E),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color ink,
    required Color line,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppPalette.accent,
      onPrimary: Colors.white,
      secondary: AppPalette.accent,
      onSecondary: Colors.white,
      error: AppPalette.danger,
      onError: Colors.white,
      surface: background,
      onSurface: ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      iconTheme: IconThemeData(color: ink),
      dividerColor: line,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppPalette.accent.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppType.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.accent,
          textStyle: AppType.bodyStrong,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppPalette.accent,
        thumbColor: Colors.white,
        overlayColor: AppPalette.accent.withValues(alpha: 0.12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFF1C1C1E),
        contentTextStyle: AppType.footnote.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// 方便在任意 widget 里拿到当前主题的中性色。
extension AppContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get pageColor => isDark ? const Color(0xFF000000) : const Color(0xFFF7F7F8);

  Color get cardColor => isDark ? const Color(0xFF1C1C1E) : Colors.white;

  Color get insetColor => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F5);

  Color get lineColor => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE6E6EB);

  Color get inkColor => isDark ? const Color(0xFFF2F2F7) : const Color(0xFF111113);

  Color get subInkColor => isDark ? const Color(0xFF9A9AA0) : const Color(0xFF6E6E73);

  Color get accentColor => AppPalette.accent;

  /// 玻璃卡片的高光描边。
  Color get glassStroke =>
      isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.9);
}
