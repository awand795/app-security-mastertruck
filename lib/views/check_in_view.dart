import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/booking_candidate_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
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

  String _tipeKunjungan = 'SERVIS';
  String _jenisKedatangan = 'WALK_IN';
  int? _bookingId;
  String? _picTujuan;
  List<String> _employeeList = [];

  final Map<String, String> _photos = {}; // 'DEPAN', 'BELAKANG', 'KIRI', 'KANAN'
  bool _isSubmitting = false;
  List<CheckinCandidate> _searchSuggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final list = await ApiService.getEmployees();
    if (mounted) {
      setState(() => _employeeList = list);
    }
  }

  void _openAnprScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnprScannerSheet(
        onPlateDetected: (plate) {
          setState(() {
            _nopolController.text = plate;
          });
          _onPlateChanged(plate);
        },
      ),
    );
  }

  Future<void> _onPlateChanged(String query) async {
    final clean = query.replaceAll(' ', '').trim();
    if (clean.length < 3) {
      setState(() => _searchSuggestions = []);
      return;
    }

    setState(() => _isSearching = true);
    final results = await ApiService.searchCandidates(clean);
    if (!mounted) return;

    setState(() {
      _isSearching = false;
      _searchSuggestions = results;
    });

    // Auto-fill jika match persis
    final exact = results.firstWhere(
      (c) => c.noPolisi.replaceAll(' ', '') == clean.toUpperCase(),
      orElse: () => CheckinCandidate(noPolisi: ''),
    );
    if (exact.noPolisi.isNotEmpty) {
      _applyCandidate(exact);
    }
  }

  void _applyCandidate(CheckinCandidate c) {
    setState(() {
      _nopolController.text = c.noPolisi;
      _bookingId = c.bookingId;
      _jenisKedatangan = c.bookingId != null ? 'BOOKING' : 'WALK_IN_MEMBER';
      if (c.namaPelanggan != null && _driverNameController.text.isEmpty) {
        _driverNameController.text = c.namaPelanggan!;
      }
      if (c.noTelepon != null && _driverPhoneController.text.isEmpty) {
        _driverPhoneController.text = c.noTelepon!;
      }
      if (c.keluhan != null) {
        _complaintController.text = c.keluhan!;
      }
      if (c.picTujuan != null) {
        _picTujuan = c.picTujuan;
      }
      _searchSuggestions = [];
    });
  }

  Future<void> _handleSubmitCheckIn() async {
    final nopol = _nopolController.text.trim().toUpperCase();
    final driver = _driverNameController.text.trim();
    final phone = _driverPhoneController.text.trim();
    final complaint = _complaintController.text.trim();

    if (nopol.isEmpty) {
      _showToast('Nomor polisi harus diisi!');
      return;
    }
    if (driver.isEmpty) {
      _showToast('Nama pengemudi harus diisi!');
      return;
    }

    setState(() => _isSubmitting = true);

    final petugas = AuthService.currentSession?.name ?? 'Security Gate';
    final res = await ApiService.postCheckIn(
      noPolisi: nopol,
      namaPengemudi: driver,
      noTeleponPengemudi: phone,
      tipeKunjungan: _tipeKunjungan,
      keluhan: complaint.isEmpty ? 'Servis rutin berkala' : complaint,
      petugasSecurity: petugas,
      bookingId: _bookingId,
      picTujuan: _picTujuan,
      jenisKedatangan: _jenisKedatangan,
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

      // Tampilkan Tiket Digital Modal
      await showDialog(
        context: context,
        builder: (_) => GatePassDialog(
          title: 'Tiket Masuk Kendaraan',
          codeNumber: nomorTiket,
          nopol: nopol,
          driverName: driver,
          customerName: _jenisKedatangan,
          dateTime: DateTime.now(),
          isExit: false,
        ),
      );

      // Reset Form
      setState(() {
        _isSubmitting = false;
        _nopolController.clear();
        _driverNameController.clear();
        _driverPhoneController.clear();
        _complaintController.clear();
        _bookingId = null;
        _jenisKedatangan = 'WALK_IN';
        _photos.clear();
      });
    } else {
      setState(() => _isSubmitting = false);
      _showToast(res['message'] ?? 'Gagal check-in.');
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Plat Input & AI Scanner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nomor Polisi Kendaraan',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _jenisKedatangan == 'BOOKING'
                              ? AppTheme.successLight
                              : AppTheme.amberLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _jenisKedatangan == 'BOOKING' ? 'TERDAFTAR BOOKING' : 'WALK-IN',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: _jenisKedatangan == 'BOOKING'
                                ? AppTheme.successGreen
                                : AppTheme.amberGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nopolController,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: _onPlateChanged,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                          decoration: InputDecoration(
                            hintText: 'CONTOH: B 1234 WLG',
                            prefixIcon: const Icon(Icons.pin, color: AppTheme.textMuted),
                            suffixIcon: _isSearching
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _openAnprScanner,
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          label: Text(
                            'Scan AI',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.corporateNavy,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Search Suggestions Box
                  if (_searchSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _searchSuggestions.map((c) {
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              c.bookingId != null ? Icons.event_available : Icons.local_shipping,
                              color: AppTheme.corporateNavy,
                              size: 20,
                            ),
                            title: Text(
                              c.noPolisi,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${c.namaPelanggan ?? 'Member'} • ${c.jenisKedatangan ?? 'BOOKING'}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                            onTap: () => _applyCandidate(c),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Form Detail Pengemudi & Layanan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Pengemudi & Kunjungan',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _driverNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pengemudi / Sopir *',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _driverPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'No. Handphone / WhatsApp',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tipe Kunjungan Dropdown
                  DropdownButtonFormField<String>(
                    value: _tipeKunjungan,
                    decoration: const InputDecoration(
                      labelText: 'Tipe Kunjungan',
                      prefixIcon: Icon(Icons.build_circle_outlined, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SERVIS', child: Text('Servis / Perbaikan Truk')),
                      DropdownMenuItem(value: 'CUCI', child: Text('Cuci Armada Truk')),
                      DropdownMenuItem(value: 'INSPEKSI', child: Text('Inspeksi Pra-Operasional')),
                      DropdownMenuItem(value: 'LAINNYA', child: Text('Tamu / Keperluan Lainnya')),
                    ],
                    onChanged: (v) => setState(() => _tipeKunjungan = v ?? 'SERVIS'),
                  ),
                  const SizedBox(height: 12),

                  // PIC Dropdown
                  DropdownButtonFormField<String>(
                    value: _picTujuan,
                    decoration: const InputDecoration(
                      labelText: 'PIC Tujuan (Opsional)',
                      prefixIcon: Icon(Icons.support_agent_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('- Pilih PIC Penerima -')),
                      ..._employeeList.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                    ],
                    onChanged: (v) => setState(() => _picTujuan = v),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _complaintController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Keluhan / Catatan Kedatangan',
                      hintText: 'Contoh: Rem bunyi, ganti oli mesin rutin',
                      prefixIcon: Icon(Icons.notes_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Foto 4 Sudut Component
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: PhotoQuadPicker(
                photos: _photos,
                onPhotoCaptured: (angle, b64) {
                  setState(() => _photos[angle] = b64);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmitCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.corporateNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Catat Check-In & Terbitkan Tiket',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
