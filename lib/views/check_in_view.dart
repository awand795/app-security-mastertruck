import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/booking_candidate_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/plate_utils.dart';
import '../widgets/anpr_scanner_sheet.dart';
import '../widgets/app_widgets.dart';
import '../widgets/gate_pass_dialog.dart';
import '../widgets/photo_quad_picker.dart';

class CheckInView extends StatefulWidget {
  const CheckInView({super.key, this.employeeLoader, this.candidateSearcher});

  /// Opsional untuk preview/test; produksi memakai ApiService.
  final Future<List<String>> Function()? employeeLoader;
  final Future<List<CheckinCandidate>> Function(String query)?
  candidateSearcher;

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

  String _tipeKunjungan = 'Service';
  String _jenisKedatangan = 'WALK_IN';
  int? _bookingId;
  String? _selectedPic;
  List<String> _employeeList = [];
  bool _isLoadingEmployees = true;

  CheckinCandidate? _selectedCandidate;
  List<CheckinCandidate> _candidates = [];
  bool _isSearchingPlate = false;
  bool _hasSearchedPlate = false;

  final Map<String, String> _photos = {};
  bool _isSubmitting = false;
  int? _uploadCurrent;
  int? _uploadTotal;

  String? _plateError;
  String? _driverError;
  String? _picError;

  static const _tipeOptions = ['Service', 'Kunjungan', 'Beli Part', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
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

    if (clean.length < 3) {
      setState(() => _plateError = 'Minimal 3 karakter nomor polisi.');
      _showSnackBar('Masukkan minimal 3 karakter nomor polisi.');
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
      _picError = null;

      final driverName = candidate.effectiveDriverName;
      final phone = candidate.effectivePhone;
      final complaint = candidate.effectiveComplaint;

      if (forceFill || _driverNameController.text.trim().isEmpty) {
        if (driverName.isNotEmpty) _driverNameController.text = driverName;
      }
      if (forceFill || _driverPhoneController.text.trim().isEmpty) {
        if (phone.isNotEmpty) _driverPhoneController.text = phone;
      }
      if (forceFill || _complaintController.text.trim().isEmpty) {
        if (complaint.isNotEmpty) _complaintController.text = complaint;
      }

      if (candidate.source == 'BOOKING') {
        _tipeKunjungan = candidate.mappedTipeKunjungan;
        if (_tipeKunjungan == 'Lainnya' && candidate.jenisLayanan != null) {
          _customTipeController.text = candidate.jenisLayanan!;
        }
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
    final selected = await showModalBottomSheet<String>(
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
        _selectedPic = selected;
        _picController.text = selected;
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

    final plateError = cleanPlate.length < 3
        ? 'Nomor polisi belum valid.'
        : null;
    final driverError = driver.isEmpty ? 'Nama pengemudi wajib diisi.' : null;
    final picError = (_selectedPic == null || _selectedPic!.isEmpty)
        ? 'Pilih PIC tujuan.'
        : null;

    if (plateError != null || driverError != null || picError != null) {
      setState(() {
        _plateError = plateError;
        _driverError = driverError;
        _picError = picError;
      });
      _showSnackBar('Lengkapi data bertanda * terlebih dahulu.');
      return;
    }

    final effectiveTipe = _tipeKunjungan == 'Lainnya'
        ? (_customTipeController.text.trim().isNotEmpty
              ? _customTipeController.text.trim()
              : 'Lainnya')
        : _tipeKunjungan;

    setState(() {
      _isSubmitting = true;
      _uploadCurrent = null;
      _uploadTotal = null;
    });

    final petugas = AuthService.currentSession?.name ?? 'Pos Security KIM 3';
    final res = await ApiService.postCheckIn(
      noPolisi: cleanPlate,
      namaPengemudi: driver,
      noTeleponPengemudi: phone,
      tipeKunjungan: effectiveTipe,
      keluhan: complaint.isEmpty ? 'Pengecekan umum armada' : complaint,
      petugasSecurity: petugas,
      bookingId: _bookingId,
      picTujuan: _selectedPic,
      jenisKedatangan: _jenisKedatangan,
      catatanMasuk: notes,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final kunjunganId = res['kunjungan_id'];
      final nomorTiket = res['nomor_tiket'] ?? 'TKT-KIM3';
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
        builder: (_) => GatePassDialog(
          nomorTiket: nomorTiket,
          noPolisi: formatPlate(cleanPlate),
          namaPengemudi: driver,
          tipeKunjungan: effectiveTipe,
          keluhan: complaint.isEmpty ? 'Pengecekan armada' : complaint,
          waktuMasuk: 'Baru Saja',
          petugasSecurity: petugas,
          uploadWarning: failedUploads == 0
              ? null
              : '$failedUploads dari $totalUploads foto gagal diunggah. '
                    'Data check-in tetap tersimpan, tetapi foto masuk belum lengkap.',
          onClose: _resetForm,
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
      _tipeKunjungan = 'Service';
      _jenisKedatangan = 'WALK_IN';
      _bookingId = null;
      _selectedCandidate = null;
      _selectedPic = null;
      _hasSearchedPlate = false;
      _candidates.clear();
      _photos.clear();
      _isSubmitting = false;
      _uploadCurrent = null;
      _uploadTotal = null;
      _plateError = null;
      _driverError = null;
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
    final semantic = context.semantic;
    final texts = Theme.of(context).textTheme;
    final photoCount = _photos.length.clamp(0, 4).toInt();
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
                      subtitle: 'Scan kamera atau ketik manual',
                      icon: Icons.directions_car_rounded,
                      trailing: _hasSearchedPlate || _selectedCandidate != null
                          ? StatusChip(
                              _statusFor(_selectedCandidate),
                              compact: true,
                            )
                          : null,
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
                            loading: _isSearchingPlate,
                            loadingLabel: 'Memeriksa data',
                            onPressed: _isSearchingPlate
                                ? null
                                : () => _executePlateSearch(),
                          ),
                        ),
                      ],
                    ),
                    if (_hasSearchedPlate) ...[
                      const SizedBox(height: AppSpacing.md),
                      _CandidateResultCard(
                        candidate: _selectedCandidate,
                        searchedPlate: _nopolController.text,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(
                      title: 'Data Pengemudi & Tujuan',
                      subtitle: 'Identitas pengemudi dan keperluan kunjungan',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tujuan kunjungan *',
                            style: texts.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: _tipeOptions.map((option) {
                              final selected = _tipeKunjungan == option;
                              final display = option == 'Beli Part'
                                  ? 'Sparepart'
                                  : option;
                              return ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                child: ChoiceChip(
                                  label: Text(display),
                                  selected: selected,
                                  showCheckmark: false,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.padded,
                                  selectedColor: scheme.primaryContainer,
                                  backgroundColor: scheme.surfaceContainer,
                                  side: BorderSide(
                                    color: selected
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                  ),
                                  labelStyle: texts.labelLarge?.copyWith(
                                    color: selected
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                  ),
                                  onSelected: (value) {
                                    if (!value) return;
                                    setState(() {
                                      _tipeKunjungan = option;
                                      if (option != 'Lainnya') {
                                        _customTipeController.clear();
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                          if (_tipeKunjungan == 'Lainnya') ...[
                            const SizedBox(height: AppSpacing.sm),
                            AppTextField(
                              controller: _customTipeController,
                              label: 'Tujuan lainnya',
                              hint: 'Tuliskan tujuan kedatangan',
                              required: true,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
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
                            label: 'Nomor telepon pengemudi',
                            hint: 'Contoh: 0812 3456 7890',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _picController,
                            label: 'PIC / Petugas Tujuan',
                            hint: _isLoadingEmployees
                                ? 'Memuat daftar PIC...'
                                : 'Pilih petugas tujuan',
                            required: true,
                            readOnly: true,
                            prefixIcon: Icons.person_search_outlined,
                            errorText: _picError,
                            onTap: _openPicPicker,
                            suffixIcon: IconButton(
                              tooltip: 'Pilih PIC',
                              onPressed: _openPicPicker,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _complaintController,
                            label: 'Keperluan / keluhan',
                            hint: 'Contoh: ganti oli, periksa rem',
                            maxLines: 3,
                            minLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _notesController,
                            label: 'Catatan tambahan',
                            hint: 'Opsional, misalnya kondisi barang bawaan',
                            maxLines: 2,
                            minLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'Foto Kendaraan',
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
                        photos: _photos,
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
        StickyBottomBar(
          hint: _isSubmitting
              ? 'Mohon tunggu, data sedang diproses.'
              : 'Data bertanda * wajib diisi.',
          child: AppButton(
            label: 'Konfirmasi Check-In',
            icon: Icons.check_circle_outline_rounded,
            loading: _isSubmitting,
            loadingLabel: uploadLabel ?? 'Memproses check-in',
            onPressed: _isSubmitting ? null : _handleSubmitCheckIn,
          ),
        ),
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

  final List<String> employees;
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
    final query = _query.toLowerCase();
    final filtered = widget.employees
        .where((name) => name.toLowerCase().contains(query))
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
                      final isSelected = widget.selected == employee;
                      return ListTile(
                        leading: InitialsAvatar(name: employee, size: 40),
                        title: Text(
                          employee,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: texts.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
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
