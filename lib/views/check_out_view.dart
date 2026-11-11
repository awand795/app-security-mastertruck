import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/active_vehicle_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/plate_utils.dart';
import '../widgets/anpr_scanner_sheet.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gate_pass_dialog.dart';
import '../widgets/photo_quad_picker.dart';

class CheckOutView extends StatefulWidget {
  final String? initialPlate;
  final VoidCallback? onClearInitialPlate;

  /// Opsional untuk preview/test; produksi memakai ApiService.
  final Future<List<ActiveVehicle>> Function(String query)? vehicleLoader;

  const CheckOutView({
    super.key,
    this.initialPlate,
    this.onClearInitialPlate,
    this.vehicleLoader,
  });

  @override
  State<CheckOutView> createState() => _CheckOutViewState();
}

class _CheckOutViewState extends State<CheckOutView> {
  final _nopolController = TextEditingController();
  final _notesController = TextEditingController();

  ActiveVehicle? _selectedVehicle;
  bool _isLoading = false;
  bool _hasLookedUp = false;
  bool _isSubmitting = false;
  final Map<String, String> _exitPhotos = {};
  int? _uploadCurrent;
  int? _uploadTotal;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlate != null && widget.initialPlate!.isNotEmpty) {
      _nopolController.text = formatPlate(widget.initialPlate!);
      _lookupVehicle(widget.initialPlate!);
    }
  }

  @override
  void dispose() {
    _nopolController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openAnprScanner() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => AnprScannerSheet(
        onPlateDetected: (plate) {
          if (!mounted) return;
          final formatted = formatPlate(plate);
          setState(() {
            _nopolController.text = formatted;
            _notesController.clear();
            _exitPhotos.clear();
          });
          _lookupVehicle(formatted);
        },
      ),
    );
  }

  Future<void> _lookupVehicle(String nopol) async {
    final clean = normalizePlate(nopol);
    if (clean.isEmpty) {
      _showSnackBar('Masukkan nomor polisi terlebih dahulu.');
      return;
    }

    setState(() {
      _isLoading = true;
      _selectedVehicle = null;
      _hasLookedUp = false;
    });

    try {
      final loader =
          widget.vehicleLoader ??
          (String query) => ApiService.getActiveInside(query: query);
      final list = await loader(clean);
      if (!mounted) return;

      ActiveVehicle? found;
      for (final vehicle in list) {
        if (normalizePlate(vehicle.noPolisi) == clean) {
          found = vehicle;
          break;
        }
      }

      setState(() {
        _isLoading = false;
        _hasLookedUp = true;
        // Jangan pernah memilih kendaraan lain secara otomatis. Nomor polisi
        // harus cocok persis agar petugas tidak memproses unit yang salah.
        _selectedVehicle = found;
      });

      if (_selectedVehicle == null) {
        _showSnackBar(
          'Nomor polisi tidak cocok dengan kendaraan di dalam bengkel.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLookedUp = true;
      });
      _showSnackBar('Gagal mencari kendaraan. Coba lagi.');
    }
  }

  void _clearPlate() {
    _nopolController.clear();
    setState(() {
      _selectedVehicle = null;
      _hasLookedUp = false;
      _exitPhotos.clear();
      _notesController.clear();
    });
    widget.onClearInitialPlate?.call();
  }

  void _handlePlateChanged(String _) {
    if (_selectedVehicle == null && !_hasLookedUp) return;
    setState(() {
      _selectedVehicle = null;
      _hasLookedUp = false;
      _exitPhotos.clear();
      _notesController.clear();
    });
  }

  Future<bool?> _showUnpaidWarning(ActiveVehicle vehicle) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) {
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
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: semantic.warningContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: semantic.onWarningContainer,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Invoice belum lunas',
                        style: texts.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Invoice ${vehicle.nomorInvoice ?? '-'} untuk '
                  '${formatPlate(vehicle.noPolisi)} belum lunas. '
                  'Tetap izinkan kendaraan keluar gerbang?',
                  style: texts.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Batal',
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.medium,
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Izinkan',
                        icon: Icons.exit_to_app_rounded,
                        size: AppButtonSize.medium,
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCheckOut() async {
    final vehicle = _selectedVehicle;
    if (vehicle == null) {
      _showSnackBar('Pilih atau cari kendaraan terlebih dahulu.');
      return;
    }

    if (!vehicle.isSiapKeluar) {
      final confirmed = await _showUnpaidWarning(vehicle);
      if (confirmed != true) return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadCurrent = null;
      _uploadTotal = null;
    });

    final petugas = AuthService.currentSession?.name ?? 'Pos Security KIM 3';
    final res = await ApiService.postCheckOut(
      kunjunganId: vehicle.id,
      petugasSecurityKeluar: petugas,
      catatanKeluar: _notesController.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final nomorMemo = res['nomor_memo'] ?? 'MEMO-KIM3';
      var failedUploads = 0;
      var totalUploads = 0;

      if (_exitPhotos.isNotEmpty) {
        final entries = _exitPhotos.entries.toList();
        totalUploads = entries.length;
        setState(() {
          _uploadTotal = entries.length;
          _uploadCurrent = 0;
        });

        for (var index = 0; index < entries.length; index++) {
          if (!mounted) return;
          setState(() => _uploadCurrent = index + 1);
          try {
            final uploaded = await ApiService.postAddFoto(
              kunjunganId: vehicle.id,
              jenisEvent: 'KELUAR',
              sudutPandang: entries[index].key,
              base64Image: entries[index].value,
            );
            if (!uploaded) failedUploads++;
          } catch (_) {
            failedUploads++;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _uploadCurrent = null;
        _uploadTotal = null;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => GatePassDialog(
          nomorTiket: vehicle.nomorTiket ?? 'TKT-KIM3',
          noPolisi: formatPlate(vehicle.noPolisi),
          namaPengemudi: vehicle.namaPengemudi ?? '-',
          tipeKunjungan: vehicle.tipeKunjungan ?? 'Service',
          keluhan: vehicle.keluhan ?? 'Pengecekan armada',
          waktuMasuk: vehicle.waktuCheckIn != null
              ? DateFormat('HH:mm').format(vehicle.waktuCheckIn!)
              : '-',
          waktuKeluar: DateFormat('HH:mm').format(DateTime.now()),
          nomorMemo: nomorMemo,
          invoiceNumber: vehicle.nomorInvoice,
          spkNumber: vehicle.nomorSpk,
          petugasSecurity: petugas,
          uploadWarning: failedUploads == 0
              ? null
              : '$failedUploads dari $totalUploads foto gagal diunggah. '
                    'Data check-out tetap tersimpan, tetapi foto keluar belum lengkap.',
        ),
      );

      if (!mounted) return;
      setState(() {
        _nopolController.clear();
        _notesController.clear();
        _selectedVehicle = null;
        _exitPhotos.clear();
        _hasLookedUp = false;
      });
      widget.onClearInitialPlate?.call();
    } else {
      setState(() {
        _isSubmitting = false;
        _uploadCurrent = null;
        _uploadTotal = null;
      });
      _showSnackBar(res['message'] ?? 'Gagal check-out.');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;
    final vehicle = _selectedVehicle;
    final invoicePaid = (vehicle?.statusInvoice ?? '').toLowerCase() == 'lunas';
    final ready = vehicle?.isSiapKeluar ?? false;
    final photoCount = _exitPhotos.length.clamp(0, 4).toInt();
    final uploadLabel = _uploadCurrent != null && _uploadTotal != null
        ? 'Mengunggah foto $_uploadCurrent/$_uploadTotal'
        : null;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Nomor Polisi',
                      subtitle: 'Cari kendaraan keluar',
                      icon: Icons.exit_to_app_rounded,
                      trailing: vehicle == null
                          ? null
                          : StatusChip(
                              ready
                                  ? AppStatus.readyToExit
                                  : AppStatus.inProgress,
                              label: ready ? 'Siap keluar' : 'Perlu konfirmasi',
                              compact: true,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PlateInput(
                      controller: _nopolController,
                      onSubmitted: _lookupVehicle,
                      onChanged: _handlePlateChanged,
                      onClear: _clearPlate,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Scan Plat',
                            icon: Icons.document_scanner_rounded,
                            onPressed: _openAnprScanner,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: 'Cek Data',
                            icon: Icons.search_rounded,
                            variant: AppButtonVariant.secondary,
                            loading: _isLoading,
                            loadingLabel: 'Mencari kendaraan',
                            onPressed: _isLoading
                                ? null
                                : () => _lookupVehicle(_nopolController.text),
                          ),
                        ),
                      ],
                    ),
                    if (_hasLookedUp && vehicle == null) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        accentColor: scheme.outline,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Kendaraan tidak ditemukan di dalam bengkel. '
                                'Periksa nomor polisi atau scan ulang.',
                                style: texts.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (vehicle != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _VehicleCheckoutCard(
                        vehicle: vehicle,
                        invoicePaid: invoicePaid,
                        ready: ready,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const SectionHeader(
                        title: 'Catatan Keluar',
                        subtitle: 'Opsional',
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: AppTextField(
                          controller: _notesController,
                          label: 'Catatan keluar',
                          hint: 'Kondisi kendaraan saat keluar gerbang',
                          maxLines: 2,
                          minLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SectionHeader(
                        title: 'Foto Keluar',
                        subtitle: 'Empat sudut kendaraan',
                        icon: Icons.photo_camera_outlined,
                        trailing: Text(
                          '$photoCount/4',
                          style: texts.labelLarge?.copyWith(
                            color: photoCount == 4
                                ? semantic.success
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: PhotoQuadPicker(
                          photos: _exitPhotos,
                          enabled: !_isSubmitting,
                          uploadCurrent: _uploadCurrent,
                          uploadTotal: _uploadTotal,
                          onPhotoCaptured: (angle, base64) {
                            setState(() => _exitPhotos[angle] = base64);
                          },
                          onPhotoRemoved: (angle) {
                            setState(() => _exitPhotos.remove(angle));
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
        StickyBottomBar(
          hint: vehicle == null
              ? 'Cari kendaraan terlebih dahulu.'
              : (!ready
                    ? 'Invoice belum lunas. Konfirmasi diperlukan sebelum keluar.'
                    : 'Periksa status invoice dan foto sebelum keluar.'),
          child: AppButton(
            label: 'Konfirmasi Check-Out',
            icon: Icons.exit_to_app_rounded,
            loading: _isSubmitting,
            loadingLabel: uploadLabel ?? 'Memproses check-out',
            onPressed: _isSubmitting || vehicle == null
                ? null
                : _handleCheckOut,
          ),
        ),
      ],
    );
  }
}

class _VehicleCheckoutCard extends StatelessWidget {
  const _VehicleCheckoutCard({
    required this.vehicle,
    required this.invoicePaid,
    required this.ready,
  });

  final ActiveVehicle vehicle;
  final bool invoicePaid;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    return AppCard(
      accentColor: ready ? semantic.success : semantic.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PlateBadge(vehicle.noPolisi, size: PlateBadgeSize.large),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Tiket ${vehicle.nomorTiket ?? '-'}',
                      style: texts.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                invoicePaid ? AppStatus.paid : AppStatus.unpaid,
                label: invoicePaid ? 'Lunas' : 'Belum Lunas',
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusChip(
                ready ? AppStatus.readyToExit : AppStatus.inProgress,
                label: ready ? 'Siap keluar' : 'Perlu konfirmasi',
                compact: true,
              ),
              if (vehicle.statusServis != null &&
                  vehicle.statusServis!.isNotEmpty)
                StatusChip(
                  AppStatus.neutral,
                  label: vehicle.statusServis!,
                  compact: true,
                ),
            ],
          ),
          if (!ready) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: semantic.warningContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: semantic.onWarningContainer,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Invoice belum lunas. Kendaraan tetap dapat keluar '
                      'setelah konfirmasi petugas.',
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
          const SizedBox(height: AppSpacing.sm),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: AppSpacing.xxs),
          InfoRow(
            label: 'Pengemudi',
            value: vehicle.namaPengemudi ?? '-',
            dense: true,
          ),
          InfoRow(
            label: 'Pelanggan',
            value: vehicle.namaPelanggan ?? '-',
            dense: true,
          ),
          InfoRow(
            label: 'Masuk',
            value: vehicle.waktuCheckIn != null
                ? DateFormat('dd MMM, HH:mm').format(vehicle.waktuCheckIn!)
                : '-',
            dense: true,
          ),
          if (vehicle.picTujuan != null && vehicle.picTujuan!.isNotEmpty)
            InfoRow(label: 'PIC', value: vehicle.picTujuan!, dense: true),
          if (vehicle.nomorSpk != null && vehicle.nomorSpk!.isNotEmpty)
            InfoRow(label: 'No. SPK', value: vehicle.nomorSpk!, dense: true),
          if (vehicle.nomorInvoice != null && vehicle.nomorInvoice!.isNotEmpty)
            InfoRow(
              label: 'No. Invoice',
              value: vehicle.nomorInvoice!,
              dense: true,
            ),
          if (vehicle.keluhan != null && vehicle.keluhan!.isNotEmpty)
            InfoRow(label: 'Keluhan', value: vehicle.keluhan!, dense: true),
        ],
      ),
    );
  }
}
