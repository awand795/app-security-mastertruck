import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Area aksi yang menempel di bawah layar (sticky CTA).
///
/// Konten di dalamnya dibatasi selebar 760 px agar tetap rapi di tablet,
/// sementara latar dan bayangan mengikuti lebar penuh layar.
class StickyBottomBar extends StatelessWidget {
  const StickyBottomBar({
    super.key,
    required this.child,
    this.hint,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    this.maxWidth = 760,
  });

  final Widget child;
  final String? hint;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: AppShadows.top(context),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hint != null) ...[
                    Text(
                      hint!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
