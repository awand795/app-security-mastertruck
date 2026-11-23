import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/panduan_apk_model.dart';
import '../services/api_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/html_iframe_box.dart';

/// Halaman Panduan & SOP Petugas Security berbasis HTML / iframe dari tabel `sch_pos.panduan_apk`.
class PanduanSopView extends StatefulWidget {
  const PanduanSopView({super.key, this.loader});

  final Future<List<PanduanApkItem>> Function()? loader;

  @override
  State<PanduanSopView> createState() => _PanduanSopViewState();
}

class _PanduanSopViewState extends State<PanduanSopView> {
  List<PanduanApkItem> _items = [];
  bool _isLoading = true;
  bool _hasError = false;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final list = await (widget.loader ?? ApiService.getPanduanApk)();
      if (!mounted) return;
      final active = list.where((e) => e.isActive).toList()
        ..sort((a, b) {
          final order = a.urutan.compareTo(b.urutan);
          return order != 0 ? order : a.id.compareTo(b.id);
        });
      setState(() {
        _items = active;
        _expandedId = active.isNotEmpty ? active.first.id : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan & SOP Petugas'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SkeletonList(itemCount: 3, itemHeight: 110),
                )
              : _hasError
              ? ErrorState(
                  message: 'Gagal memuat Panduan & SOP dari server.',
                  onRetry: _load,
                )
              : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Belum ada Panduan & SOP',
                  message: 'Data panduan aktif pada tabel panduan_apk akan tampil di sini.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final expanded = _expandedId == item.id;
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              onTap: () {
                                setState(() {
                                  _expandedId = expanded ? null : item.id;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: texts.labelLarge?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              StatusChip(
                                                item.kategori == 'SOP'
                                                    ? AppStatus.info
                                                    : AppStatus.readyToExit,
                                                label: item.kategori,
                                                compact: true,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                item.kode,
                                                style: texts.labelSmall
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.judul,
                                            style: texts.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      expanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedSize(
                              duration: AppDurations.normal,
                              curve: Curves.easeOutCubic,
                              child: expanded
                                  ? Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.md,
                                        0,
                                        AppSpacing.md,
                                        AppSpacing.md,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        child: HtmlIframeBox(
                                          key: ValueKey(
                                            'panduan-${item.id}-${item.kode}',
                                          ),
                                          htmlContent: item.kontenHtml,
                                          fallbackTitle: item.judul,
                                          height: 260,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
