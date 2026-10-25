import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/settings_store.dart';

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  /// 用户在异步读取完成前就改过设置时，不要用旧值把手动选择覆盖掉。
  bool _touched = false;

  @override
  AppSettings build() {
    _restore();
    return const AppSettings();
  }

  Future<void> _restore() async {
    final saved = await ref.read(settingsStoreProvider).load();
    if (_touched) return;
    state = saved;
  }

  Future<void> setOutputFolder(String folder) async {
    final clean = SettingsStore.sanitizeFolder(folder);
    _apply(state.copyWith(outputFolder: clean));
  }

  Future<void> setThemeMode(String mode) async {
    _apply(state.copyWith(themeMode: mode));
  }

  Future<void> setGlass(bool enabled) async {
    _apply(state.copyWith(glass: enabled));
  }

  void _apply(AppSettings next) {
    _touched = true;
    state = next;
    ref.read(settingsStoreProvider).save(next);
  }
}
