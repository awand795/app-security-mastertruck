import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Banner ringkas saat form memiliki draft tersimpan lokal, dengan tombol reset.
class DraftBanner extends StatelessWidget {
  const DraftBanner({
    super.key,
    required this.onReset,
    this.label = 'Draft tersimpan otomatis di HP',
  });

  final VoidCallback onReset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.save_outlined,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: texts.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onReset,
            style: TextButton.styleFrom(
              foregroundColor: scheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Reset Form'),
          ),
        ],
      ),
    );
  }
}
