import 'package:flutter/material.dart';

import '../config/theme.dart';

enum AppStatus {
  booking,
  member,
  walkIn,
  readyToExit,
  inProgress,
  paid,
  unpaid,
  info,
  neutral,
}

/// Badge status ringkas dengan warna semantik dari tema.
class StatusChip extends StatelessWidget {
  const StatusChip(
    this.status, {
    super.key,
    this.label,
    this.icon,
    this.compact = false,
  });

  final AppStatus status;
  final String? label;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;

    final String defaultLabel;
    final Color background;
    final Color foreground;

    switch (status) {
      case AppStatus.booking:
        defaultLabel = 'Booking';
        background = semantic.infoContainer;
        foreground = semantic.onInfoContainer;
        break;
      case AppStatus.member:
        defaultLabel = 'Member Fleet';
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        break;
      case AppStatus.walkIn:
        defaultLabel = 'Walk-in';
        background = semantic.neutralContainer;
        foreground = semantic.onNeutralContainer;
        break;
      case AppStatus.readyToExit:
        defaultLabel = 'Siap keluar';
        background = semantic.successContainer;
        foreground = semantic.onSuccessContainer;
        break;
      case AppStatus.inProgress:
        defaultLabel = 'Pengerjaan';
        background = semantic.warningContainer;
        foreground = semantic.onWarningContainer;
        break;
      case AppStatus.paid:
        defaultLabel = 'LUNAS';
        background = semantic.successContainer;
        foreground = semantic.onSuccessContainer;
        break;
      case AppStatus.unpaid:
        defaultLabel = 'BELUM LUNAS';
        background = semantic.warningContainer;
        foreground = semantic.onWarningContainer;
        break;
      case AppStatus.info:
        defaultLabel = 'Informasi';
        background = semantic.infoContainer;
        foreground = semantic.onInfoContainer;
        break;
      case AppStatus.neutral:
        defaultLabel = 'Netral';
        background = semantic.neutralContainer;
        foreground = semantic.onNeutralContainer;
        break;
    }

    final text = label ?? defaultLabel;

    return Semantics(
      label: text,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: foreground.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      fontSize: compact ? 11 : 11.5,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
