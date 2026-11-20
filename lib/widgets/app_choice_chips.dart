import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Kumpulan ChoiceChips berbentuk pill (tinggi 40+) dengan state terpilih biru solid.
class AppChoiceChips extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.onSelected,
  });

  final List<String> options;
  final String? selectedOption;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: options.map((opt) {
        final selected = selectedOption == opt;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: ChoiceChip(
            label: Text(opt),
            selected: selected,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            selectedColor: scheme.primary,
            backgroundColor: scheme.surfaceContainer,
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            shape: const StadiumBorder(),
            labelStyle: texts.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
            onSelected: (_) => onSelected(opt),
          ),
        );
      }).toList(),
    );
  }
}
