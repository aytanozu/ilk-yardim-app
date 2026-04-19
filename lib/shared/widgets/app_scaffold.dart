import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Root scaffold used by the bottom navigation shell.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Dest('ACİL DURUM', Icons.emergency_rounded),
    _Dest('EĞİTİM', Icons.school_rounded),
    _Dest('AKIŞ', Icons.forum_rounded),
    _Dest('PROFİL', Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
        selected: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.selected, required this.onTap});

  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: AppColors.ambientShadow,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < AppShellScaffold._destinations.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: _NavItem(
                      dest: AppShellScaffold._destinations[i],
                      active: selected == i,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.dest, required this.active});

  final _Dest dest;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.onSurfaceVariant;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryFixed : Colors.transparent,
            borderRadius: AppSpacing.borderFull,
          ),
          child: Icon(dest.icon, color: color, size: 22),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          dest.label,
          style: AppTypography.labelSm.copyWith(
            color: color,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _Dest {
  const _Dest(this.label, this.icon);
  final String label;
  final IconData icon;
}
