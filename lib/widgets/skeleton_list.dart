import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Placeholder skeleton berbentuk kartu daftar.
///
/// Menggantikan spinner tengah layar: tata letak tetap stabil dan petugas
/// melihat "bentuk" konten yang akan muncul.
class SkeletonList extends StatefulWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.scrollable = true,
    this.itemHeight = 144,
  });

  final int itemCount;
  final EdgeInsets padding;
  final bool scrollable;
  final double itemHeight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget buildItem(BuildContext context, int index) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final tone = Color.lerp(
            scheme.surfaceContainer,
            scheme.surfaceContainerHigh,
            _controller.value,
          )!;

          Widget box(double? width, double height, {double radius = 8}) {
            return Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(radius),
              ),
            );
          }

          return Container(
            height: widget.itemHeight,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    box(84, 28),
                    box(76, 24, radius: AppRadius.pill),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                box(double.infinity, 12),
                const SizedBox(height: AppSpacing.xs),
                box(168, 12),
                const Spacer(),
                Row(
                  children: [
                    box(16, 16, radius: AppRadius.pill),
                    const SizedBox(width: AppSpacing.xs),
                    box(96, 12),
                    const Spacer(),
                    box(84, 24),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    final children = List<Widget>.generate(widget.itemCount, (index) {
      return buildItem(context, index);
    });

    return Semantics(
      label: 'Memuat data',
      child: ExcludeSemantics(
        child: widget.scrollable
            ? ListView.separated(
                padding: widget.padding,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: children.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => children[index],
              )
            : Padding(
                padding: widget.padding,
                child: Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      children[i],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
