import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'plate_badge.dart';

/// Kotak viewfinder plat nomor bergaya Dribbble:
/// gradien biru muda, 4 sudut siku biru, garis pindai bergradien di tengah,
/// dan [PlateBadge] (atau input plat) di tengah.
class PlateViewfinder extends StatelessWidget {
  const PlateViewfinder({
    super.key,
    required this.plate,
    this.onTap,
    this.helperText,
  });

  final String plate;
  final VoidCallback? onTap;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPlate = plate.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF172549), const Color(0xFF111C38)]
                : [const Color(0xFFEAF0FF), const Color(0xFFF4F7FF)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Garis pindai bergradien di tengah
            Positioned(
              left: 20,
              right: 20,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0),
                      scheme.primary.withValues(alpha: 0.45),
                      scheme.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // 4 sudut siku biru
            ..._buildCorners(scheme.primary),
            // Konten tengah
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: hasPlate
                  ? PlateBadge(plate, size: PlateBadgeSize.large)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.document_scanner_outlined,
                          size: 26,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          helperText ??
                              'Ketuk untuk pindai atau isi plat nomor',
                          textAlign: TextAlign.center,
                          style: texts.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCorners(Color color) {
    const double pad = 12;
    const double len = 16;
    const double thick = 2.5;
    final side = BorderSide(color: color, width: thick);

    return [
      Positioned(
        left: pad,
        top: pad,
        child: Container(
          width: len,
          height: len,
          decoration: BoxDecoration(
            border: Border(top: side, left: side),
          ),
        ),
      ),
      Positioned(
        right: pad,
        top: pad,
        child: Container(
          width: len,
          height: len,
          decoration: BoxDecoration(
            border: Border(top: side, right: side),
          ),
        ),
      ),
      Positioned(
        left: pad,
        bottom: pad,
        child: Container(
          width: len,
          height: len,
          decoration: BoxDecoration(
            border: Border(bottom: side, left: side),
          ),
        ),
      ),
      Positioned(
        right: pad,
        bottom: pad,
        child: Container(
          width: len,
          height: len,
          decoration: BoxDecoration(
            border: Border(bottom: side, right: side),
          ),
        ),
      ),
    ];
  }
}
