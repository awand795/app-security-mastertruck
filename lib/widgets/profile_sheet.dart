import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'info_row.dart';
import 'initials_avatar.dart';
import 'status_chip.dart';

/// Sheet profil petugas. Logout tidak lagi berada di AppBar, melainkan di sini.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final UserSession? session;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final name = session?.name ?? 'Petugas Security';
    final role = session?.role ?? 'SECURITY';
    final branch = session?.namaCabang ??
        (session?.kodeCabang != null
            ? 'Cabang ${session!.kodeCabang}'
            : 'Bengkel Master Truck KIM 3');

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    InitialsAvatar(name: name, size: 64),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: texts.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          const StatusChip(
                            AppStatus.info,
                            label: 'Sesi aktif',
                            icon: Icons.verified_user_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  showShadow: false,
                  child: Column(
                    children: [
                      InfoRow(
                        label: 'ID Petugas',
                        value: session?.userId ?? '-',
                        icon: Icons.badge_outlined,
                      ),
                      Divider(height: AppSpacing.lg, color: scheme.outlineVariant),
                      InfoRow(
                        label: 'Peran',
                        value: role.toUpperCase(),
                        icon: Icons.admin_panel_settings_outlined,
                      ),
                      Divider(height: AppSpacing.lg, color: scheme.outlineVariant),
                      InfoRow(
                        label: 'Penempatan',
                        value: branch,
                        icon: Icons.location_on_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Pastikan Anda keluar dari akun setelah shift berakhir agar sesi '
                  'petugas berikutnya tetap aman.',
                  style: texts.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Keluar dari Akun',
                  icon: Icons.logout_rounded,
                  variant: AppButtonVariant.danger,
                  onPressed: onLogout,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'MasterTruck · Pos Security Gerbang KIM 3',
                  textAlign: TextAlign.center,
                  style: texts.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
