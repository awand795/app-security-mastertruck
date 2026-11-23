import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/booking_candidate_model.dart';
import '../models/employee_model.dart';
import '../models/lokasi_model.dart';
import '../models/set_foto_model.dart';
import '../models/tujuan_kedatangan_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../utils/plate_utils.dart';
import '../widgets/anpr_scanner_sheet.dart';
import '../widgets/app_widgets.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/photo_quad_picker.dart';

class CheckInView extends StatefulWidget {
  const CheckInView({
    super.key,
    this.employeeLoader,
    this.candidateSearcher,
    this.lokasiLoader,
    this.tujuanLoader,
    this.setFotoLoader,
    this.locationValidator,
    this.dockCtaNotifier,
    this.onGoToBeranda,
  });

  /// Opsional untuk preview/test; produksi memakai ApiService.
  final Future<List<EmployeeItem>> Function()? employeeLoader;
  final Future<List<CheckinCandidate>> Function(String query)?
  candidateSearcher;
  final Future<List<LokasiItem>> Function()? lokasiLoader;
  final Future<List<TujuanKedatanganItem>> Function()? tujuanLoader;
  final Future<List<SetFotoItem>> Function()? setFotoLoader;
  final Future<LocationCheckResult> Function(LokasiItem lokasi)?
  locationValidator;
  final ValueNotifier<Widget?>? dockCtaNotifier;
  final VoidCallback? onGoToBeranda;

  @override
  State<CheckInView> createState() => _CheckInViewState();
}

class _CheckInViewState extends State<CheckInView> {
  final _nopolController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _complaintController = TextEditingController();
  final _notesController = TextEditingController();
  final _customTipeController = TextEditingController();
  final _picController = TextEditingController();

  String _jenisKedatangan = 'WALK_IN';
  int? _bookingId;
  String? _selectedPic;
  EmployeeItem? _selectedEmployee;
  List<EmployeeItem> _employeeList = [];
  bool _isLoadingEmployees = true;

  List<LokasiItem> _lokasiList = [];
  LokasiItem? _selectedLokasi;
  bool _isLoadingLokasi = true;

  List<TujuanKedatanganItem> _tujuanList = [];
  TujuanKedatanganItem? _selectedTujuan;
  bool _isLoadingTujuan = true;

  List<SetFotoItem> _fotoSettings = SetFotoItem.defaultSettings;

  CheckinCandidate? _selectedCandidate;
  List<CheckinCandidate> _candidates = [];
  bool _isSearchingPlate = false;
  bool _hasSearchedPlate = false;

  final Map<String, String> _photos = {};
  bool _isSubmitting = false;
  int? _uploadCurrent;
  int? _uploadTotal;

  String? _plateError;
  String? _lokasiError;
  String? _tujuanError;
  String? _driverError;
  String? _phoneError;
  String? _picError;

  static const _fallbackLokasi = [
    LokasiItem(id: 1, kodeLokasi: 'MT', namaLokasi: 'Bengkel'),
    LokasiItem(id: 2, kodeLokasi: 'G1', namaLokasi: 'Gudang 1'),
    LokasiItem(id: 3, kodeLokasi: 'G2', namaLokasi: 'Gudang 2'),
  ];

  static const _fallbackTujuan = [
    TujuanKedatanganItem(
      id: 1,
      kodeTujuan: 'SERVICE',
      namaTujuan: 'Service',
      urutan: 1,
    ),
    TujuanKedatanganItem(
      id: 2,
      kodeTujuan: 'KUNJUNGAN',
      namaTujuan: 'Kunjungan',
      urutan: 2,
    ),
    TujuanKedatanganItem(
      id: 3,
      kodeTujuan: 'BELI_SPAREPART',
      namaTujuan: 'Beli Sparepart',
      urutan: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadLokasi();
    _loadTujuanKedatangan();
    _loadSetFoto();
  }

  @override
  void dispose() {
    _nopolController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _complaintController.dispose();
    _notesController.dispose();
    _customTipeController.dispose();
    _picController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final loader = widget.employeeLoader ?? ApiService.getEmployees;
      final list = await loader();
      if (!mounted) return;
      setState(() {
        _employeeList = list;
        _isLoadingEmployees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingEmployees = false);
    }
  }

  Future<void> _loadLokasi() async {
    try {
      final loader = widget.lokasiLoader ?? ApiService.getLokasi;
      final list = await loader();
      if (!mounted) return;
      final items = list.isNotEmpty ? list : _fallbackLokasi;
      setState(() {
        _lokasiList = items;
        _selectedLokasi = items.firstWhere(
          (e) => e.isBengkelMt,
          orElse: () => items.first,
        );
        _isLoadingLokasi = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lokasiList = _fallbackLokasi;
        _selectedLokasi = _fallbackLokasi.first;
        _isLoadingLokasi = false;
      });
    }
  }

  Future<void> _loadTujuanKedatangan() async {
    try {
      final loader = widget.tujuanLoader ?? ApiService.getTujuanKedatangan;
      final list = await loader();
      if (!mounted) return;
      final items = list.isNotEmpty ? list : _fallbackTujuan;
      setState(() {
        _tujuanList = items;
        if (_selectedTujuan == null && items.isNotEmpty) {
          _selectedTujuan = items.first;
        }
        _isLoadingTujuan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tujuanList = _fallbackTujuan;
        _selectedTujuan ??= _fallbackTujuan.first;
        _isLoadingTujuan = false;
      });
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

  void _openAnprScanner() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => AnprScannerSheet(
        onPlateDetected: (detectedPlate) {
          if (!mounted) return;
          final formatted = formatPlate(detectedPlate);
          setState(() {
            _nopolController.text = formatted;
            _plateError = null;
          });
          _executePlateSearch(formatted);
        },
      ),
    );
  }

  Future<void> _executePlateSearch([String? targetPlate]) async {
    final query = targetPlate ?? _nopolController.text;
    final clean = normalizePlate(query);

    if (!isValidPlate(clean)) {
      setState(() => _plateError = kPlateStandardErrorMessage);
      _showSnackBar(kPlateStandardErrorMessage);
      return;
    }

    setState(() {
      _plateError = null;
      _isSearchingPlate = true;
      _hasSearchedPlate = false;
      _candidates = [];
    });

    try {
      final searcher = widget.candidateSearcher ?? ApiService.searchCandidates;
      final results = await searcher(clean);
      if (!mounted) return;

      setState(() {
        _isSearchingPlate = false;
        _hasSearchedPlate = true;
        _candidates = results;
      });

      final exactMatches = results
          .where((item) => item.noPolisiClean == clean)
          .toList();

      if (exactMatches.length == 1) {
        await _applyCandidate(exactMatches.first, forceFill: true);
      } else if (results.isNotEmpty) {
        await _showCandidatesSelectionSheet(results);
      } else {
        setState(() {
          _selectedCandidate = null;
          _jenisKedatangan = 'WALK_IN';
          _bookingId = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearchingPlate = false;
        _plateError = 'Data belum dapat diperiksa. Coba lagi.';
      });
      _showSnackBar('Gagal memeriksa data plat. Coba lagi.');
    }
  }

  Future<void> _applyCandidate(
    CheckinCandidate candidate, {
    bool forceFill = false,
  }) async {
    if (!mounted) return;

    setState(() {
      _selectedCandidate = candidate;
      _nopolController.text = formatPlate(candidate.noPolisi);
      _bookingId = candidate.bookingId;
      _jenisKedatangan = candidate.source == 'BOOKING'
          ? 'BOOKING'
          : 'WALK_IN_MEMBER';
      _plateError = null;
      _driverError = null;
      _phoneError = null;
      _picError = null;

      // Nama & nomor telepon pengemudi tidak diisi otomatis dari API
      // karena data API berisi nama PT/perusahaan, bukan pengemudi aktual.
      final complaint = candidate.effectiveComplaint;
      if (forceFill || _complaintController.text.trim().isEmpty) {
        if (complaint.isNotEmpty) _complaintController.text = complaint;
      }

      if (candidate.source == 'BOOKING') {
        final serviceItem = _tujuanList
            .cast<TujuanKedatanganItem?>()
            .firstWhere(
              (t) => t?.kodeTujuan == 'SERVICE',
              orElse: () => _tujuanList.isNotEmpty ? _tujuanList.first : null,
            );
        _selectedTujuan = serviceItem;
        _customTipeController.clear();
        _tujuanError = null;
      }
    });

    if (candidate.source == 'BOOKING' && !candidate.isConfirmed) {
      await _showUnconfirmedBookingWarning(candidate);
    }
  }

  Future<void> _showUnconfirmedBookingWarning(
    CheckinCandidate candidate,
  ) async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    await showModalBottomSheet<void>(
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
                        'Booking belum dikonfirmasi',
                        style: texts.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Booking ${formatPlate(candidate.noPolisi)} untuk '
                  '${candidate.customerName ?? 'pelanggan'} belum dikonfirmasi '
                  'admin. Koordinasikan sebelum layanan lanjutan.',
                  style: texts.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Mengerti',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCandidatesSelectionSheet(
    List<CheckinCandidate> list,
  ) async {
    final selected = await showModalBottomSheet<CheckinCandidate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CandidatePickerSheet(candidates: list),
    );

    if (selected != null && mounted) {
      await _applyCandidate(selected, forceFill: true);
    }
  }

  Future<void> _openPicPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showModalBottomSheet<EmployeeItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PicPickerSheet(
        employees: _employeeList,
        isLoading: _isLoadingEmployees,
        selected: _selectedPic,
        onRetry: () {
          _loadEmployees();
        },
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedEmployee = selected;
        _selectedPic = selected.name;
        _picController.text = '${selected.name} (${selected.position})';
        _picError = null;
      });
    }
  }

  void _handlePlateCleared() {
    setState(() {
      _selectedCandidate = null;
      _hasSearchedPlate = false;
      _candidates.clear();
      _jenisKedatangan = 'WALK_IN';
      _bookingId = null;
      _plateError = null;
    });
  }

  void _handlePlateChanged(String _) {
    if (!_hasSearchedPlate &&
        _selectedCandidate == null &&
        _plateError == null) {
      return;
    }
    setState(() {
      _selectedCandidate = null;
      _hasSearchedPlate = false;
      _candidates.clear();
      _jenisKedatangan = 'WALK_IN';
      _bookingId = null;
      _plateError = null;
    });
  }

  Future<void> _handleSubmitCheckIn() async {
    final rawPlate = _nopolController.text.trim();
    final cleanPlate = normalizePlate(rawPlate);
    final driver = _driverNameController.text.trim();
    final phone = _driverPhoneController.text.trim();
    final complaint = _complaintController.text.trim();
    final notes = _notesController.text.trim();
    final customTujuan = _customTipeController.text.trim();
    final hasCustomTujuan = customTujuan.isNotEmpty;

    final plateError = !isValidPlate(cleanPlate)
        ? kPlateStandardErrorMessage
        : null;
    final lokasiError = _selectedLokasi == null
        ? 'Pilih lokasi check-in terlebih dahulu.'
        : null;
    final tujuanError = !hasCustomTujuan && _selectedTujuan == null
        ? 'Pilih tujuan kedatangan atau isi tujuan lainnya.'
        : null;
    final driverError = driver.isEmpty ? 'Nama pengemudi wajib diisi.' : null;
    final phoneError = phone.isEmpty ? 'Nomor telepon wajib diisi.' : null;
    final manualPic = _picController.text.trim();
    final effectivePic = hasCustomTujuan
        ? manualPic
        : (_selectedEmployee?.name ?? _selectedPic ?? '');
    final picError = effectivePic.isEmpty
        ? (hasCustomTujuan
              ? 'Nama PIC tujuan wajib diisi.'
              : 'Pilih PIC tujuan.')
        : null;

    if (plateError != null ||
        lokasiError != null ||
        tujuanError != null ||
        driverError != null ||
        phoneError != null ||
        picError != null) {
      setState(() {
        _plateError = plateError;
        _lokasiError = lokasiError;
        _tujuanError = tujuanError;
        _driverError = driverError;
        _phoneError = phoneError;
        _picError = picError;
      });
      _showSnackBar(
        plateError ??
            lokasiError ??
            tujuanError ??
            phoneError ??
            picError ??
            'Lengkapi data bertanda * terlebih dahulu.',
      );
      return;
    }

    if (!PhotoQuadPicker.hasRequiredPhotosFor(_photos, _fotoSettings)) {
      final requiredLabels = _fotoSettings
          .where((s) => s.isWajib)
          .map((s) => s.namaFoto)
          .join(', ');
      _showSnackBar(
        'Foto wajib ($requiredLabels) harus diambil terlebih dahulu.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadCurrent = null;
      _uploadTotal = null;
    });

    final selectedLokasi = _selectedLokasi!;
    if (selectedLokasi.cekLokasi) {
      final validator =
          widget.locationValidator ?? LocationService.validateLokasiPosition;
      final locCheck = await validator(selectedLokasi);
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

    final effectiveTipe = hasCustomTujuan
        ? 'LAINNYA'
        : _selectedTujuan!.kodeTujuan;
    final effectiveSubTujuan = hasCustomTujuan
        ? customTujuan
        : _selectedTujuan!.kodeTujuan;

    final session = AuthService.currentSession;
    final petugas = session?.name ?? 'Security DarkoGate';
    final res = await ApiService.postCheckIn(
      noPolisi: cleanPlate,
      namaPengemudi: driver,
      noTeleponPengemudi: phone,
      tipeKunjungan: effectiveTipe,
      subTujuan: effectiveSubTujuan,
      keluhan: complaint.isEmpty ? 'Pengecekan umum armada' : complaint,
      petugasSecurity: petugas,
      bookingId: _bookingId,
      picTujuan: effectivePic,
      jenisKedatangan: _jenisKedatangan,
      catatanMasuk: notes,
      gateMasukId: session?.gateId,
      gateMasukName: session?.gateName,
      lokasiKode: selectedLokasi.kodeLokasi,
      lokasiNama: selectedLokasi.namaLokasi,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final kunjunganId = res['kunjungan_id'];
      var failedUploads = 0;
      var totalUploads = 0;

      if (_photos.isNotEmpty) {
        totalUploads = _photos.length;
        if (kunjunganId == null) {
          failedUploads = _photos.length;
        } else {
          final entries = _photos.entries.toList();
          setState(() {
            _uploadTotal = entries.length;
            _uploadCurrent = 0;
          });

          for (var index = 0; index < entries.length; index++) {
            if (!mounted) return;
            setState(() => _uploadCurrent = index + 1);
            try {
              final uploaded = await ApiService.postAddFoto(
                kunjunganId: kunjunganId is int
                    ? kunjunganId
                    : int.tryParse(kunjunganId.toString()) ?? 0,
                jenisEvent: 'MASUK',
                sudutPandang: entries[index].key,
                base64Image: entries[index].value,
              );
              if (!uploaded) failedUploads++;
            } catch (_) {
              failedUploads++;
            }
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
        builder: (_) => CompletionDialog(
          title: 'Check-In Selesai',
          noPolisi: formatPlate(cleanPlate),
          namaPengemudi: driver,
          uploadWarning: failedUploads == 0
              ? null
              : '$failedUploads dari $totalUploads foto gagal diunggah. '
                    'Data check-in tetap tersimpan, tetapi foto masuk belum lengkap.',
          onDone: _resetForm,
          onGoToBeranda: widget.onGoToBeranda,
        ),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _uploadCurrent = null;
        _uploadTotal = null;
      });
      _showSnackBar(res['message'] ?? 'Gagal menyimpan check-in.');
    }
  }

  void _resetForm() {
    if (!mounted) return;
    setState(() {
      _nopolController.clear();
      _driverNameController.clear();
      _driverPhoneController.clear();
      _complaintController.clear();
      _notesController.clear();
      _customTipeController.clear();
      _picController.clear();
      _jenisKedatangan = 'WALK_IN';
      _bookingId = null;
      _selectedCandidate = null;
      _selectedPic = null;
      _selectedEmployee = null;
      _selectedTujuan = _tujuanList.isNotEmpty ? _tujuanList.first : null;
      _hasSearchedPlate = false;
      _candidates.clear();
      _photos.clear();
      _isSubmitting = false;
      _uploadCurrent = null;
      _uploadTotal = null;
      _plateError = null;
      _lokasiError = null;
      _tujuanError = null;
      _driverError = null;
      _phoneError = null;
      _picError = null;
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  AppStatus _statusFor(CheckinCandidate? candidate) {
    if (candidate == null) return AppStatus.walkIn;
    return candidate.source == 'BOOKING' ? AppStatus.booking : AppStatus.member;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final uploadLabel = _uploadCurrent != null && _uploadTotal != null
        ? 'Mengunggah foto $_uploadCurrent/$_uploadTotal'
        : null;
    final hasCustomTujuan = _customTipeController.text.trim().isNotEmpty;
    final requiredCount = PhotoQuadPicker.requiredUploadedCountFor(
      _photos,
      _fotoSettings,
    );
    final totalRequired = PhotoQuadPicker.requiredTotalCountFor(_fotoSettings);

    final ctaButton = AppButton(
      label: 'Konfirmasi Check-In',
      icon: Icons.check_circle_outline_rounded,
      loading: _isSubmitting,
      loadingLabel: uploadLabel ?? 'Memproses check-in',
      onPressed: _isSubmitting ? null : _handleSubmitCheckIn,
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
                      subtitle: 'Scan kamera atau ketik manual',
                      trailing: _hasSearchedPlate || _selectedCandidate != null
                          ? StatusChip(
                              _statusFor(_selectedCandidate),
                              compact: true,
                            )
                          : null,
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
                            onSubmitted: _executePlateSearch,
                            onChanged: _handlePlateChanged,
                            onClear: _handlePlateCleared,
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
                                  label: _nopolController.text.trim().isEmpty
                                      ? 'Scan Plat'
                                      : 'Scan Ulang',
                                  icon: Icons.document_scanner_rounded,
                                  size: AppButtonSize.medium,
                                  onPressed: _openAnprScanner,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: AppButton(
                                  label: 'Cek Data',
                                  icon: Icons.search_rounded,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.medium,
                                  loading: _isSearchingPlate,
                                  loadingLabel: 'Memeriksa data',
                                  onPressed: _isSearchingPlate
                                      ? null
                                      : () => _executePlateSearch(),
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
                          if (_hasSearchedPlate) ...[
                            const SizedBox(height: AppSpacing.md),
                            _CandidateResultCard(
                              candidate: _selectedCandidate,
                              searchedPlate: _nopolController.text,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      stepNumber: 2,
                      title: 'Tujuan kunjungan',
                      subtitle: 'Pilih tujuan di atas, atau isi Tujuan lainnya di bawah',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isLoadingTujuan && _tujuanList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: _tujuanList.map((item) {
                                final selected =
                                    !hasCustomTujuan &&
                                    _selectedTujuan?.kodeTujuan ==
                                        item.kodeTujuan;
                                return _TujuanOptionPill(
                                  item: item,
                                  selected: selected,
                                  onTap: () {
                                    setState(() {
                                      _selectedTujuan = item;
                                      _customTipeController.clear();
                                      _tujuanError = null;
                                      _picError = null;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          Divider(
                            height: 1,
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _customTipeController,
                            label: 'Tujuan lainnya (Opsional)',
                            hint: 'Isi jika tujuan tidak ada di daftar atas (otomatis dipakai)',
                            prefixIcon: Icons.edit_outlined,
                            textCapitalization: TextCapitalization.sentences,
                            errorText: _tujuanError,
                            onChanged: (_) {
                              setState(() {
                                _tujuanError = null;
                                _picError = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      stepNumber: 3,
                      title: 'Data pengemudi',
                      subtitle: 'Identitas pengemudi, PIC, dan keperluan',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _driverNameController,
                            label: 'Nama pengemudi',
                            hint: 'Nama sesuai identitas',
                            required: true,
                            prefixIcon: Icons.person_outline_rounded,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            errorText: _driverError,
                            onChanged: (_) {
                              if (_driverError != null) {
                                setState(() => _driverError = null);
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _driverPhoneController,
                            label: 'Nomor telepon',
                            hint: 'Contoh: 0812 3456 7890',
                            required: true,
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            errorText: _phoneError,
                            onChanged: (_) {
                              if (_phoneError != null) {
                                setState(() => _phoneError = null);
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (hasCustomTujuan)
                            AppTextField(
                              controller: _picController,
                              label: 'PIC / Orang yang Dituju',
                              hint: 'Ketik nama PIC secara manual',
                              required: true,
                              prefixIcon: Icons.person_outline_rounded,
                              textCapitalization: TextCapitalization.words,
                              errorText: _picError,
                              onChanged: (_) {
                                if (_picError != null) {
                                  setState(() => _picError = null);
                                }
                              },
                            )
                          else
                            _PicSelectorTile(
                              selectedEmployee: _selectedEmployee,
                              fallbackName: _selectedPic,
                              isLoading: _isLoadingEmployees,
                              errorText: _picError,
                              onTap: _openPicPicker,
                            ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _complaintController,
                            label: 'Keperluan (Opsional)',
                            hint:
                                'Contoh: ganti oli, bertemu PIC, bongkar muat',
                            maxLines: 2,
                            minLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _notesController,
                            label: 'Catatan (Opsional)',
                            hint: 'Opsional, catatan tambahan dari security',
                            maxLines: 2,
                            minLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      stepNumber: 4,
                      title: 'Foto kendaraan & supir',
                      subtitle: totalRequired > 0
                          ? 'Foto bertanda * wajib diisi'
                          : 'Dokumentasi kondisi kendaraan',
                      trailing: StatusChip(
                        requiredCount >= totalRequired
                            ? AppStatus.readyToExit
                            : AppStatus.info,
                        label: totalRequired > 0
                            ? '$requiredCount/$totalRequired wajib'
                            : '${_photos.length} foto',
                        compact: true,
                      ),
                      child: PhotoQuadPicker(
                        photos: _photos,
                        fotoSettings: _fotoSettings,
                        enabled: !_isSubmitting,
                        uploadCurrent: _uploadCurrent,
                        uploadTotal: _uploadTotal,
                        onPhotoCaptured: (angle, base64) {
                          setState(() => _photos[angle] = base64);
                        },
                        onPhotoRemoved: (angle) {
                          setState(() => _photos.remove(angle));
                        },
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
            hint: _isSubmitting
                ? 'Mohon tunggu, data sedang diproses.'
                : 'Data bertanda * wajib diisi.',
            child: ctaButton,
          ),
      ],
    );
  }
}

class _PicSelectorTile extends StatelessWidget {
  const _PicSelectorTile({
    required this.selectedEmployee,
    required this.fallbackName,
    required this.isLoading,
    required this.errorText,
    required this.onTap,
  });

  final EmployeeItem? selectedEmployee;
  final String? fallbackName;
  final bool isLoading;
  final String? errorText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final displayName = selectedEmployee?.name ?? fallbackName ?? '';
    final hasSelection = displayName.isNotEmpty;
    final role = selectedEmployee?.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text.rich(
            TextSpan(
              text: 'PIC / Petugas Tujuan',
              style: texts.labelMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: errorText != null
                  ? Border.all(color: scheme.error, width: 1.2)
                  : null,
            ),
            child: Row(
              children: [
                if (hasSelection)
                  InitialsAvatar(name: displayName, size: 36)
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_search_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasSelection
                            ? displayName
                            : (isLoading
                                  ? 'Memuat daftar PIC...'
                                  : 'Pilih petugas tujuan'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texts.bodyLarge?.copyWith(
                          color: hasSelection
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontWeight: hasSelection
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (role != null && role.isNotEmpty)
                        Text(
                          role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: texts.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: texts.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CandidateResultCard extends StatelessWidget {
  const _CandidateResultCard({this.candidate, this.searchedPlate});

  final CheckinCandidate? candidate;
  final String? searchedPlate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    if (candidate == null) {
      return AppCard(
        accentColor: scheme.outline,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: semantic.neutralContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: semantic.onNeutralContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const StatusChip(AppStatus.walkIn, compact: true),
                      const Spacer(),
                      PlateBadge(
                        searchedPlate == null || searchedPlate!.isEmpty
                            ? '-'
                            : searchedPlate!,
                        size: PlateBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Kendaraan belum terdaftar sebagai booking atau member.',
                    style: texts.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lengkapi data pengemudi dan tujuan secara manual.',
                    style: texts.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final item = candidate!;
    final isBooking = item.source == 'BOOKING';
    final confirmed = item.isConfirmed;
    final accent = isBooking
        ? (confirmed ? semantic.info : semantic.warning)
        : scheme.secondary;
    final vehicle = [
      item.merk,
      item.model,
      item.tahun?.toString(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

    return AppCard(
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatusChip(
                isBooking ? AppStatus.booking : AppStatus.member,
                label: isBooking
                    ? (confirmed ? 'Booking terkonfirmasi' : 'Booking')
                    : 'Member Fleet',
                compact: true,
              ),
              const Spacer(),
              PlateBadge(item.noPolisi, size: PlateBadgeSize.small),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isBooking
                ? (item.customerName ?? 'Pelanggan')
                : (item.namaPerusahaan ?? item.customerName ?? 'Member'),
            style: texts.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (isBooking) ...[
            InfoRow(
              label: 'Jadwal',
              value: '${item.tanggalBooking ?? '-'} ${item.jamBooking ?? ''}'
                  .trim(),
              dense: true,
            ),
            InfoRow(
              label: 'Layanan',
              value: item.jenisLayanan ?? 'Service',
              dense: true,
            ),
            if (item.keluhan != null && item.keluhan!.isNotEmpty)
              InfoRow(label: 'Keluhan', value: item.keluhan!, dense: true),
          ] else ...[
            InfoRow(
              label: 'Unit',
              value: vehicle.isEmpty ? '-' : vehicle,
              dense: true,
            ),
            if (item.namaPenggunaFleet != null &&
                item.namaPenggunaFleet!.isNotEmpty)
              InfoRow(
                label: 'Pengguna',
                value: item.namaPenggunaFleet!,
                dense: true,
              ),
            if (item.unitTelepon != null && item.unitTelepon!.isNotEmpty)
              InfoRow(label: 'Telepon', value: item.unitTelepon!, dense: true),
          ],
          if (isBooking && !confirmed) ...[
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
                      'Booking belum dikonfirmasi admin. Koordinasikan sebelum layanan lanjutan.',
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
        ],
      ),
    );
  }
}

class _CandidatePickerSheet extends StatelessWidget {
  const _CandidatePickerSheet({required this.candidates});

  final List<CheckinCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih kendaraan',
                          style: texts.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${candidates.length} data ditemukan',
                          style: texts.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final item = candidates[index];
                    final isBooking = item.source == 'BOOKING';
                    final detail = isBooking
                        ? '${item.customerName ?? 'Pelanggan'} • '
                              '${item.tanggalBooking ?? '-'} ${item.jamBooking ?? ''}'
                        : '${item.namaPerusahaan ?? item.customerName ?? 'Member'}'
                              '${item.merk != null ? ' • ${item.merk} ${item.model ?? ''}' : ''}';

                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      onTap: () => Navigator.of(context).pop(item),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isBooking
                                  ? scheme.primaryContainer
                                  : scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              isBooking
                                  ? Icons.event_available_rounded
                                  : Icons.local_shipping_rounded,
                              size: 20,
                              color: isBooking
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        formatPlate(item.noPolisi),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: texts.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    StatusChip(
                                      isBooking
                                          ? AppStatus.booking
                                          : AppStatus.member,
                                      compact: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  detail,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: texts.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PicPickerSheet extends StatefulWidget {
  const _PicPickerSheet({
    required this.employees,
    required this.isLoading,
    required this.selected,
    required this.onRetry,
  });

  final List<EmployeeItem> employees;
  final bool isLoading;
  final String? selected;
  final VoidCallback onRetry;

  @override
  State<_PicPickerSheet> createState() => _PicPickerSheetState();
}

class _PicPickerSheetState extends State<_PicPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final query = _query.trim().toLowerCase();
    final filtered = widget.employees
        .where(
          (emp) =>
              emp.name.toLowerCase().contains(query) ||
              emp.position.toLowerCase().contains(query),
        )
        .toList();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih PIC / Petugas',
                          style: texts.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Cari nama penerima atau penanggung jawab',
                          style: texts.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SearchField(
                autofocus: true,
                hintText: 'Cari nama PIC',
                debounce: const Duration(milliseconds: 120),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (widget.isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (widget.employees.isEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_search_outlined,
                          size: 40,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Daftar PIC belum tersedia.',
                          textAlign: TextAlign.center,
                          style: texts.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Muat ulang',
                          icon: Icons.refresh_rounded,
                          size: AppButtonSize.medium,
                          expanded: false,
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onRetry();
                          },
                        ),
                      ],
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                Flexible(
                  child: Center(
                    child: Text(
                      'PIC tidak ditemukan.',
                      style: texts.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xxs),
                    itemBuilder: (context, index) {
                      final employee = filtered[index];
                      final isSelected = widget.selected == employee.name;
                      return ListTile(
                        leading: InitialsAvatar(name: employee.name, size: 40),
                        title: Text(
                          employee.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: texts.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                  border: Border.all(
                                    color: scheme.primary.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  employee.position,
                                  style: texts.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: context.semantic.success,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(employee),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TujuanOptionPill extends StatelessWidget {
  const _TujuanOptionPill({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TujuanKedatanganItem item;
  final bool selected;
  final VoidCallback onTap;

  IconData _iconFor(String kode) {
    switch (kode.toUpperCase()) {
      case 'SERVICE':
        return Icons.build_rounded;
      case 'KUNJUNGAN':
        return Icons.badge_outlined;
      case 'BELI_SPAREPART':
        return Icons.inventory_2_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        constraints: const BoxConstraints(minHeight: 46, minWidth: 112),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? semantic.infoContainer : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                _iconFor(item.kodeTujuan),
                size: 16,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.namaTujuan,
              style: texts.labelLarge?.copyWith(
                color: selected ? scheme.primary : scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
