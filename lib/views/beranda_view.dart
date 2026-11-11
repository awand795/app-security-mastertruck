import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/active_vehicle_model.dart';
import '../models/memo_keluar_model.dart';
import '../services/api_service.dart';
import '../widgets/app_widgets.dart';

/// Data yang sudah tersedia dari ApiService untuk ringkasan Beranda.
typedef BerandaData = ({List<ActiveVehicle> active, List<MemoKeluar> exited});

class BerandaView extends StatefulWidget {
  const BerandaView({
    super.key,
    required this.officerName,
    required this.onOpenProfile,
    required this.onOpenTab,
    required this.onOpenCheckout,
    this.refreshToken = 0,
    this.loadData,
    this.clock,
  });

  final String officerName;
  final VoidCallback onOpenProfile;

  /// Indeks tab: 1 = Masuk, 2 = Di Dalam, 3 = Keluar.
  final ValueChanged<int> onOpenTab;
  final ValueChanged<String> onOpenCheckout;

  /// Dinaikkan oleh app shell setiap kali Beranda dipilih lagi.
  final int refreshToken;

  /// Opsional untuk preview test; produksi memakai ApiService.
  final Future<BerandaData> Function()? loadData;

  /// Opsional agar sapaan, tanggal, dan durasi di preview stabil.
  final DateTime Function()? clock;

  @override
  State<BerandaView> createState() => _BerandaViewState();
}

class _BerandaViewState extends State<BerandaView> {
  BerandaData? _data;
  bool _isLoading = true;
  bool _hasError = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BerandaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<BerandaData> _fetchFromApi() async {
    final activeFuture = ApiService.getActiveInside();
    final exitedFuture = ApiService.getMemoKeluar();
    return (active: await activeFuture, exited: await exitedFuture);
  }

  Future<void> _load({bool showSkeleton = false}) async {
    final requestId = ++_requestId;
    if (showSkeleton && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final data = await (widget.loadData ?? _fetchFromApi)();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _data = data;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      if (_data == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal memperbarui data. Periksa koneksi internet lalu coba lagi.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock?.call() ?? DateTime.now();
    final active = _data?.active ?? const <ActiveVehicle>[];
    final readyCount = active.where((vehicle) => vehicle.isSiapKeluar).length;
    final exitedToday =
        _data?.exited.where((memo) => _isSameDay(memo.waktuKeluar, now)).length ??
            0;
    final recent = _recentVehicles(active);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              _GreetingHeader(
                officerName: widget.officerName,
                now: now,
                onOpenProfile: widget.onOpenProfile,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isLoading) ...[
                const SkeletonList(
                  scrollable: false,
                  itemCount: 3,
                  padding: EdgeInsets.zero,
                  itemHeight: 144,
                ),
              ] else if (_hasError && _data == null) ...[
                SizedBox(
                  height: 320,
                  child: ErrorState(
                    compact: true,
                    message:
                        'Periksa koneksi internet lalu muat ulang ringkasan gerbang.',
                    onRetry: () => _load(showSkeleton: true),
                  ),
                ),
              ] else ...[
                _SummaryCard(
                  insideCount: active.length,
                  readyCount: readyCount,
                  exitedToday: exitedToday,
                  onTap: () => widget.onOpenTab(2),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: 'Aksi cepat',
                  subtitle: 'Alur tercepat untuk petugas gerbang',
                ),
                const SizedBox(height: AppSpacing.sm),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Scan Plat Masuk',
                          caption: 'Catat kendaraan',
                          background: Theme.of(context).colorScheme.primary,
                          foreground: Theme.of(context).colorScheme.onPrimary,
                          onTap: () => widget.onOpenTab(1),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.exit_to_app_rounded,
                          label: 'Scan Plat Keluar',
                          caption: 'Validasi invoice',
                          background: context.semantic.warningContainer,
                          foreground: context.semantic.onWarningContainer,
                          onTap: () => widget.onOpenTab(3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Kendaraan terbaru',
                  trailing: active.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => widget.onOpenTab(2),
                          child: const Text('Lihat semua'),
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (recent.isEmpty)
                  SizedBox(
                    height: 250,
                    child: EmptyState(
                      compact: true,
                      icon: Icons.local_shipping_outlined,
                      title: 'Belum ada kendaraan',
                      message:
                          'Kendaraan yang sudah check-in akan muncul di sini.',
                      actionLabel: 'Scan Plat Masuk',
                      actionIcon: Icons.qr_code_scanner_rounded,
                      onAction: () => widget.onOpenTab(1),
                    ),
                  )
                else
                  for (var index = 0; index < recent.length; index++) ...[
                    if (index > 0) const SizedBox(height: AppSpacing.sm),
                    _VehicleCard(
                      vehicle: recent[index],
                      now: now,
                      onTap: () =>
                          widget.onOpenCheckout(recent[index].noPolisi),
                    ),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.officerName,
    required this.now,
    required this.onOpenProfile,
  });

  final String officerName;
  final DateTime now;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.corporateNavy,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Image.asset(
                'assets/images/master-truck-logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shield_rounded,
                  color: AppTheme.amberGold,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MasterTruck',
                    style: texts.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('Pos Gerbang KIM 3', style: texts.bodySmall),
                ],
              ),
            ),
            InitialsAvatar(
              name: officerName,
              size: 44,
              onTap: onOpenProfile,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '${_greeting(now)},',
          style: texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        Text(
          officerName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: texts.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_dateLabel(now)} · Pos Gerbang KIM 3',
                maxLines: 2,
                style: texts.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.insideCount,
    required this.readyCount,
    required this.exitedToday,
    required this.onTap,
  });

  final int insideCount;
  final int readyCount;
  final int exitedToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final isDark = context.isDarkMode;
    final background = isDark ? scheme.surfaceContainerHigh : scheme.primary;
    final foreground = isDark ? scheme.onSurface : scheme.onPrimary;
    final muted = foreground.withValues(alpha: 0.72);
    final divider = foreground.withValues(alpha: 0.16);

    return AppCard(
      onTap: onTap,
      backgroundColor: background,
      borderColor: isDark ? scheme.outlineVariant : background,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(
              Icons.local_shipping_rounded,
              size: 124,
              color: foreground.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_rounded, size: 18, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'KENDARAAN DI DALAM',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texts.labelMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$insideCount',
                    style: texts.displayMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.xs,
                      bottom: 6,
                    ),
                    child: Text(
                      'unit',
                      style: texts.bodyMedium?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(height: 1, color: divider),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Siap keluar',
                      value: '$readyCount',
                      color: foreground,
                      muted: muted,
                    ),
                  ),
                  Container(width: 1, height: 34, color: divider),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MiniStat(
                      label: 'Keluar hari ini',
                      value: '$exitedToday',
                      color: foreground,
                      muted: muted,
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: foreground, size: 20),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.muted,
  });

  final String label;
  final String value;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      semanticLabel: '$label. $caption',
      backgroundColor: background,
      borderColor: background,
      showShadow: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: foreground, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: texts.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: texts.bodySmall?.copyWith(
              color: foreground.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.now,
    required this.onTap,
  });

  final ActiveVehicle vehicle;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final semantic = context.semantic;
    final isReady = vehicle.isSiapKeluar;

    return AppCard(
      onTap: onTap,
      semanticLabel:
          '${vehicle.noPolisi}, ${vehicle.namaPengemudi ?? 'pengemudi belum tercatat'}, '
          '${isReady ? 'siap keluar' : 'pengerjaan'}',
      accentColor: isReady ? semantic.success : semantic.warning,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 2,
        AppSpacing.sm,
        AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PlateBadge(vehicle.noPolisi, size: PlateBadgeSize.small),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(
                          isReady ? AppStatus.readyToExit : AppStatus.inProgress,
                          compact: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  vehicle.namaPengemudi ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDuration(vehicle.waktuCheckIn, now)} di dalam',
                      style: texts.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        '· ${vehicle.tipeKunjungan ?? 'Service'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texts.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

String _greeting(DateTime now) {
  final hour = now.hour;
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}

String _dateLabel(DateTime date) {
  try {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
  } catch (_) {
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  }
}

List<ActiveVehicle> _recentVehicles(List<ActiveVehicle> vehicles) {
  final sorted = [...vehicles]..sort((a, b) {
      final aTime = a.waktuCheckIn;
      final bTime = b.waktuCheckIn;
      if (aTime == null && bTime == null) return b.id.compareTo(a.id);
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  return sorted.take(3).toList(growable: false);
}

String _formatDuration(DateTime? since, DateTime now) {
  if (since == null) return '-';
  final duration = now.difference(since);
  if (duration.isNegative || duration.inMinutes < 1) return 'Baru saja';
  if (duration.inHours < 1) return '${duration.inMinutes}m';
  if (duration.inDays < 1) {
    return '${duration.inHours}j ${duration.inMinutes % 60}m';
  }
  return '${duration.inDays}h ${duration.inHours % 24}j';
}

bool _isSameDay(DateTime? value, DateTime reference) {
  if (value == null) return false;
  return value.year == reference.year &&
      value.month == reference.month &&
      value.day == reference.day;
}
