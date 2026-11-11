import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/plate_utils.dart';

enum PlateBadgeSize { small, medium, large, xlarge }

/// Plat nomor bergaya plat fisik Indonesia: latar gelap, huruf Chivo tebal.
///
/// Dipakai konsisten di kartu daftar, detail, struk, dan halaman sukses.
class PlateBadge extends StatelessWidget {
  const PlateBadge(
    this.plate, {
    super.key,
    this.size = PlateBadgeSize.medium,
    this.maxWidth,
  });

  final String plate;
  final PlateBadgeSize size;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final display = formatPlate(plate);
    final label = display.isEmpty ? '-' : display;

    final double fontSize;
    final EdgeInsets padding;
    final double radius;
    final double letterSpacing;

    switch (size) {
      case PlateBadgeSize.small:
        fontSize = 13;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
        radius = AppRadius.xs;
        letterSpacing = 1.4;
        break;
      case PlateBadgeSize.medium:
        fontSize = 16;
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
        radius = 10;
        letterSpacing = 1.8;
        break;
      case PlateBadgeSize.large:
        fontSize = 22;
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
        radius = AppRadius.sm;
        letterSpacing = 2.4;
        break;
      case PlateBadgeSize.xlarge:
        fontSize = 30;
        padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
        radius = 14;
        letterSpacing = 3.2;
        break;
    }

    return Semantics(
      label: 'Nomor polisi $label',
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        padding: padding,
        decoration: BoxDecoration(
          color: semantic.plateBackground,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: semantic.plateBorder, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: AppTheme.plateStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
            ).copyWith(color: semantic.plateForeground),
          ),
        ),
      ),
    );
  }
}
