import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/lokasi_model.dart';

/// Pilihan lokasi (MT, G1, G2, dll) yang ditempatkan tepat di bawah scan plat.
class LokasiSelectorBlock extends StatelessWidget {
  const LokasiSelectorBlock({
    super.key,
    required this.lokasiList,
    required this.selectedLokasi,
    required this.onSelected,
    this.isLoading = false,
    this.errorText,
  });

  final List<LokasiItem> lokasiList;
  final LokasiItem? selectedLokasi;
  final ValueChanged<LokasiItem> onSelected;
  final bool isLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                text: 'Lokasi',
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: scheme.error),
                  ),
                ],
              ),
              style: texts.labelMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (selectedLokasi?.cekLokasi == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: semantic.infoContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.my_location_rounded,
                      size: 13,
                      color: semantic.onInfoContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cek GPS (${selectedLokasi!.radiusMeter}m)',
                      style: texts.labelSmall?.copyWith(
                        color: semantic.onInfoContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (isLoading && lokasiList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 3),
          )
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: lokasiList.map((loc) {
              final selected = selectedLokasi?.kodeLokasi == loc.kodeLokasi;
              return InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => onSelected(loc),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary
                        : scheme.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.outlineVariant,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        loc.isBengkelMt
                            ? Icons.build_circle_outlined
                            : Icons.warehouse_outlined,
                        size: 16,
                        color: selected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        loc.namaLokasi,
                        style: texts.labelLarge?.copyWith(
                          color: selected ? scheme.onPrimary : scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: texts.bodySmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
