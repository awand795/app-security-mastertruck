import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/plate_utils.dart';

enum PlateBadgeSize { small, medium, large, xlarge }

/// Plat nomor bergaya plat fisik putih Indonesia: border navy #0F1B3D 2px,
/// strip biru di bagian bawah, dan huruf Chivo 900 berjarak lebar.
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
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final display = formatPlate(plate);
    final label = display.isEmpty ? '-' : display;

    final double fontSize;
    final EdgeInsets padding;
    final double radius;
    final double letterSpacing;
    final double stripHeight;

    switch (size) {
      case PlateBadgeSize.small:
        fontSize = 13;
        padding = const EdgeInsets.fromLTRB(10, 4, 10, 4);
        radius = 8;
        letterSpacing = 1.6;
        stripHeight = 3;
        break;
      case PlateBadgeSize.medium:
        fontSize = 16;
        padding = const EdgeInsets.fromLTRB(12, 6, 12, 5);
        radius = 10;
        letterSpacing = 2.0;
        stripHeight = 3.5;
        break;
      case PlateBadgeSize.large:
        fontSize = 22;
        padding = const EdgeInsets.fromLTRB(16, 8, 16, 7);
        radius = 12;
        letterSpacing = 2.6;
        stripHeight = 4;
        break;
      case PlateBadgeSize.xlarge:
        fontSize = 28;
        padding = const EdgeInsets.fromLTRB(20, 10, 20, 9);
        radius = 14;
        letterSpacing = 3.2;
        stripHeight = 5;
        break;
    }

    return Semantics(
      label: 'Nomor polisi $label',
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        decoration: BoxDecoration(
          color: semantic.plateBackground,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: semantic.plateBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2349C9).withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: padding,
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
              Container(height: stripHeight, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
