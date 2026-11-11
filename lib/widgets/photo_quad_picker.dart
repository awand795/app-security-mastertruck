import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/theme.dart';

/// Pemilih foto empat sudut kendaraan.
///
/// Setiap kotak dapat difoto ulang dengan mengetuk gambar, atau dihapus lewat
/// tombol hapus. Progres unggah ditampilkan di dalam komponen agar petugas
/// gerbang tahu proses yang sedang berjalan.
class PhotoQuadPicker extends StatelessWidget {
  const PhotoQuadPicker({
    super.key,
    required this.photos,
    required this.onPhotoCaptured,
    this.onPhotoRemoved,
    this.enabled = true,
    this.uploadCurrent,
    this.uploadTotal,
    this.showHeader = false,
  });

  /// 'DEPAN', 'BELAKANG', 'KIRI', 'KANAN' -> base64.
  final Map<String, String> photos;
  final Function(String angle, String base64) onPhotoCaptured;
  final Function(String angle)? onPhotoRemoved;
  final bool enabled;
  final int? uploadCurrent;
  final int? uploadTotal;
  final bool showHeader;

  static const List<Map<String, String>> angles = [
    {'key': 'DEPAN', 'label': 'Tampak Depan'},
    {'key': 'BELAKANG', 'label': 'Tampak Belakang'},
    {'key': 'KIRI', 'label': 'Sisi Kiri'},
    {'key': 'KANAN', 'label': 'Sisi Kanan'},
  ];

  Future<void> _takePhoto(BuildContext context, String angle) async {
    final picker = ImagePicker();
    try {
      final xFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 960,
        imageQuality: 80,
      );

      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        final b64 = base64Encode(bytes);
        onPhotoCaptured(angle, b64);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera tidak tersedia. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;
    final count = photos.length.clamp(0, angles.length).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Foto Kendaraan',
                  style: texts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count/${angles.length}',
                style: texts.labelLarge?.copyWith(
                  color: count == angles.length
                      ? semantic.success
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: List<Widget>.generate(angles.length, (index) {
            final filled = index < count;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == angles.length - 1 ? 0 : AppSpacing.xs,
                ),
                child: AnimatedContainer(
                  duration: AppDurations.normal,
                  height: 6,
                  decoration: BoxDecoration(
                    color: filled
                        ? semantic.success
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            );
          }),
        ),
        if (uploadCurrent != null &&
            uploadTotal != null &&
            uploadTotal! > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: semantic.infoContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 18,
                      color: semantic.onInfoContainer,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Mengunggah foto ${uploadCurrent!.clamp(1, uploadTotal!)}/${uploadTotal!}',
                        style: texts.bodySmall?.copyWith(
                          color: semantic.onInfoContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: (uploadCurrent! / uploadTotal!)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    minHeight: 6,
                    color: semantic.info,
                    backgroundColor: semantic.info.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.xs,
                mainAxisSpacing: AppSpacing.xs,
                childAspectRatio: columns == 4 ? 1.15 : 1.28,
              ),
              itemCount: angles.length,
              itemBuilder: (context, index) {
                final item = angles[index];
                final key = item['key']!;
                final label = item['label']!;
                final photo = photos[key];

                if (photo == null) {
                  return _EmptyPhotoTile(
                    label: label,
                    enabled: enabled,
                    onTap: () => _takePhoto(context, key),
                  );
                }

                return _FilledPhotoTile(
                  label: label,
                  photo: photo,
                  enabled: enabled,
                  onRetake: () => _takePhoto(context, key),
                  onRemove: onPhotoRemoved == null
                      ? null
                      : () => onPhotoRemoved!(key),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _EmptyPhotoTile extends StatelessWidget {
  const _EmptyPhotoTile({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Semantics(
      button: enabled,
      label: 'Ambil foto $label',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Ink(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: texts.labelLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ambil foto',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texts.bodySmall?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilledPhotoTile extends StatelessWidget {
  const _FilledPhotoTile({
    required this.label,
    required this.photo,
    required this.enabled,
    required this.onRetake,
    this.onRemove,
  });

  final String label;
  final String photo;
  final bool enabled;
  final VoidCallback onRetake;
  final VoidCallback? onRemove;

  Widget _buildImage(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    try {
      return Image.memory(
        base64Decode(photo),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    } catch (_) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    return Semantics(
      button: enabled,
      label: 'Foto $label, ketuk untuk ganti',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: semantic.success, width: 1.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: enabled ? onRetake : null,
                child: _buildImage(context),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      scheme.scrim.withValues(alpha: 0.72),
                      scheme.scrim.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.xs,
              right: AppSpacing.xs,
              bottom: AppSpacing.xs,
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: semantic.success,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: semantic.onSuccess,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texts.bodySmall?.copyWith(
                        color: semantic.plateForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (enabled && onRemove != null)
              Positioned(
                top: 0,
                right: 0,
                child: Semantics(
                  button: true,
                  label: 'Hapus foto $label',
                  child: Tooltip(
                    message: 'Hapus foto $label',
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRemove,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: scheme.scrim.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: semantic.plateForeground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (!enabled)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: scheme.scrim.withValues(alpha: 0.25),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
