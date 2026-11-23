import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'app_button.dart';
import 'plate_badge.dart';
import 'status_chip.dart';

/// Dialog ringkas selesai setelah Check-In / Check-Out (tanpa barcode/QR).
///
/// Menampilkan ikon ceklis, judul selesai, plat nomor, dan nama pengemudi,
/// dengan 2 tombol: 'Ke Beranda' dan 'Selesai' (untuk transaksi berikutnya).
class CompletionDialog extends StatelessWidget {
  const CompletionDialog({
    super.key,
    required this.title,
    required this.noPolisi,
    required this.namaPengemudi,
    this.isTempExit = false,
    this.uploadWarning,
    this.onDone,
    this.onGoToBeranda,
  });

  final String title;
  final String noPolisi;
  final String namaPengemudi;
  final bool isTempExit;
  final String? uploadWarning;
  final VoidCallback? onDone;
  final VoidCallback? onGoToBeranda;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: isTempExit
                      ? semantic.warningContainer
                      : semantic.successContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 40,
                  color: isTempExit ? semantic.warning : semantic.success,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: texts.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (isTempExit) ...[
                const StatusChip(
                  AppStatus.inProgress,
                  label: 'Keluar Sementara',
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    PlateBadge(noPolisi, size: PlateBadgeSize.large),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      namaPengemudi.isNotEmpty ? namaPengemudi : '-',
                      textAlign: TextAlign.center,
                      style: texts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (uploadWarning != null && uploadWarning!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: semantic.warningContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    uploadWarning!,
                    textAlign: TextAlign.center,
                    style: texts.bodySmall?.copyWith(
                      color: semantic.onWarningContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (onGoToBeranda != null) ...[
                    Expanded(
                      child: AppButton(
                        label: 'Ke Beranda',
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.medium,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDone?.call();
                          onGoToBeranda?.call();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: AppButton(
                      label: 'Selesai',
                      icon: Icons.check_rounded,
                      size: AppButtonSize.medium,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onDone?.call();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
