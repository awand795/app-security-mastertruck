import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/memo_keluar_model.dart';
import '../models/ms_foto_model.dart';
import '../services/api_service.dart';
import '../widgets/app_widgets.dart';

enum _ExitDateFilter { today, yesterday, todayAndYesterday }

/// Riwayat kendaraan yang sudah keluar (filter default Hari ini).
///
/// Pencarian memakai [SearchField] yang di-debounce, daftar dapat ditarik
/// untuk menyegarkan data, dan setiap item dapat dibuka detailnya beserta
/// foto dokumentasi kunjungan.
class TodayExitView extends StatefulWidget {
  const TodayExitView({
    super.key,
    this.memoLoader,
    this.photoLoader,
    this.fotoLoader,
    this.photosLoader,
    this.imageLoader,
    this.clock,
  });

  /// Opsional untuk preview/test; produksi memakai [ApiService].
  final Future<List<MemoKeluar>> Function(String query)? memoLoader;

  /// Opsional untuk preview/test foto; produksi memakai [ApiService].
  final Future<List<MsFoto>> Function(int kunjunganId)? photoLoader;
  final Future<List<MsFoto>> Function(int kunjunganId)? fotoLoader;
  final Future<List<MsFoto>> Function(int kunjunganId)? photosLoader;
  final Future<List<MsFoto>> Function(int kunjunganId)? imageLoader;

  /// Opsional agar filter tanggal di preview stabil.
  final DateTime Function()? clock;

  Future<List<MsFoto>> Function(int kunjunganId) get resolvedPhotoLoader =>
      photoLoader ??
      fotoLoader ??
      photosLoader ??
      imageLoader ??
      ((int id) => ApiService.getFotoKunjungan(id));

  @override
  State<TodayExitView> createState() => _TodayExitViewState();
}

class _TodayExitViewState extends State<TodayExitView> {
  final _searchController = TextEditingController();

  List<MemoKeluar> _memos = const [];
  _ExitDateFilter _dateFilter = _ExitDateFilter.today;
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

  String get _dateFilterLabel => switch (_dateFilter) {
    _ExitDateFilter.today => 'Hari ini',
    _ExitDateFilter.yesterday => 'Kemarin',
    _ExitDateFilter.todayAndYesterday => 'Hari ini & kemarin',
  };

  List<MemoKeluar> get _filteredMemos {
    final now = widget.clock?.call() ?? DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final list = _memos.where((m) {
      return switch (_dateFilter) {
        _ExitDateFilter.today => _isSameDay(m.waktuKeluar, now),
        _ExitDateFilter.yesterday => _isSameDay(m.waktuKeluar, yesterday),
        _ExitDateFilter.todayAndYesterday =>
          _isSameDay(m.waktuKeluar, now) ||
              _isSameDay(m.waktuKeluar, yesterday),
      };
    }).toList();
    list.sort((a, b) {
      final ta = a.waktuKeluar?.millisecondsSinceEpoch ?? 0;
      final tb = b.waktuKeluar?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return list;
  }

  void _showDetail(MemoKeluar memo) {
    showDialog<void>(
      context: context,
      builder: (_) => _MemoDetailDialog(
        memo: memo,
        photoLoader: widget.resolvedPhotoLoader,
        clock: widget.clock,
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
                      PopupMenuButton<_ExitDateFilter>(
                        initialValue: _dateFilter,
                        tooltip: 'Pilih rentang hari',
                        onSelected: (value) {
                          if (_dateFilter != value) {
                            setState(() => _dateFilter = value);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ExitDateFilter.today,
                            child: Text('Hari ini'),
                          ),
                          PopupMenuItem(
                            value: _ExitDateFilter.yesterday,
                            child: Text('Kemarin'),
                          ),
                          PopupMenuItem(
                            value: _ExitDateFilter.todayAndYesterday,
                            child: Text('Hari ini & kemarin'),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
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
                                _dateFilterLabel,
                                style: texts.labelSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                            ],
                          ),
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
                              onOpenDetail: () => _showDetail(memo),
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
      title: 'Belum ada kendaraan keluar',
      message: 'Memo gate pass hari ini dan kemarin akan muncul di sini setelah kendaraan check-out.',
      actionLabel: 'Muat ulang',
      actionIcon: Icons.refresh_rounded,
      onAction: () => _loadData(showSkeleton: true, showSearching: false),
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({required this.memo, required this.onOpenDetail});

  final MemoKeluar memo;
  final VoidCallback onOpenDetail;

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
                label: 'Detail',
                icon: Icons.visibility_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.medium,
                expanded: false,
                semanticLabel: 'Lihat detail ${memo.noPolisi}',
                onPressed: onOpenDetail,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoDetailDialog extends StatefulWidget {
  const _MemoDetailDialog({
    required this.memo,
    required this.photoLoader,
    this.clock,
  });

  final MemoKeluar memo;
  final Future<List<MsFoto>> Function(int kunjunganId) photoLoader;
  final DateTime Function()? clock;

  @override
  State<_MemoDetailDialog> createState() => _MemoDetailDialogState();
}

class _MemoDetailDialogState extends State<_MemoDetailDialog> {
  List<MsFoto> _photos = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await widget.photoLoader(widget.memo.id);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _photos = const [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final memo = widget.memo;
    final exitTime = memo.waktuKeluar == null
        ? '-'
        : DateFormat('dd MMM yyyy, HH:mm').format(memo.waktuKeluar!);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detail Memo Keluar',
                      style: texts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PlateBadge(
                      memo.noPolisi,
                      size: PlateBadgeSize.small,
                      maxWidth: 220,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _DetailRow(label: 'Nomor memo', value: memo.nomorMemo),
                    _DetailRow(
                      label: 'Pengemudi',
                      value: memo.namaPengemudi ?? '-',
                    ),
                    _DetailRow(
                      label: 'Pelanggan',
                      value: memo.namaPelanggan ?? '-',
                    ),
                    _DetailRow(
                      label: 'Tujuan',
                      value: memo.subTujuan ?? memo.statusKunjungan,
                    ),
                    _DetailRow(label: 'Waktu keluar', value: exitTime),
                    _DetailRow(
                      label: 'Petugas keluar',
                      value: memo.petugasSecurityKeluar ?? '-',
                    ),
                    _DetailRow(
                      label: 'Gate masuk',
                      value: memo.gateMasukNama ?? '-',
                    ),
                    _DetailRow(
                      label: 'Gate keluar',
                      value: memo.gateKeluarNama ?? '-',
                    ),
                    if (memo.alasanKeluar?.trim().isNotEmpty == true)
                      _DetailRow(
                        label: 'Alasan keluar',
                        value: memo.alasanKeluar!,
                      ),
                    if (memo.catatanKeluar?.trim().isNotEmpty == true)
                      _DetailRow(label: 'Catatan', value: memo.catatanKeluar!),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Dokumentasi Foto (${_photos.length})',
                      style: texts.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_photos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Tidak ada foto dokumentasi tersimpan.',
                          style: texts.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: AppSpacing.xs,
                              crossAxisSpacing: AppSpacing.xs,
                              childAspectRatio: 4 / 3,
                            ),
                        itemCount: _photos.length,
                        itemBuilder: (context, index) {
                          final photo = _photos[index];
                          return _PhotoTile(photo: photo);
                        },
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Tutup',
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.medium,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Gate Pass',
                      icon: Icons.qr_code_2_rounded,
                      size: AppButtonSize.medium,
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Gate pass handled by caller; reopen not needed.
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: texts.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: texts.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});

  final MsFoto photo;

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider(photo.fotoData);
    return GestureDetector(
      onTap: provider == null
          ? null
          : () => _openZoom(context, provider, photo.sudutPandang),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          color: Colors.black12,
          child: provider == null
              ? const Center(child: Icon(Icons.broken_image_rounded))
              : Image(
                  image: provider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image_rounded)),
                ),
        ),
      ),
    );
  }

  void _openZoom(BuildContext context, ImageProvider provider, String title) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image(image: provider, fit: BoxFit.contain),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ImageProvider? _imageProvider(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return NetworkImage(trimmed);
  }

  String base64Part = trimmed;
  if (trimmed.startsWith('data:')) {
    final idx = trimmed.indexOf('base64,');
    if (idx >= 0) {
      base64Part = trimmed.substring(idx + 7);
    } else {
      return null;
    }
  } else {
    // Deteksi hex bytea (Postgres), termasuk yang berawalan \x atau 0x.
    var hexStr = trimmed;
    if (hexStr.startsWith(r'\x') || hexStr.startsWith('0x') || hexStr.startsWith('0X')) {
      hexStr = hexStr.substring(2);
    }
    final head = hexStr.substring(0, hexStr.length.clamp(0, 16));
    if (head.isNotEmpty && RegExp(r'^[0-9a-fA-F]+$').hasMatch(head) && hexStr.length.isEven) {
      try {
        final bytes = <int>[];
        for (var i = 0; i < hexStr.length; i += 2) {
          bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
        }
        return MemoryImage(Uint8List.fromList(bytes));
      } catch (_) {
        // Fall through to base64 handling.
      }
    }
  }

  try {
    return MemoryImage(base64Decode(base64Part));
  } catch (_) {
    return null;
  }
}

bool _isSameDay(DateTime? value, DateTime now) {
  if (value == null) return false;
  return value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
}
