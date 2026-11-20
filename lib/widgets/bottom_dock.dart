import 'package:flutter/material.dart';

import '../config/theme.dart';

class BottomNavItem {
  const BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Satu container putih menyatu di bagian bawah layar berisi:
/// - Opsional CTA [cta] di bagian atas
/// - [BottomNav] 5 tab di bagian bawah dengan pil tint biru (56x30) untuk tab aktif.
class BottomDock extends StatelessWidget {
  const BottomDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTabSelected,
    this.cta,
  });

  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: AppShadows.top(context),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: AppDurations.fast,
                  curve: Curves.easeOut,
                  child: cta == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: cta,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: List<Widget>.generate(items.length, (index) {
                      final item = items[index];
                      final selected = index == currentIndex;
                      return Expanded(
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: item.label,
                          child: InkWell(
                            onTap: () => onTabSelected(index),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: AppDurations.fast,
                                    curve: Curves.easeOut,
                                    width: 56,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? scheme.primaryContainer
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Icon(
                                      selected ? item.selectedIcon : item.icon,
                                      size: 20,
                                      color: selected
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: texts.labelSmall?.copyWith(
                                      fontSize: 11,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: selected
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
