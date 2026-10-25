import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';

/// 历史记录就存一个 JSON 文件，够用且零依赖。
class HistoryStore {
  static const _maxEntries = 300;
  File? _cachedFile;

  Future<File> _file() async {
    final cached = _cachedFile;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}history.json');
    _cachedFile = file;
    return file;
  }

  Future<List<ConvertTask>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ConvertTask.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ConvertTask> tasks) async {
    final finished = tasks.where((task) => task.status.isFinished).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final trimmed = finished.take(_maxEntries).toList();
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode(trimmed.map((task) => task.toJson()).toList()),
      );
    } catch (_) {
      // 历史写入失败不影响转换本身。
    }
  }
}
