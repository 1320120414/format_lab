import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;

import '../../application/task_queue.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../domain/models.dart';
import '../home/home_page.dart';
import '../settings/settings_page.dart';
import '../tasks/tasks_page.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedTabProvider);
    final glass = glassOn(ref);
    final activeCount = ref
        .watch(taskQueueProvider)
        .where((task) => !task.status.isFinished)
        .length;
    void select(int tab) =>
        ref.read(selectedTabProvider.notifier).state = tab;

    return lgw.GlassPage(
      background: const AmbientBackground(),
      settings: glassSettings,
      child: Scaffold(
        // 透明底，露出 GlassPage 的背景
        backgroundColor: Colors.transparent,
        // 让内容滑到导航栏下面，玻璃才有东西可糊。
        extendBody: true,
        body: ContentWidth(
          child: IndexedStack(
            index: index,
            children: const [
              HomePage(),
              TasksPage(),
              SettingsPage(),
            ],
          ),
        ),
        bottomNavigationBar: GlassOrSolid(
          on: glass,
          glass: lgw.GlassTabBar.bottom(
            tabs: [
              const lgw.GlassTab(
                icon: Icon(Icons.grid_view_rounded),
                label: '首页',
              ),
              lgw.GlassTab(
                icon: _TabIcon(
                  icon: Icons.swap_vert_rounded,
                  badge: activeCount,
                ),
                label: '任务',
              ),
              const lgw.GlassTab(icon: Icon(Icons.tune_rounded), label: '设置'),
            ],
            selectedIndex: index,
            onTabSelected: select,
            barHeight: 60,
            verticalPadding: 14,
          ),
          solid: _SolidTabBar(
            index: index,
            activeCount: activeCount,
            onSelected: select,
          ),
        ),
      ),
    );
  }
}

/// 关掉液态玻璃时的底部导航：纯色药丸 + 选中项实心。
class _SolidTabBar extends StatelessWidget {
  const _SolidTabBar({
    required this.index,
    required this.activeCount,
    required this.onSelected,
  });

  final int index;
  final int activeCount;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.grid_view_rounded, '首页'),
    (Icons.swap_vert_rounded, '任务'),
    (Icons.tune_rounded, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        height: 60,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.lineColor),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: i == index
                          ? context.accentColor.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TabIcon(
                          icon: _items[i].$1,
                          badge: i == 1 ? activeCount : 0,
                          color: i == index
                              ? context.accentColor
                              : context.subInkColor,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _items[i].$2,
                          style: AppType.caption.copyWith(
                            fontSize: 11,
                            color: i == index
                                ? context.accentColor
                                : context.subInkColor,
                            fontWeight: i == index
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ],
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

/// 图标 + 可选角标，交给 GlassTabBar 当 tab 图标用。
class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.icon, this.badge = 0, this.color});

  final IconData icon;
  final int badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (badge <= 0) return Icon(icon, size: 22, color: color);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 22, color: color),
        Positioned(
          right: -8,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppPalette.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
