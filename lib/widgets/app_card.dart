import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Permukaan kartu standar: radius 20, border tipis, bayangan lembut.
///
/// [accentColor] menambahkan strip status di tepi kiri (dipakai daftar
/// kendaraan), sementara [gradient] dipakai untuk kartu ringkasan menonjol.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
    this.accentColor,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = AppRadius.lg,
    this.elevated = false,
    this.showShadow = true,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final bool elevated;
  final bool showShadow;

  /// Label aksesibilitas untuk kartu yang dapat diketuk.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    final effectiveBorder = borderColor ??
        (gradient != null ? Colors.transparent : scheme.outlineVariant);

    final effectivePadding = accentColor == null
        ? padding
        : padding.copyWith(left: padding.left + 4);

    Widget content = Padding(
      padding: effectivePadding,
      child: accentColor == null
          ? child
          : Stack(
              clipBehavior: Clip.none,
              children: [
                child,
                Positioned(
                  left: -padding.left - 4,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: accentColor),
                ),
              ],
            ),
    );

    if (onTap != null) {
      content = InkWell(onTap: onTap, child: content);
    }

    final card = Material(
      color: gradient == null ? (backgroundColor ?? scheme.surface) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: effectiveBorder, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: gradient == null ? null : BoxDecoration(gradient: gradient),
        child: content,
      ),
    );

    Widget decorated = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showShadow
            ? (elevated ? AppShadows.raised(context) : AppShadows.soft(context))
            : null,
      ),
      child: card,
    );

    if (onTap != null) {
      decorated = Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: decorated,
      );
    }

    if (margin == null) return decorated;
    return Padding(padding: margin!, child: decorated);
  }
}
