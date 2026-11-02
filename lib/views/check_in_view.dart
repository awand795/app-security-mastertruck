import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/booking_candidate_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/plate_utils.dart';
import '../widgets/anpr_scanner_sheet.dart';
import '../widgets/photo_quad_picker.dart';
import '../widgets/gate_pass_dialog.dart';

class CheckInView extends StatefulWidget {
  const CheckInView({Key? key}) : super(key: key);

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

  final Map<String, String> _photos = {}; // 'DEPAN', 'BELAKANG', 'KIRI', 'KANAN' -> base64
  bool _isSubmitting = false;

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
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await ApiService.getEmployees();
      if (mounted) {
        setState(() {
          _employeeList = list;
          _isLoadingEmployees = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  // Open Native Camera AI ANPR Scanner
  void _openAnprScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnprScannerSheet(
        onPlateDetected: (detectedPlate) {
          final formatted = formatPlate(detectedPlate);
          setState(() {
            _nopolController.text = formatted;
          });
          // Otomatis langsung Cek Plat saat scan kamera selesai
          _executePlateSearch(formatted);
        },
      ),
    );
  }

  // Eksekusi Cek Plat ke database / API
  Future<void> _executePlateSearch([String? targetPlate]) async {
    final query = targetPlate ?? _nopolController.text;
    final clean = normalizePlate(query);

    if (clean.length < 3) {
      _showSnackBar('Masukkan minimal 3 karakter nomor polisi.');
      return;
    }

    setState(() {
      _isSearchingPlate = true;
      _hasSearchedPlate = false;
      _candidates = [];
    });

    try {
      final results = await ApiService.searchCandidates(clean);
      if (!mounted) return;

      setState(() {
        _isSearchingPlate = false;
        _hasSearchedPlate = true;
        _candidates = results;
      });

      // 1. Cek apakah ada exact match
      final exactMatches = results.where((item) => item.noPolisiClean == clean).toList();

      if (exactMatches.length == 1) {
        // Tepat 1 kandidat cocok -> langsung auto-fill
        _applyCandidate(exactMatches.first, forceFill: true);
      } else if (results.isNotEmpty) {
        // Lebih dari 1 kandidat -> buka Bottom Sheet pilihan
        _showCandidatesSelectionSheet(results);
      } else {
        // Walk-in umum (tidak ada booking dan bukan member)
        setState(() {
          _selectedCandidate = null;
          _jenisKedatangan = 'WALK_IN';
          _bookingId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingPlate = false);
        _showSnackBar('Gagal mencari data plat: $e');
      }
    }
  }

  void _applyCandidate(CheckinCandidate candidate, {bool forceFill = false}) {
    setState(() {
      _selectedCandidate = candidate;
      _nopolController.text = formatPlate(candidate.noPolisi);
      _bookingId = candidate.bookingId;
      _jenisKedatangan = candidate.source == 'BOOKING' ? 'BOOKING' : 'WALK_IN_MEMBER';

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

    // Peringatan jika Booking belum dikonfirmasi admin
    if (candidate.source == 'BOOKING' && !candidate.isConfirmed) {
      _showUnconfirmedBookingWarning(candidate);
    }
  }

  void _showUnconfirmedBookingWarning(CheckinCandidate candidate) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.amberGold, size: 26),
            const SizedBox(width: 8),
            Text(
              'Perhatian Booking',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Booking armada ${formatPlate(candidate.noPolisi)} (${candidate.customerName ?? 'Pelanggan'}) belum dikonfirmasi oleh Customer Service/Admin bengkel.\n\nPastikan koordinasi sebelum proses service lanjutan.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.corporateNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Saya Mengerti'),
          ),
        ],
      ),
    );
  }

  void _showCandidatesSelectionSheet(List<CheckinCandidate> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Data Kendaraan (${list.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.corporateNavy,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final item = list[idx];
                  final isBooking = item.source == 'BOOKING';
                  final vehicleDesc = [item.merk, item.model].where((s) => s != null && s.isNotEmpty).join(' ');

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _applyCandidate(item, forceFill: true);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isBooking ? AppTheme.successGreen.withOpacity(0.4) : AppTheme.cardBorder,
                          width: isBooking ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isBooking ? AppTheme.successLight : AppTheme.corporateNavy.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isBooking ? Icons.event_available : Icons.local_shipping,
                              color: isBooking ? AppTheme.successGreen : AppTheme.corporateNavy,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      formatPlate(item.noPolisi),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: AppTheme.corporateNavy,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isBooking ? AppTheme.successLight : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isBooking ? 'BOOKING' : 'MEMBER FLEET',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9,
                                          color: isBooking ? AppTheme.successGreen : Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isBooking
                                      ? '${item.customerName ?? 'Pelanggan'} • Jadwal: ${item.tanggalBooking ?? '-'} ${item.jamBooking ?? ''}'
                                      : '${item.namaPerusahaan ?? item.customerName ?? 'Member'} ${vehicleDesc.isNotEmpty ? '• $vehicleDesc' : ''}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmitCheckIn() async {
    final rawPlate = _nopolController.text.trim();
    final cleanPlate = normalizePlate(rawPlate);
    final driver = _driverNameController.text.trim();
    final phone = _driverPhoneController.text.trim();
    final complaint = _complaintController.text.trim();
    final notes = _notesController.text.trim();

    if (cleanPlate.length < 3) {
      _showSnackBar('Nomor polisi harus diisi dengan benar!');
      return;
    }
    if (driver.isEmpty) {
      _showSnackBar('Nama pengemudi wajib diisi!');
      return;
    }
    if (_selectedPic == null || _selectedPic!.isEmpty) {
      _showSnackBar('Pilih PIC / Petugas Tujuan terlebih dahulu!');
      return;
    }

    final effectiveTipe = _tipeKunjungan == 'Lainnya'
        ? (_customTipeController.text.trim().isNotEmpty ? _customTipeController.text.trim() : 'Lainnya')
        : _tipeKunjungan;

    setState(() => _isSubmitting = true);

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

      // Upload Foto 4 Sudut jika ada
      if (kunjunganId != null && _photos.isNotEmpty) {
        for (final entry in _photos.entries) {
          await ApiService.postAddFoto(
            kunjunganId: kunjunganId is int ? kunjunganId : int.tryParse(kunjunganId.toString()) ?? 0,
            jenisEvent: 'MASUK',
            sudutPandang: entry.key,
            base64Image: entry.value,
          );
        }
      }

      setState(() => _isSubmitting = false);

      // Tampilkan Tiket Digital & QR Code
      showDialog(
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
          onClose: () {
            _resetForm();
          },
        ),
      );
    } else {
      setState(() => _isSubmitting = false);
      _showSnackBar(res['message'] ?? 'Gagal menyimpan check-in.');
    }
  }

  void _resetForm() {
    setState(() {
      _nopolController.clear();
      _driverNameController.clear();
      _driverPhoneController.clear();
      _complaintController.clear();
      _notesController.clear();
      _customTipeController.clear();
      _tipeKunjungan = 'Service';
      _jenisKedatangan = 'WALK_IN';
      _bookingId = null;
      _selectedCandidate = null;
      _hasSearchedPlate = false;
      _candidates.clear();
      _photos.clear();
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.corporateNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBooking = _selectedCandidate?.source == 'BOOKING';
    final isMember = _selectedCandidate?.source == 'MEMBER_UNIT';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // KARTU 1: IDENTIFIKASI PELAT NOMOR KENDARAAN
              // ==========================================
              Card(
                elevation: 0,
                color: AppTheme.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppTheme.cardBorder, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.corporateNavy,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.directions_car, color: AppTheme.amberGold, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nomor Polisi Kendaraan',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: AppTheme.corporateNavy,
                                    ),
                                  ),
                                  Text(
                                    'Deteksi Otomatis atau Ketik Plat',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isBooking
                                  ? AppTheme.successLight
                                  : (isMember ? Colors.blue.shade50 : AppTheme.backgroundLight),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isBooking
                                    ? AppTheme.successGreen.withOpacity(0.4)
                                    : (isMember ? Colors.blue.shade200 : AppTheme.cardBorder),
                              ),
                            ),
                            child: Text(
                              isBooking ? 'BOOKING' : (isMember ? 'MEMBER FLEET' : 'WALK-IN'),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                color: isBooking
                                    ? AppTheme.successGreen
                                    : (isMember ? Colors.blue.shade700 : AppTheme.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Kolom Input Plat Nomor - Full Width, font besar leluasa (tidak terpotong kamera)
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                        ),
                        child: TextField(
                          controller: _nopolController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [PlateInputFormatter()],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.chivo(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                            color: AppTheme.corporateNavy,
                          ),
                          decoration: InputDecoration(
                            hintText: 'B 2156 TQR',
                            hintStyle: GoogleFonts.chivo(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3.0,
                              color: Colors.grey.shade400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            suffixIcon: _nopolController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.cancel_rounded, color: AppTheme.textMuted, size: 22),
                                    onPressed: () {
                                      _nopolController.clear();
                                      setState(() {
                                        _selectedCandidate = null;
                                        _hasSearchedPlate = false;
                                        _candidates.clear();
                                        _jenisKedatangan = 'WALK_IN';
                                        _bookingId = null;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (val) => _executePlateSearch(val),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quick Action Buttons: Scan Kamera AI & Cek Plat Booking
                      Row(
                        children: [
                          // 1. Scan Kamera AI ANPR Card Button
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _openAnprScanner,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                  decoration: BoxDecoration(
                                    color: AppTheme.corporateNavy.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.corporateNavy.withOpacity(0.2),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.corporateNavy,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.document_scanner_rounded,
                                          color: AppTheme.amberGold,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Scan Plat',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: AppTheme.corporateNavy,
                                              ),
                                            ),
                                            Text(
                                              'Deteksi AI Instan',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 9.5,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // 2. Cek Plat / Booking Database Button
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isSearchingPlate ? null : () => _executePlateSearch(),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0A2540),
                                        Color(0xFF1E3A8A),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0A2540).withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.16),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: _isSearchingPlate
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppTheme.amberGold,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.search_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _isSearchingPlate ? 'Memeriksa...' : 'Cek Plat',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              'Verifikasi Booking',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 9.5,
                                                color: Colors.white.withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Hasil Verifikasi Plat Status Banner
                      if (_hasSearchedPlate) ...[
                        const SizedBox(height: 14),
                        if (isBooking && _selectedCandidate != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.successLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.successGreen.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Booking Terkonfirmasi: ${_selectedCandidate!.customerName ?? 'Pelanggan'}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: AppTheme.successGreen,
                                        ),
                                      ),
                                      Text(
                                        'Jadwal: ${_selectedCandidate!.tanggalBooking ?? '-'} ${_selectedCandidate!.jamBooking ?? ''} • ${_selectedCandidate!.jenisLayanan ?? 'Service'}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isMember && _selectedCandidate != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_shipping_rounded, color: Colors.blue.shade700, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Armada Member Fleet: ${_selectedCandidate!.namaPerusahaan ?? _selectedCandidate!.customerName ?? 'Member'}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      Text(
                                        'Tipe Unit: ${[_selectedCandidate!.merk, _selectedCandidate!.model].where((s) => s != null).join(' ')}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Walk-In Umum: Kendaraan belum memiliki jadwal booking / member. Data dapat diisi langsung.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
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
              ),

              const SizedBox(height: 16),

              // ==========================================
              // KARTU 2: DATA KUNJUNGAN & PENGEMUDI
              // ==========================================
              Card(
                elevation: 0,
                color: AppTheme.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppTheme.cardBorder, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.amberGold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.assignment_ind_rounded, color: AppTheme.amberGold, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data Kunjungan & Supir',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.corporateNavy,
                                ),
                              ),
                              Text(
                                'Identitas pengemudi dan keperluan kunjungan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Tujuan Kedatangan
                      Text(
                        'Tujuan Kedatangan *',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _tipeKunjungan,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Service', child: Text('Service / Perbaikan')),
                          DropdownMenuItem(value: 'Kunjungan', child: Text('Kunjungan / Tamu')),
                          DropdownMenuItem(value: 'Beli Part', child: Text('Beli Sparepart')),
                          DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya (Isi Sendiri)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _tipeKunjungan = val);
                        },
                      ),

                      if (_tipeKunjungan == 'Lainnya') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customTipeController,
                          decoration: InputDecoration(
                            hintText: 'Tuliskan tujuan kedatangan...',
                            filled: true,
                            fillColor: AppTheme.backgroundLight,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Nama Pengemudi
                      Text(
                        'Nama Pengemudi *',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _driverNameController,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Joko Widodo / Supir Armada',
                          prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppTheme.corporateNavy),
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // No Kontak / HP Pengemudi
                      Text(
                        'No. Telepon / WhatsApp Pengemudi',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _driverPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 081234567890',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppTheme.corporateNavy),
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // PIC / Petugas Tujuan
                      Text(
                        'PIC / Petugas Tujuan *',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedPic,
                        isExpanded: true,
                        hint: Text(
                          _isLoadingEmployees ? 'Memuat daftar PIC...' : 'Pilih PIC / SA / Mekanik',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: _employeeList.map((e) {
                          return DropdownMenuItem<String>(
                            value: e,
                            child: Text(e, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedPic = val),
                      ),

                      const SizedBox(height: 14),

                      // Keluhan / Keperluan
                      Text(
                        'Keperluan Kunjungan / Keluhan Unit',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _complaintController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Ganti oli berkala, perbaikan rem, cek suspensi...',
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Catatan Masuk (Optional)
                      Text(
                        'Catatan Tambahan Masuk (Opsional)',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          hintText: 'Catatan kondisi fisik / barang bawaan supir...',
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // KARTU 3: DOKUMENTASI FISIK 4 SUDUT
              // ==========================================
              Card(
                elevation: 0,
                color: AppTheme.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppTheme.cardBorder, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: PhotoQuadPicker(
                    photos: _photos,
                    onPhotoCaptured: (angle, b64) {
                      setState(() => _photos[angle] = b64);
                    },
                    onPhotoRemoved: (angle) {
                      setState(() => _photos.remove(angle));
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // TOMBOL EKSEKUSI CHECK-IN
              // ==========================================
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmitCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.corporateNavy,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Konfirmasi & Cetak Tiket Masuk',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
