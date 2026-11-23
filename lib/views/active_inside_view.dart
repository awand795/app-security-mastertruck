import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/active_vehicle_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

enum _InsideFilter { all, inside, tempOut }

/// Daftar kendaraan yang masih berada di dalam bengkel.
///
/// Pencarian memakai [SearchField] yang sudah di-debounce, filter bekerja di
/// sisi klien, dan daftar dapat ditarik untuk menyegarkan data.
class ActiveInsideView extends StatefulWidget {
  const ActiveInsideView({
    super.key,
    this.onNavigateToCheckout,
    this.vehicleLoader,
    this.clock,
  });

  final ValueChanged<String>? onNavigateToCheckout;

  /// Opsional untuk preview/test; produksi memakai [ApiService].
  final Future<List<ActiveVehicle>> Function(String query)? vehicleLoader;

  /// Opsional agar durasi di preview stabil.
  final DateTime Function()? clock;

  @override
  State<ActiveInsideView> createState() => _ActiveInsideViewState();
}

class _ActiveInsideViewState extends State<ActiveInsideView> {
  final _searchController = TextEditingController();

  List<ActiveVehicle> _vehicles = const [];
  _InsideFilter _filter = _InsideFilter.all;
  String _query = '';
  bool _isLoading = true;
  bool _isSearching = false;
  bool _hasError = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadData(showSkeleton: true, showSearching: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({
    String? query,
    bool showSkeleton = false,
    bool showSearching = true,
  }) async {
    final requestId = ++_requestId;
    final effectiveQuery = query ?? _query;
    _query = effectiveQuery;

    if (!mounted) return;
    setState(() {
      if (showSkeleton) {
        _isLoading = true;
        _hasError = false;
      }
      if (showSearching) _isSearching = true;
    });

    try {
      final loader =
          widget.vehicleLoader ??
          (String q) => ApiService.getActiveInside(query: q);
      final data = await loader(effectiveQuery);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _vehicles = data;
        _isLoading = false;
        _isSearching = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isLoading = false;
        _isSearching = false;
        if (_vehicles.isEmpty) _hasError = true;
      });
      if (_vehicles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui daftar kendaraan. Coba lagi.'),
          ),
        );
      }
    }
  }

  void _handleSearch(String value) {
    if (value == _query) return;
    _loadData(query: value);
  }

  void _clearSearch() {
    _searchController.clear();
    _loadData(query: '', showSearching: false);
  }

  void _selectFilter(_InsideFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
  }

  List<ActiveVehicle> get _filteredVehicles {
    switch (_filter) {
      case _InsideFilter.all:
        return _vehicles;
      case _InsideFilter.inside:
        return _vehicles.where((v) => !v.isKeluarSementara).toList();
      case _InsideFilter.tempOut:
        return _vehicles.where((v) => v.isKeluarSementara).toList();
    }
  }

  int get _tempOutCount => _vehicles.where((v) => v.isKeluarSementara).length;
  int get _insideCount => _vehicles.where((v) => !v.isKeluarSementara).length;

  Future<void> _handleReEnter(ActiveVehicle vehicle) async {
    final session = AuthService.currentSession;
    final res = await ApiService.postReEnter(
      kunjunganId: vehicle.id,
      petugasSecurity: session?.name ?? 'Security',
      gateMasukId: session?.gateId,
      gateMasukName: session?.gateName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? 'Berhasil masuk kembali.'),
      ),
    );
    if (res['success'] == true) {
      _loadData(query: _query, showSearching: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;
    final filtered = _filteredVehicles;
    final now = widget.clock?.call() ?? DateTime.now();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SearchField(
                    controller: _searchController,
                    hintText: 'Cari nopol, pengemudi, atau keluhan',
                    isSearching: _isSearching,
                    onChanged: _handleSearch,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${filtered.length} kendaraan',
                          style: texts.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '$_insideCount di bengkel · $_tempOutCount keluar sementara',
                        style: texts.bodySmall?.copyWith(
                          color: _tempOutCount > 0
                              ? semantic.warning
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _buildFilterChip(
                        label: 'Semua (${_vehicles.length})',
                        selected: _filter == _InsideFilter.all,
                        onSelected: () => _selectFilter(_InsideFilter.all),
                      ),
                      _buildFilterChip(
                        label: 'Di Bengkel ($_insideCount)',
                        selected: _filter == _InsideFilter.inside,
                        onSelected: () => _selectFilter(_InsideFilter.inside),
                      ),
                      _buildFilterChip(
                        label: 'Keluar Sementara ($_tempOutCount)',
                        selected: _filter == _InsideFilter.tempOut,
                        onSelected: () => _selectFilter(_InsideFilter.tempOut),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadData(query: _query, showSearching: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  children: [
                    if (_isLoading)
                      const SkeletonList(
                        itemCount: 4,
                        scrollable: false,
                        itemHeight: 158,
                        padding: EdgeInsets.zero,
                      )
                    else if (_hasError)
                      SizedBox(
                        height: 340,
                        child: ErrorState(
                          message:
                              'Periksa koneksi internet lalu muat ulang daftar '
                              'kendaraan.',
                          onRetry: () => _loadData(
                            showSkeleton: true,
                            showSearching: false,
                          ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      SizedBox(height: 360, child: _buildEmptyState())
                    else
                      ...List<Widget>.generate(filtered.length, (index) {
                        final vehicle = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: StaggeredItem(
                            key: ValueKey('inside-${vehicle.id}'),
                            index: index,
                            child: _ActiveVehicleCard(
                              vehicle: vehicle,
                              now: now,
                              onReEnter: vehicle.isKeluarSementara
                                  ? () => _handleReEnter(vehicle)
                                  : null,
                              onCheckout:
                                  widget.onNavigateToCheckout == null ||
                                      vehicle.isKeluarSementara
                                  ? null
                                  : () => widget.onNavigateToCheckout!(
                                      vehicle.noPolisi,
                                    ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: texts.labelLarge?.copyWith(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasQuery = _query.trim().isNotEmpty;
    final hasFilter = _filter != _InsideFilter.all;

    if (hasQuery) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Kendaraan tidak ditemukan',
        message: 'Coba kata kunci lain atau hapus pencarian.',
        actionLabel: 'Hapus pencarian',
        actionIcon: Icons.close_rounded,
        onAction: _clearSearch,
      );
    }

    if (hasFilter) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'Tidak ada kendaraan pada filter ini',
        message: 'Tampilkan semua kendaraan untuk melihat daftar lengkap.',
        actionLabel: 'Tampilkan semua',
        actionIcon: Icons.filter_alt_off_rounded,
        onAction: () => _selectFilter(_InsideFilter.all),
      );
    }

    return EmptyState(
      icon: Icons.local_shipping_outlined,
      title: 'Belum ada kendaraan di dalam',
      message:
          'Kendaraan yang sudah check-in akan muncul di sini untuk dipantau.',
      actionLabel: 'Muat ulang',
      actionIcon: Icons.refresh_rounded,
      onAction: () => _loadData(showSkeleton: true, showSearching: false),
    );
  }
}

class _ActiveVehicleCard extends StatelessWidget {
  const _ActiveVehicleCard({
    required this.vehicle,
    required this.now,
    this.onCheckout,
    this.onReEnter,
  });

  final ActiveVehicle vehicle;
  final DateTime now;
  final VoidCallback? onCheckout;
  final VoidCallback? onReEnter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;
    final ready = vehicle.isSiapKeluar;
    final isTempOut = vehicle.isKeluarSementara;
    final driver = vehicle.namaPengemudi?.trim();
    final customer = vehicle.namaPelanggan?.trim();
    final complaint = vehicle.keluhan?.trim();
    final checkInTime = vehicle.waktuCheckIn == null
        ? '-'
        : DateFormat('HH:mm').format(vehicle.waktuCheckIn!);
    final duration = _formatDuration(vehicle.waktuCheckIn, now);
    final statusLabel = isTempOut
        ? 'Keluar Sementara'
        : (vehicle.isServicePengerjaan && vehicle.hasWo
              ? (vehicle.hasFir ? 'FIR Siap' : 'Belum FIR')
              : (vehicle.subTujuan ?? vehicle.tipeKunjungan ?? 'Di Bengkel'));

    return AppCard(
      accentColor: ready ? semantic.success : semantic.warning,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PlateBadge(
                    vehicle.noPolisi,
                    size: PlateBadgeSize.small,
                    maxWidth: 190,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusChip(
                    ready ? AppStatus.readyToExit : AppStatus.inProgress,
                    label: statusLabel,
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            driver != null && driver.isNotEmpty
                ? driver
                : 'Pengemudi belum tercatat',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (customer != null && customer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                customer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: texts.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                duration,
                style: texts.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  'di dalam · masuk $checkInTime',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (complaint != null && complaint.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    complaint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: texts.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiket ${vehicle.nomorTiket ?? '-'}'
                      '${vehicle.gateMasukNama != null ? ' · ${vehicle.gateMasukNama}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texts.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isTempOut &&
                        vehicle.alasanKeluar != null &&
                        vehicle.alasanKeluar!.isNotEmpty)
                      Text(
                        'Alasan: ${vehicle.alasanKeluar}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texts.bodySmall?.copyWith(
                          color: semantic.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (onReEnter != null) ...[
                const SizedBox(width: AppSpacing.xs),
                AppButton(
                  label: 'Masuk Kembali',
                  icon: Icons.login_rounded,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  expanded: false,
                  onPressed: onReEnter,
                ),
              ] else if (onCheckout != null) ...[
                const SizedBox(width: AppSpacing.xs),
                AppButton(
                  label: 'Proses Keluar',
                  icon: Icons.exit_to_app_rounded,
                  variant: ready
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  size: AppButtonSize.medium,
                  expanded: false,
                  semanticLabel: 'Proses keluar untuk ${vehicle.noPolisi}',
                  onPressed: onCheckout,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(DateTime? since, DateTime now) {
  if (since == null) return '-';
  final difference = now.difference(since);
  if (difference.isNegative || difference.inMinutes < 1) return 'Baru saja';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) {
    return '${difference.inHours}j ${difference.inMinutes % 60}m';
  }
  return '${difference.inDays}h ${difference.inHours % 24}j';
}
