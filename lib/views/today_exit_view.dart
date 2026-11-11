import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/memo_keluar_model.dart';
import '../services/api_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gate_pass_dialog.dart';

/// Riwayat gate pass kendaraan yang sudah keluar hari ini.
///
/// Pencarian memakai [SearchField] yang di-debounce, dan daftar dapat ditarik untuk menyegarkan data.
class TodayExitView extends StatefulWidget {
  const TodayExitView({super.key, this.memoLoader, this.clock});

  /// Opsional untuk preview/test; produksi memakai [ApiService].
  final Future<List<MemoKeluar>> Function(String query)? memoLoader;

  /// Opsional agar filter tanggal di preview stabil.
  final DateTime Function()? clock;

  @override
  State<TodayExitView> createState() => _TodayExitViewState();
}

class _TodayExitViewState extends State<TodayExitView> {
  final _searchController = TextEditingController();

  List<MemoKeluar> _memos = const [];
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
          widget.memoLoader ?? (String q) => ApiService.getMemoKeluar(query: q);
      final data = await loader(effectiveQuery);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _memos = data;
        _isLoading = false;
        _isSearching = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isLoading = false;
        _isSearching = false;
        if (_memos.isEmpty) _hasError = true;
      });
      if (_memos.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui riwayat keluar. Coba lagi.'),
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

  List<MemoKeluar> get _filteredMemos {
    final now = widget.clock?.call() ?? DateTime.now();
    return _memos.where((m) => _isSameDay(m.waktuKeluar, now)).toList();
  }

  void _showGatePass(MemoKeluar memo) {
    showDialog<void>(
      context: context,
      builder: (_) => GatePassDialog(
        title: 'Gate Pass / Memo Keluar Digital',
        codeNumber: memo.nomorMemo,
        nopol: memo.noPolisi,
        driverName: memo.namaPengemudi,
        customerName: memo.namaPelanggan,
        spkNumber: memo.nomorSpk,
        invoiceNumber: memo.nomorInvoice,
        dateTime: memo.waktuKeluar ?? widget.clock?.call() ?? DateTime.now(),
        isExit: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final filtered = _filteredMemos;

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
                    hintText: 'Cari nopol atau nomor memo',
                    isSearching: _isSearching,
                    onChanged: _handleSearch,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${filtered.length} kendaraan keluar',
                          style: texts.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Hari ini (${DateFormat('dd MMM yyyy').format(widget.clock?.call() ?? DateTime.now())})',
                              style: texts.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
                        itemHeight: 176,
                        padding: EdgeInsets.zero,
                      )
                    else if (_hasError)
                      SizedBox(
                        height: 340,
                        child: ErrorState(
                          message:
                              'Periksa koneksi internet lalu muat ulang riwayat '
                              'keluar.',
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
                        final memo = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: StaggeredItem(
                            key: ValueKey('memo-${memo.id}'),
                            index: index,
                            child: _MemoCard(
                              memo: memo,
                              onOpenGatePass: () => _showGatePass(memo),
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

  Widget _buildEmptyState() {
    final hasQuery = _query.trim().isNotEmpty;

    if (hasQuery) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Memo tidak ditemukan',
        message: 'Coba nomor polisi atau nomor memo lain.',
        actionLabel: 'Hapus pencarian',
        actionIcon: Icons.close_rounded,
        onAction: _clearSearch,
      );
    }

    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'Belum ada kendaraan keluar hari ini',
      message:
          'Memo gate pass hari ini akan muncul di sini setelah kendaraan check-out.',
      actionLabel: 'Muat ulang',
      actionIcon: Icons.refresh_rounded,
      onAction: () => _loadData(showSkeleton: true, showSearching: false),
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({required this.memo, required this.onOpenGatePass});

  final MemoKeluar memo;
  final VoidCallback onOpenGatePass;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;
    final driver = memo.namaPengemudi?.trim();
    final customer = memo.namaPelanggan?.trim();
    final exitTime = memo.waktuKeluar == null
        ? '-'
        : DateFormat('dd MMM, HH:mm').format(memo.waktuKeluar!);
    final details = <String>[
      if (memo.nomorSpk?.trim().isNotEmpty == true)
        'SPK ${memo.nomorSpk!.trim()}',
      if (memo.nomorInvoice?.trim().isNotEmpty == true)
        'Invoice ${memo.nomorInvoice!.trim()}',
    ];

    return AppCard(
      accentColor: semantic.info,
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
                    memo.noPolisi,
                    size: PlateBadgeSize.small,
                    maxWidth: 190,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusChip(
                    AppStatus.info,
                    label: 'Keluar',
                    icon: Icons.exit_to_app_rounded,
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
                Icons.schedule_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                exitTime,
                style: texts.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Petugas ${memo.petugasSecurityKeluar ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                details.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: texts.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Memo ${memo.nomorMemo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texts.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton(
                label: 'Gate Pass',
                icon: Icons.qr_code_2_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.medium,
                expanded: false,
                semanticLabel: 'Lihat gate pass ${memo.noPolisi}',
                onPressed: onOpenGatePass,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime? value, DateTime now) {
  if (value == null) return false;
  return value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
}
