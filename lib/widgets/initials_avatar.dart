import 'package:flutter/material.dart';

/// Membuat inisial dari nama petugas, mis. "Bambang Sutrisno" -> "BS".
String initialsFromName(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);

  if (words.isEmpty) return 'PT';
  if (words.length == 1) {
    final word = words.first;
    return (word.length >= 2 ? word.substring(0, 2) : word).toUpperCase();
  }

  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

/// Avatar inisial tanpa foto. Dipakai di header Beranda, header tab lain,
/// dan sheet Profil agar identitas petugas tetap konsisten.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.onTap,
    this.tooltip = 'Buka profil petugas',
  });

  final String name;
  final double size;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final hitSize = size < 48 ? 48.0 : size;

    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        initialsFromName(name),
        style: texts.labelLarge?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
          letterSpacing: 0.4,
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(label: 'Avatar ${initialsFromName(name)}', child: circle);
    }

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: hitSize,
              height: hitSize,
              child: Center(child: circle),
            ),
          ),
        ),
      ),
    );
  }
}
