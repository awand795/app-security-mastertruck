import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/theme.dart';
import '../models/set_foto_model.dart';

/// Pemilih foto kendaraan & supir yang dikonfigurasi dari tabel `set_foto`.
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
    this.anglesList,
    this.fotoSettings,
    this.showExtraButton = true,
  });

  /// '<KODE_FOTO>' -> base64.
  final Map<String, String> photos;
  final Function(String angle, String base64) onPhotoCaptured;
  final Function(String angle)? onPhotoRemoved;
  final bool enabled;
  final int? uploadCurrent;
  final int? uploadTotal;
  final bool showHeader;
  final List<Map<String, String>>? anglesList;
  final List<SetFotoItem>? fotoSettings;
  final bool showExtraButton;

  static const List<Map<String, String>> checkoutAngles = [
    {'key': 'TAMPAK_DEPAN', 'label': 'Tampak Depan *'},
    {'key': 'FOTO_SUPIR', 'label': 'Foto Supir *'},
    {'key': 'TAMPAK_BELAKANG', 'label': 'Tampak Belakang'},
    {'key': 'TAMPAK_KIRI', 'label': 'Tampak Kiri'},
    {'key': 'TAMPAK_KANAN', 'label': 'Tampak Kanan'},
    {'key': 'FOTO_LAINNYA', 'label': 'Foto Lainnya'},
  ];

  static const List<Map<String, String>> angles = checkoutAngles;

  static bool hasRequiredPhotos(Map<String, String> photos) =>
      hasRequiredPhotosFor(photos, SetFotoItem.defaultSettings);

  static bool hasRequiredPhotosFor(
    Map<String, String> photos,
    List<SetFotoItem> settings,
  ) {
    final requiredItems = settings.where((s) => s.isWajib).toList();
    if (requiredItems.isEmpty) return true;
    return requiredItems.every(
      (s) => (photos[s.angleKey]?.isNotEmpty ?? false),
    );
  }

  static int requiredUploadedCountFor(
    Map<String, String> photos,
    List<SetFotoItem> settings,
  ) {
    return settings
        .where((s) => s.isWajib && (photos[s.angleKey]?.isNotEmpty ?? false))
        .length;
  }

  static int requiredTotalCountFor(List<SetFotoItem> settings) =>
      settings.where((s) => s.isWajib).length;

  String _nextExtraKey() {
    var idx = 1;
    while (photos.containsKey('TAMBAHAN_$idx')) {
      idx++;
    }
    return 'TAMBAHAN_$idx';
  }

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
    final settings = fotoSettings;
    final activeAngles = (settings != null && settings.isNotEmpty)
        ? settings
              .map((s) => {'key': s.angleKey, 'label': s.displayLabel})
              .toList()
        : (anglesList ?? angles);
    final count = photos.length.clamp(0, activeAngles.length).toInt();

    final extraKeys =
        photos.keys.where((k) => k.startsWith('TAMBAHAN_')).toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Foto Kendaraan & Supir',
                  style: texts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${photos.length} foto',
                style: texts.labelLarge?.copyWith(
                  color:
                      (settings != null
                          ? hasRequiredPhotosFor(photos, settings)
                          : hasRequiredPhotos(photos))
                      ? semantic.success
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: List<Widget>.generate(activeAngles.length, (index) {
            final filled = index < count;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == activeAngles.length - 1 ? 0 : AppSpacing.xs,
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
              itemCount: activeAngles.length,
              itemBuilder: (context, index) {
                final item = activeAngles[index];
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
        if (extraKeys.isNotEmpty) ...[
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
                itemCount: extraKeys.length,
                itemBuilder: (context, index) {
                  final key = extraKeys[index];
                  final label = 'Tambahan #${index + 1}';
                  return _FilledPhotoTile(
                    label: label,
                    photo: photos[key]!,
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
        if (showExtraButton) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: enabled
                ? () => _takePhoto(context, _nextExtraKey())
                : null,
            icon: const Icon(Icons.add_a_photo_rounded, size: 18),
            label: Text(
              extraKeys.isEmpty
                  ? 'Tambah Foto Tambahan'
                  : 'Tambah Foto Tambahan (${extraKeys.length})',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
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
    final isRequired = label.endsWith('*');
    final cleanLabel = isRequired
        ? label.substring(0, label.length - 1).trim()
        : label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dashColor = isDark ? scheme.outline : const Color(0xFFB8C4E4);

    return Semantics(
      button: enabled,
      label: 'Ambil foto $label',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: CustomPaint(
            painter: _DashedRectPainter(color: dashColor, radius: AppRadius.md),
            child: Ink(
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
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
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text.rich(
                      TextSpan(
                        text: cleanLabel,
                        style: texts.labelMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        children: isRequired
                            ? [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ]
                            : const [],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final len = (dist + dashWidth).clamp(0.0, metric.length) - dist;
        canvas.drawPath(metric.extractPath(dist, dist + len), paint);
        dist += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
