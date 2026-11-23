import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/active_vehicle_model.dart';
import '../models/lokasi_model.dart';
import '../models/set_foto_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../utils/plate_utils.dart';
import '../widgets/anpr_scanner_sheet.dart';
import '../widgets/app_widgets.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/photo_quad_picker.dart';

class CheckOutView extends StatefulWidget {
  final String? initialPlate;
  final VoidCallback? onClearInitialPlate;

  /// Opsional untuk preview/test; produksi memakai ApiService.
  final Future<List<ActiveVehicle>> Function(String query)? vehicleLoader;
  final Future<List<LokasiItem>> Function()? lokasiLoader;
  final Future<List<SetFotoItem>> Function()? setFotoLoader;
  final Future<LocationCheckResult> Function(LokasiItem lokasi)?
  locationValidator;
  final ValueNotifier<Widget?>? dockCtaNotifier;
  final VoidCallback? onGoToBeranda;

  const CheckOutView({
    super.key,
    this.initialPlate,
    this.onClearInitialPlate,
    this.vehicleLoader,
    this.lokasiLoader,
    this.setFotoLoader,
    this.locationValidator,
    this.dockCtaNotifier,
    this.onGoToBeranda,
  });

  @override
  State<CheckOutView> createState() => _CheckOutViewState();
}

class _CheckOutViewState extends State<CheckOutView> {
  final _nopolController = TextEditingController();
  final _notesController = TextEditingController();
  final _reasonController = TextEditingController();

  String? _plateError;
  String? _lokasiError;
  ActiveVehicle? _selectedVehicle;
  List<LokasiItem> _lokasiList = [];
  LokasiItem? _selectedLokasi;
  bool _isLoadingLokasi = true;
  List<SetFotoItem> _fotoSettings = SetFotoItem.defaultSettings;
  bool _isLoading = false;
  bool _hasLookedUp = false;
  bool _isSubmitting = false;
  final Map<String, String> _exitPhotos = {};
  int? _uploadCurrent;
  int? _uploadTotal;

  static const _fallbackLokasi = [
    LokasiItem(id: 1, kodeLokasi: 'MT', namaLokasi: 'Bengkel'),
    LokasiItem(id: 2, kodeLokasi: 'G1', namaLokasi: 'Gudang 1'),
    LokasiItem(id: 3, kodeLokasi: 'G2', namaLokasi: 'Gudang 2'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLokasi();
    _loadSetFoto();
    if (widget.initialPlate != null && widget.initialPlate!.isNotEmpty) {
      _nopolController.text = formatPlate(widget.initialPlate!);
      _lookupVehicle(widget.initialPlate!);
    }
  }

  Future<void> _loadSetFoto() async {
    try {
      final loader = widget.setFotoLoader ?? ApiService.getSetFoto;
      final list = await loader();
      if (!mounted) return;
      if (list.isNotEmpty) {
        setState(() => _fotoSettings = list);
      }
    } catch (_) {}
  }

  Future<void> _loadLokasi() async {
    try {
      final loader = widget.lokasiLoader ?? ApiService.getLokasi;
      final list = await loader();
      if (!mounted) return;
      final items = list.isNotEmpty ? list : _fallbackLokasi;
      setState(() {
        _lokasiList = items;
        _selectedLokasi ??= items.firstWhere(
          (e) => e.isBengkelMt,
          orElse: () => items.first,
        );
        _isLoadingLokasi = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lokasiList = _fallbackLokasi;
        _selectedLokasi ??= _fallbackLokasi.first;
        _isLoadingLokasi = false;
      });
    }
  }

  @override
  void dispose() {
    _nopolController.dispose();
    _notesController.dispose();
    _reasonController.dispose();
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
          });
          _lookupVehicle(formatted);
        },
      ),
    );
  }

  Future<void> _lookupVehicle(String nopol) async {
    final clean = normalizePlate(nopol);
    if (!isValidPlate(clean)) {
      setState(() {
        _plateError = kPlateStandardErrorMessage;
        _selectedVehicle = null;
        _hasLookedUp = false;
      });
      _showSnackBar(kPlateStandardErrorMessage);
      return;
    }

    setState(() {
      _plateError = null;
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

  /// Hanya nomor polisi dan data kendaraan yang direset. Catatan, alasan, dan
  /// foto keluar tetap tersimpan agar isian petugas tidak hilang saat plat
  /// dikoreksi, dibersihkan, atau dipindai ulang.
  void _clearPlate() {
    _nopolController.clear();
    setState(() {
      _plateError = null;
      _lokasiError = null;
      _selectedVehicle = null;
      _hasLookedUp = false;
    });
    widget.onClearInitialPlate?.call();
  }

  void _handlePlateChanged(String _) {
    setState(() {
      _plateError = null;
      _lokasiError = null;
      _selectedVehicle = null;
      _hasLookedUp = false;
    });
  }

  bool get _hasInput =>
      _notesController.text.trim().isNotEmpty ||
      _reasonController.text.trim().isNotEmpty ||
      _exitPhotos.isNotEmpty;

  /// Mengosongkan isian form keluar tanpa menyentuh nomor polisi/kendaraan.
  Future<void> _clearInputs() async {
    if (_exitPhotos.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text('Kosongkan isian?'),
          content: const Text(
            'Catatan, alasan, dan foto keluar akan dihapus. Nomor polisi dan data kendaraan tetap.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Kosongkan'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() {
      _notesController.clear();
      _reasonController.clear();
      _exitPhotos.clear();
    });
  }

  Future<bool?> _showCrossGateDialog(String gateMasuk, String gateKeluar) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: semantic.warningContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.swap_horiz_rounded,
                color: semantic.onWarningContainer,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Konfirmasi Perbedaan Gerbang')),
          ],
        ),
        content: Text(
          'Kendaraan ini tercatat masuk melalui $gateMasuk, namun saat ini akan melakukan keluar melalui $gateKeluar.\n\nApakah Anda mengizinkan kendaraan ini keluar melalui gerbang tersebut?',
          style: texts.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batalkan'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Ya, Izinkan Keluar'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showExitReasonDialog({
    required bool willKeluarSementara,
  }) async {
    final controller = TextEditingController(text: _reasonController.text);
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final scheme = Theme.of(ctx).colorScheme;
            final semantic = ctx.semantic;
            final texts = Theme.of(ctx).textTheme;
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: willKeluarSementara
                          ? semantic.warningContainer
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: willKeluarSementara
                          ? semantic.onWarningContainer
                          : scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      willKeluarSementara
                          ? 'Alasan Keluar Sementara'
                          : 'Alasan Keluar',
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    willKeluarSementara
                        ? 'Unit memiliki SPK aktif namun FIR belum terbit. Tuliskan alasan keluar sementara.'
                        : 'Unit belum memiliki SPK & FIR. Tuliskan alasan kendaraan keluar.',
                    style: texts.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: controller,
                    label: 'Alasan keluar',
                    hint:
                        'Contoh: test drive, ambil dokumen, selesai kunjungan',
                    required: true,
                    autofocus: true,
                    maxLines: 2,
                    minLines: 2,
                    errorText: errorText,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batalkan'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setDialogState(
                        () => errorText = 'Alasan keluar wajib diisi.',
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(text);
                  },
                  child: Text(
                    willKeluarSementara
                        ? 'Catat Keluar Sementara'
                        : 'Lanjutkan Check-Out',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _handleCheckOut() async {
    final rawPlate = _nopolController.text.trim();
    final cleanPlate = normalizePlate(rawPlate);

    if (!isValidPlate(cleanPlate)) {
      setState(() => _plateError = kPlateStandardErrorMessage);
      _showSnackBar(kPlateStandardErrorMessage);
      return;
    }

    final vehicle = _selectedVehicle;
    if (vehicle == null) {
      _showSnackBar('Pilih atau cari kendaraan terlebih dahulu.');
      return;
    }

    if (_selectedLokasi == null) {
      setState(() => _lokasiError = 'Pilih lokasi check-out terlebih dahulu.');
      _showSnackBar('Pilih lokasi check-out terlebih dahulu.');
      return;
    }

    final effLokasiKode = _selectedLokasi!.kodeLokasi;
    final willKeluarSementara = vehicle.willBeKeluarSementaraFor(effLokasiKode);
    final requiresReason = vehicle.requiresExitReasonFor(effLokasiKode);

    if (!PhotoQuadPicker.hasRequiredPhotosFor(_exitPhotos, _fotoSettings)) {
      final requiredLabels = _fotoSettings
          .where((s) => s.isWajib)
          .map((s) => s.namaFoto)
          .join(', ');
      _showSnackBar(
        'Foto wajib ($requiredLabels) harus diambil terlebih dahulu.',
      );
      return;
    }

    final session = AuthService.currentSession;
    final gateMasuk = vehicle.gateMasukNama?.trim();
    final gateKeluar = session?.gateName?.trim();
    if (gateMasuk != null &&
        gateMasuk.isNotEmpty &&
        gateKeluar != null &&
        gateKeluar.isNotEmpty &&
        gateMasuk.toLowerCase() != gateKeluar.toLowerCase()) {
      final confirmed = await _showCrossGateDialog(gateMasuk, gateKeluar);
      if (confirmed != true) return;
    }

    var reason = '';
    if (requiresReason) {
      final inputReason = await _showExitReasonDialog(
        willKeluarSementara: willKeluarSementara,
      );
      if (!mounted || inputReason == null) return;
      reason = inputReason;
      _reasonController.text = inputReason;
    }

    setState(() {
      _isSubmitting = true;
      _uploadCurrent = null;
      _uploadTotal = null;
      _lokasiError = null;
    });

    if (_selectedLokasi!.cekLokasi) {
      final validator =
          widget.locationValidator ?? LocationService.validateLokasiPosition;
      final locCheck = await validator(_selectedLokasi!);
      if (!mounted) return;
      if (!locCheck.allowed) {
        setState(() {
          _isSubmitting = false;
          _lokasiError = locCheck.message;
        });
        _showSnackBar(locCheck.message ?? 'Posisi di luar area lokasi.');
        return;
      }
    }

    final petugas = session?.name ?? 'Pos Security DarkoGate';
    final res = await ApiService.postCheckOut(
      kunjunganId: vehicle.id,
      petugasSecurityKeluar: petugas,
      catatanKeluar: _notesController.text.trim(),
      alasanKeluar: reason,
      gateKeluarId: session?.gateId,
      gateKeluarName: session?.gateName,
      lokasiKode: effLokasiKode,
    );

    if (!mounted) return;

    if (res['success'] == true) {
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

      final isTempExit =
          (res['status_kunjungan']?.toString().toUpperCase() ?? '') ==
              'KELUAR_SEMENTARA' ||
          vehicle.willBeKeluarSementaraFor(_selectedLokasi?.kodeLokasi);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CompletionDialog(
          title: isTempExit ? 'Keluar Sementara Selesai' : 'Check-Out Selesai',
          noPolisi: formatPlate(vehicle.noPolisi),
          namaPengemudi: vehicle.namaPengemudi ?? '-',
          isTempExit: isTempExit,
          uploadWarning: failedUploads == 0
              ? null
              : '$failedUploads dari $totalUploads foto gagal diunggah. '
                    'Data check-out tetap tersimpan, tetapi foto keluar belum lengkap.',
          onGoToBeranda: widget.onGoToBeranda,
        ),
      );

      if (!mounted) return;
      setState(() {
        _nopolController.clear();
        _notesController.clear();
        _reasonController.clear();
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
    final texts = Theme.of(context).textTheme;
    final vehicle = _selectedVehicle;
    final effLokasiKode = _selectedLokasi?.kodeLokasi ?? vehicle?.lokasiKode;
    final willKeluarSementara =
        vehicle?.willBeKeluarSementaraFor(effLokasiKode) ?? false;
    final requiredPhotoCount = PhotoQuadPicker.requiredUploadedCountFor(
      _exitPhotos,
      _fotoSettings,
    );
    final totalRequiredPhotos = PhotoQuadPicker.requiredTotalCountFor(
      _fotoSettings,
    );
    final uploadLabel = _uploadCurrent != null && _uploadTotal != null
        ? 'Mengunggah foto $_uploadCurrent/$_uploadTotal'
        : null;

    final ctaButton = AppButton(
      label: willKeluarSementara
          ? 'Catat Keluar Sementara'
          : 'Konfirmasi Check-Out',
      icon: Icons.exit_to_app_rounded,
      loading: _isSubmitting,
      loadingLabel: uploadLabel ?? 'Memproses check-out',
      onPressed: _isSubmitting || vehicle == null ? null : _handleCheckOut,
    );

    if (widget.dockCtaNotifier != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.dockCtaNotifier!.value = ctaButton;
      });
    }

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
                    SectionCard(
                      stepNumber: 1,
                      title: 'Nomor polisi',
                      subtitle: 'Cari kendaraan yang akan keluar',
                      trailing: vehicle == null
                          ? null
                          : StatusChip(
                              willKeluarSementara
                                  ? AppStatus.inProgress
                                  : AppStatus.readyToExit,
                              label: willKeluarSementara
                                  ? 'Keluar sementara'
                                  : 'Siap keluar',
                              compact: true,
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PlateViewfinder(
                            plate: _nopolController.text,
                            onTap: _openAnprScanner,
                            helperText: 'Ketuk untuk memindai plat nomor',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          PlateInput(
                            controller: _nopolController,
                            onSubmitted: _lookupVehicle,
                            onChanged: _handlePlateChanged,
                            onClear: _clearPlate,
                          ),
                          if (_plateError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _plateError!,
                              style: texts.bodySmall?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'Scan Plat',
                                  icon: Icons.document_scanner_rounded,
                                  size: AppButtonSize.medium,
                                  onPressed: _openAnprScanner,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppButton(
                                  label: 'Cari Unit',
                                  icon: Icons.search_rounded,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.medium,
                                  loading: _isLoading,
                                  loadingLabel: 'Mencari kendaraan',
                                  onPressed: _isLoading
                                      ? null
                                      : () => _lookupVehicle(
                                          _nopolController.text,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          LokasiSelectorBlock(
                            lokasiList: _lokasiList,
                            selectedLokasi: _selectedLokasi,
                            isLoading: _isLoadingLokasi,
                            errorText: _lokasiError,
                            onSelected: (loc) {
                              setState(() {
                                _selectedLokasi = loc;
                                _lokasiError = null;
                              });
                            },
                          ),
                          if (_hasLookedUp && vehicle == null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      'Kendaraan tidak ditemukan di dalam bengkel. '
                                      'Periksa nomor polisi atau scan ulang.',
                                      style: texts.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      stepNumber: 2,
                      title: 'Data kendaraan',
                      subtitle: 'Gate masuk, lokasi, dan status SPK/FIR (MT)',
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _isLoading
                            ? const _VehicleDataSkeleton(
                                key: ValueKey('vehicle-loading'),
                              )
                            : vehicle == null
                            ? const _VehicleDataPlaceholder(
                                key: ValueKey('vehicle-empty'),
                              )
                            : _VehicleCheckoutCard(
                                key: ValueKey('vehicle-${vehicle.id}'),
                                vehicle: vehicle,
                                lokasiKode: effLokasiKode ?? 'MT',
                                willKeluarSementara: willKeluarSementara,
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      stepNumber: 3,
                      title: 'Catatan & Foto keluar',
                      subtitle: totalRequiredPhotos > 0
                          ? 'Foto bertanda * wajib diisi'
                          : 'Dokumentasi kondisi kendaraan',
                      trailing: StatusChip(
                        requiredPhotoCount >= totalRequiredPhotos
                            ? AppStatus.readyToExit
                            : AppStatus.info,
                        label: totalRequiredPhotos > 0
                            ? '$requiredPhotoCount/$totalRequiredPhotos wajib'
                            : '${_exitPhotos.length} foto',
                        compact: true,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _notesController,
                            label: 'Catatan keluar',
                            hint: 'Kondisi kendaraan saat keluar gerbang (opsional)',
                            maxLines: 2,
                            minLines: 2,
                            enabled: !_isSubmitting,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PhotoQuadPicker(
                            photos: _exitPhotos,
                            fotoSettings: _fotoSettings,
                            showExtraButton: true,
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
                          if (_hasInput) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _isSubmitting ? null : _clearInputs,
                                icon: const Icon(
                                  Icons.cleaning_services_outlined,
                                  size: 16,
                                ),
                                label: const Text('Kosongkan isian'),
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onSurfaceVariant,
                                  textStyle: texts.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.dockCtaNotifier == null)
          StickyBottomBar(
            hint: vehicle == null
                ? 'Cari kendaraan terlebih dahulu.'
                : (willKeluarSementara
                      ? 'FIR belum terbit. Unit akan dicatat Keluar Sementara.'
                      : 'Periksa data gate & foto sebelum keluar.'),
            child: ctaButton,
          ),
      ],
    );
  }
}

class _VehicleCheckoutCard extends StatelessWidget {
  const _VehicleCheckoutCard({
    super.key,
    required this.vehicle,
    required this.lokasiKode,
    required this.willKeluarSementara,
  });

  final ActiveVehicle vehicle;
  final String lokasiKode;
  final bool willKeluarSementara;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;
    final gateMasuk = vehicle.gateMasukNama ?? 'Gerbang Masuk';
    final gateKeluar = AuthService.currentSession?.gateName ?? 'Gerbang Aktif';
    final checkInStr = vehicle.waktuCheckIn != null
        ? DateFormat('HH:mm').format(vehicle.waktuCheckIn!)
        : '-';
    final durasiHours = vehicle.waktuCheckIn == null
        ? '-'
        : '${DateTime.now().difference(vehicle.waktuCheckIn!).inHours}j '
              '${DateTime.now().difference(vehicle.waktuCheckIn!).inMinutes % 60}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PlateBadge(vehicle.noPolisi, size: PlateBadgeSize.large),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Tiket ${vehicle.nomorTiket ?? '-'}',
                    style: texts.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusChip(
              willKeluarSementara
                  ? AppStatus.inProgress
                  : AppStatus.readyToExit,
              label: willKeluarSementara
                  ? 'Keluar Sementara'
                  : (lokasiKode.toUpperCase() == 'MT' && vehicle.hasFir
                        ? 'FIR Siap'
                        : 'Siap Keluar'),
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Rute Gate Masuk -> Gate Keluar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Masuk ($checkInStr)', style: texts.labelSmall),
                  Text(
                    gateMasuk,
                    style: texts.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1.5,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: scheme.outline,
                      ),
                    ),
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    Expanded(
                      child: Container(
                        height: 1.5,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: scheme.outline,
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: semantic.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Keluar', style: texts.labelSmall),
                  Text(
                    gateKeluar,
                    style: texts.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // 3 mini-stat (Durasi, Lokasi, FIR / Pengecekan)
        Row(
          children: [
            Expanded(
              child: _MiniStatBox(label: 'Durasi', value: durasiHours),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _MiniStatBox(
                label: 'Lokasi',
                value: lokasiKode.toUpperCase(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _MiniStatBox(
                label: lokasiKode.toUpperCase() == 'MT' ? 'FIR' : 'Validasi',
                value: lokasiKode.toUpperCase() != 'MT'
                    ? 'Non-MT'
                    : (vehicle.hasWo
                          ? (vehicle.hasFir ? 'Sudah Ada' : 'Belum Ada')
                          : 'Non-WO'),
                highlightColor:
                    lokasiKode.toUpperCase() == 'MT' &&
                        vehicle.hasWo &&
                        !vehicle.hasFir
                    ? semantic.onWarningContainer
                    : (lokasiKode.toUpperCase() == 'MT' && vehicle.hasFir
                          ? semantic.success
                          : null),
              ),
            ),
          ],
        ),
        if (willKeluarSementara) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: semantic.warningContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: semantic.onWarningContainer,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'WO belum memiliki FIR. Check-Out akan dicatat sebagai KELUAR SEMENTARA (wajib mengisi alasan keluar).',
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
        if (vehicle.picTujuan != null && vehicle.picTujuan!.isNotEmpty)
          InfoRow(label: 'PIC', value: vehicle.picTujuan!, dense: true),
        if (vehicle.nomorSpk != null && vehicle.nomorSpk!.isNotEmpty)
          InfoRow(label: 'No. SPK', value: vehicle.nomorSpk!, dense: true),
        if (vehicle.namaPelanggan != null && vehicle.namaPelanggan!.isNotEmpty)
          InfoRow(
            label: 'Pelanggan',
            value: vehicle.namaPelanggan!,
            dense: true,
          ),
        if (vehicle.keluhan != null && vehicle.keluhan!.isNotEmpty)
          InfoRow(label: 'Keluhan', value: vehicle.keluhan!, dense: true),
      ],
    );
  }
}

/// Placeholder data kendaraan sebelum nomor polisi dicari.
class _VehicleDataPlaceholder extends StatelessWidget {
  const _VehicleDataPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              size: 28,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Data kendaraan belum dimuat',
            textAlign: TextAlign.center,
            style: texts.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Cari atau scan plat untuk menampilkan data gate, FIR, dan invoice.',
            textAlign: TextAlign.center,
            style: texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Skeleton sederhana (bar abu-biru berdenyut) saat data kendaraan dicari.
class _VehicleDataSkeleton extends StatefulWidget {
  const _VehicleDataSkeleton({super.key});

  @override
  State<_VehicleDataSkeleton> createState() => _VehicleDataSkeletonState();
}

class _VehicleDataSkeletonState extends State<_VehicleDataSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pulseTone = Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.22),
      scheme.surfaceContainer,
    );

    return Semantics(
      label: 'Memuat data kendaraan',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final tone = Color.lerp(
              scheme.surfaceContainer,
              pulseTone,
              _controller.value,
            )!;

            Widget bar(double? width, double height, {double radius = 8}) {
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(radius),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    bar(96, 32),
                    const Spacer(),
                    bar(84, 26, radius: AppRadius.pill),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                bar(double.infinity, 52),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(child: bar(double.infinity, 44)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: bar(double.infinity, 44)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: bar(double.infinity, 44)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                bar(double.infinity, 12),
                const SizedBox(height: AppSpacing.xs),
                bar(168, 12),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.value,
    this.highlightColor,
  });

  final String label;
  final String value;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: texts.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: texts.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: highlightColor ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
