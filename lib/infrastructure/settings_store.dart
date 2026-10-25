import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 应用设置：输出目录 + 外观。
class AppSettings {
  const AppSettings({
    this.outputFolder = 'FormatLab',
    this.themeMode = 'system',
    this.glass = true,
  });

  /// 相册里的子目录名：图片进 Pictures、视频进 Movies、音频进 Music。
  final String outputFolder;

  /// system / light / dark
  final String themeMode;

  /// 液态玻璃外观；关掉就是纯色卡片。
  final bool glass;

  AppSettings copyWith({String? outputFolder, String? themeMode, bool? glass}) =>
      AppSettings(
        outputFolder: outputFolder ?? this.outputFolder,
        themeMode: themeMode ?? this.themeMode,
        glass: glass ?? this.glass,
      );

  Map<String, dynamic> toJson() => {
        'outputFolder': outputFolder,
        'themeMode': themeMode,
        'glass': glass,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final folder = (json['outputFolder'] as String?)?.trim();
    final mode = json['themeMode'] as String?;
    return AppSettings(
      outputFolder: (folder == null || folder.isEmpty) ? 'FormatLab' : folder,
      themeMode: (mode == 'light' || mode == 'dark') ? mode! : 'system',
      glass: json['glass'] as bool? ?? true,
    );
  }
}

class SettingsStore {
  File? _cachedFile;

  Future<File> _file() async {
    final cached = _cachedFile;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}settings.json');
    _cachedFile = file;
    return file;
  }

  Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppSettings();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const AppSettings();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AppSettings();
      return AppSettings.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(settings.toJson()));
    } catch (_) {
      // 设置写入失败不影响转换。
    }
  }

  /// 目录名只保留安全字符，避免 MediaStore 路径异常。
  static String sanitizeFolder(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '')
        .replaceAll('..', '');
    if (cleaned.isEmpty) return 'FormatLab';
    return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
  }
}
