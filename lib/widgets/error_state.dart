import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'app_button.dart';

/// Error state dengan aksi "Coba Lagi" agar petugas tidak terjebak layar kosong.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Gagal memuat data',
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Coba Lagi',
    this.icon = Icons.cloud_off_rounded,
    this.compact = false,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final circle = compact ? 64.0 : 88.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? 28 : 40,
                  color: scheme.onErrorContainer,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: texts.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: texts.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: retryLabel,
                onPressed: onRetry,
                icon: Icons.refresh_rounded,
                size: AppButtonSize.medium,
                expanded: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
