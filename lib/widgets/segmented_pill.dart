import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Segmented control pill (mis. Service | Umum) dengan track #EEF2FB dan
/// thumb putih bergeser halus.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final List<({T value, String label, IconData? icon})> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = options.indexWhere((o) => o.value == selectedValue);
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainer : const Color(0xFFEEF2FB),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppDurations.normal,
                curve: Curves.easeOutCubic,
                left: safeIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.soft(context),
                  ),
                ),
              ),
              Row(
                children: options.map((opt) {
                  final selected = opt.value == selectedValue;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onChanged(opt.value),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (opt.icon != null) ...[
                              Icon(
                                opt.icon,
                                size: 18,
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                opt.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: texts.labelLarge?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
