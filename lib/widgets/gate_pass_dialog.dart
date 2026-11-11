import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/theme.dart';
import '../utils/plate_utils.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'info_row.dart';
import 'plate_badge.dart';
import 'sticky_bottom_bar.dart';

/// Struk digital full-page untuk check-in dan check-out.
///
/// Nama dan parameter konstruktor dipertahankan agar pemanggil lama tetap
/// kompatibel. Tampilan berubah menjadi halaman penuh dengan animasi tanda
/// berhasil, QR, tombol bagikan, dan tombol selesai.
class GatePassDialog extends StatefulWidget {
  final String? title;
  final String? codeNumber;
  final String? nomorTiket;
  final String? nomorMemo;
  final String noPolisi;
  final String? namaPengemudi;
  final String? driverName;
  final String? customerName;
  final String? tipeKunjungan;
  final String? keluhan;
  final String? waktuMasuk;
  final String? waktuKeluar;
  final String? spkNumber;
  final String? invoiceNumber;
  final String? petugasSecurity;
  final DateTime? dateTime;
  final bool isExit;
  final String? uploadWarning;
  final VoidCallback? onClose;

  const GatePassDialog({
    super.key,
    this.title,
    this.codeNumber,
    this.nomorTiket,
    this.nomorMemo,
    String? nopol,
    String? noPolisi,
    this.namaPengemudi,
    this.driverName,
    this.customerName,
    this.tipeKunjungan,
    this.keluhan,
    this.waktuMasuk,
    this.waktuKeluar,
    this.spkNumber,
    this.invoiceNumber,
    this.petugasSecurity,
    this.dateTime,
    this.isExit = true,
    this.uploadWarning,
    this.onClose,
  }) : noPolisi = noPolisi ?? nopol ?? '';

  @override
  State<GatePassDialog> createState() => _GatePassDialogState();
}

class _GatePassDialogState extends State<GatePassDialog> {
  bool _closed = false;

  void _finish(BuildContext context) {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop();
    widget.onClose?.call();
  }

  bool get _isExitPass =>
      widget.nomorMemo != null ||
      widget.waktuKeluar != null ||
      (widget.title?.toLowerCase().contains('keluar') ?? false) ||
      (widget.codeNumber != null && widget.nomorTiket == null) ||
      (widget.isExit && widget.nomorTiket == null);

  String get _effectiveCode =>
      widget.codeNumber ?? widget.nomorMemo ?? widget.nomorTiket ?? 'KIM3-PASS';

  String get _effectiveDriver =>
      widget.namaPengemudi ?? widget.driverName ?? '-';

  String get _effectiveTitle =>
      widget.title ?? (_isExitPass ? 'Gate Pass Keluar' : 'Tiket Masuk');

  Future<void> _showShareSheet(
    BuildContext context, {
    required String code,
    required String title,
  }) async {
    final summary = [
      title,
      'Nomor polisi: ${formatPlate(widget.noPolisi)}',
      'Kode: $code',
      'Pengemudi: $_effectiveDriver',
      if (widget.customerName != null && widget.customerName!.isNotEmpty)
        'Pelanggan: ${widget.customerName}',
      'Waktu: ${DateFormat('dd MMM yyyy, HH:mm').format(widget.dateTime ?? DateTime.now())}',
    ].join('\n');

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final texts = Theme.of(sheetContext).textTheme;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bagikan Gate Pass',
                  style: texts.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Salin ringkasan lalu tempel di WhatsApp atau aplikasi lain.',
                  style: texts.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Salin ringkasan'),
                  subtitle: const Text(
                    'Nomor polisi, kode, pengemudi, dan waktu',
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Clipboard.setData(ClipboardData(text: summary));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ringkasan gate pass disalin.'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: const Text('Salin kode gate pass'),
                  subtitle: Text(code),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kode gate pass disalin.')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;
    final nowFormatted = DateFormat('dd MMM yyyy, HH:mm')
        .format(widget.dateTime ?? DateTime.now());
    final heroTitle = _isExitPass ? 'Kendaraan Keluar' : 'Kendaraan Masuk';
    final heroMessage = _isExitPass
        ? 'Gate pass keluar berhasil diterbitkan.'
        : 'Tiket masuk berhasil diterbitkan.';
    final codeLabel = _isExitPass ? 'Nomor memo' : 'Nomor tiket';

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.antiAlias,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _finish(context);
        },
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/master-truck-logo-transparent.png',
                                height: 28,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.shield_rounded,
                                  color: scheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Master Truck KIM 3',
                                      style: texts.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      _effectiveTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: texts.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Tutup',
                                onPressed: () => _finish(context),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SuccessMark(isExit: _isExitPass),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            heroTitle,
                            textAlign: TextAlign.center,
                            style: texts.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            heroMessage,
                            textAlign: TextAlign.center,
                            style: texts.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (widget.uploadWarning != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: semantic.warningContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: semantic.warning.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.cloud_off_rounded,
                                    size: 20,
                                    color: semantic.onWarningContainer,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      widget.uploadWarning!,
                                      style: texts.bodySmall?.copyWith(
                                        color: semantic.onWarningContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppCard(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: PlateBadge(
                                    widget.noPolisi,
                                    size: PlateBadgeSize.xlarge,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                      border: Border.all(
                                        color: scheme.outlineVariant,
                                      ),
                                    ),
                                    child: QrImageView(
                                      data: _effectiveCode,
                                      version: QrVersions.auto,
                                      size: 180,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF0F172A),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape:
                                            QrDataModuleShape.square,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _effectiveCode,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.plateStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ).copyWith(color: scheme.onSurface),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  '$codeLabel • Tunjukkan QR ini kepada petugas gerbang.',
                                  textAlign: TextAlign.center,
                                  style: texts.bodySmall,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Divider(color: scheme.outlineVariant),
                                const SizedBox(height: AppSpacing.xs),
                                InfoRow(
                                  label: 'Waktu',
                                  value: nowFormatted,
                                  dense: true,
                                ),
                                InfoRow(
                                  label: 'Pengemudi',
                                  value: _effectiveDriver,
                                  dense: true,
                                ),
                                if (widget.customerName != null &&
                                    widget.customerName!.isNotEmpty)
                                  InfoRow(
                                    label: 'Pelanggan',
                                    value: widget.customerName!,
                                    dense: true,
                                  ),
                                if (widget.tipeKunjungan != null &&
                                    widget.tipeKunjungan!.isNotEmpty)
                                  InfoRow(
                                    label: 'Tujuan',
                                    value: widget.tipeKunjungan!,
                                    dense: true,
                                  ),
                                if (widget.keluhan != null &&
                                    widget.keluhan!.isNotEmpty)
                                  InfoRow(
                                    label: 'Keluhan',
                                    value: widget.keluhan!,
                                    dense: true,
                                  ),
                                if (widget.waktuMasuk != null &&
                                    widget.waktuMasuk!.isNotEmpty)
                                  InfoRow(
                                    label: 'Masuk',
                                    value: widget.waktuMasuk!,
                                    dense: true,
                                  ),
                                if (widget.waktuKeluar != null &&
                                    widget.waktuKeluar!.isNotEmpty)
                                  InfoRow(
                                    label: 'Keluar',
                                    value: widget.waktuKeluar!,
                                    dense: true,
                                  ),
                                if (widget.spkNumber != null &&
                                    widget.spkNumber!.isNotEmpty)
                                  InfoRow(
                                    label: 'No. SPK',
                                    value: widget.spkNumber!,
                                    dense: true,
                                  ),
                                if (widget.invoiceNumber != null &&
                                    widget.invoiceNumber!.isNotEmpty)
                                  InfoRow(
                                    label: 'No. Invoice',
                                    value: widget.invoiceNumber!,
                                    dense: true,
                                  ),
                                if (widget.petugasSecurity != null &&
                                    widget.petugasSecurity!.isNotEmpty)
                                  InfoRow(
                                    label: 'Petugas',
                                    value: widget.petugasSecurity!,
                                    dense: true,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 16,
                                color: semantic.success,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Dokumen digital sah. Simpan sebagai bukti kendaraan.',
                                  textAlign: TextAlign.center,
                                  style: texts.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            StickyBottomBar(
              maxWidth: 520,
              hint: _isExitPass
                  ? 'Pastikan kendaraan sudah keluar gerbang.'
                  : 'Simpan tiket ini sampai kendaraan keluar.',
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Bagikan',
                      icon: Icons.share_outlined,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.medium,
                      onPressed: () => _showShareSheet(
                        context,
                        code: _effectiveCode,
                        title: _effectiveTitle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Selesai',
                      icon: Icons.check_rounded,
                      size: AppButtonSize.medium,
                      onPressed: () => _finish(context),
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

class _SuccessMark extends StatelessWidget {
  const _SuccessMark({required this.isExit});

  final bool isExit;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Semantics(
      label: isExit ? 'Check-out berhasil' : 'Check-in berhasil',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: semantic.successContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: semantic.success.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 44,
              color: semantic.onSuccessContainer,
            ),
          ),
        ),
      ),
    );
  }
}
