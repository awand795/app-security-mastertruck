import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Baris label-nilai untuk detail kendaraan, konfirmasi, dan struk.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.valueStyle,
    this.trailing,
    this.onTap,
    this.dense = false,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.xs),
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final TextStyle? valueStyle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final displayValue = value.trim().isEmpty ? '-' : value;

    final row = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 16 : 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: (dense ? texts.bodySmall : texts.bodyMedium)?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            flex: 6,
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              style: (valueStyle ?? (dense ? texts.bodySmall : texts.bodyMedium))
                  ?.copyWith(
                color: valueColor ?? scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: row,
      ),
    );
  }
}
