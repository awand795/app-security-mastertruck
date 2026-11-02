import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/active_vehicle_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/plate_utils.dart';
import '../widgets/anpr_scanner_sheet.dart';
import '../widgets/photo_quad_picker.dart';
import '../widgets/gate_pass_dialog.dart';

class CheckOutView extends StatefulWidget {
  final String? initialPlate;
  final VoidCallback? onClearInitialPlate;

  const CheckOutView({Key? key, this.initialPlate, this.onClearInitialPlate}) : super(key: key);

  @override
  State<CheckOutView> createState() => _CheckOutViewState();
}

class _CheckOutViewState extends State<CheckOutView> {
  final _nopolController = TextEditingController();
  final _notesController = TextEditingController();

  ActiveVehicle? _selectedVehicle;
  bool _isLoading = false;
  bool _isSubmitting = false;
  final Map<String, String> _exitPhotos = {};

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnprScannerSheet(
        onPlateDetected: (plate) {
          final formatted = formatPlate(plate);
          setState(() => _nopolController.text = formatted);
          _lookupVehicle(formatted);
        },
      ),
    );
  }

  Future<void> _lookupVehicle(String nopol) async {
    final clean = normalizePlate(nopol);
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _selectedVehicle = null;
    });

    final list = await ApiService.getActiveInside(query: clean);
    if (!mounted) return;

    ActiveVehicle? found;
    for (final v in list) {
      if (normalizePlate(v.noPolisi) == clean) {
        found = v;
        break;
      }
    }

    setState(() {
      _isLoading = false;
      _selectedVehicle = found ?? (list.isNotEmpty ? list.first : null);
    });

    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kendaraan $nopol tidak ditemukan di dalam bengkel.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.corporateNavy,
        ),
      );
    }
  }

  Future<void> _handleCheckOut() async {
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih atau cari kendaraan terlebih dahulu.')),
      );
      return;
    }

    if (!_selectedVehicle!.isSiapKeluar) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.amberGold, size: 26),
              const SizedBox(width: 8),
              Text(
                'Perhatian Invoice',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            'Invoice servis kendaraan ini belum berstatus LUNAS (${_selectedVehicle!.statusInvoice ?? 'Belum Lunas'}).\n\nTetap izinkan kendaraan keluar gerbang?',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amberGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Izinkan Keluar'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);

    final petugas = AuthService.currentSession?.name ?? 'Pos Security KIM 3';
    final res = await ApiService.postCheckOut(
      kunjunganId: _selectedVehicle!.id,
      petugasSecurityKeluar: petugas,
      catatanKeluar: _notesController.text.trim(),
    );

    if (!mounted) return;

    if (res['success'] == true) {
      final nomorMemo = res['nomor_memo'] ?? 'MEMO-KIM3';

      // Upload Foto Keluar jika ada
      if (_exitPhotos.isNotEmpty) {
        for (final entry in _exitPhotos.entries) {
          await ApiService.postAddFoto(
            kunjunganId: _selectedVehicle!.id,
            jenisEvent: 'KELUAR',
            sudutPandang: entry.key,
            base64Image: entry.value,
          );
        }
      }

      // Dialog Gate Pass Keluar
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => GatePassDialog(
          nomorTiket: _selectedVehicle!.nomorTiket ?? 'TKT-KIM3',
          noPolisi: formatPlate(_selectedVehicle!.noPolisi),
          namaPengemudi: _selectedVehicle!.namaPengemudi ?? '-',
          tipeKunjungan: _selectedVehicle!.tipeKunjungan ?? 'Service',
          keluhan: _selectedVehicle!.keluhan ?? 'Pengecekan armada',
          waktuMasuk: _selectedVehicle!.waktuCheckIn != null
              ? DateFormat('HH:mm').format(_selectedVehicle!.waktuCheckIn!)
              : '-',
          waktuKeluar: DateFormat('HH:mm').format(DateTime.now()),
          nomorMemo: nomorMemo,
          petugasSecurity: petugas,
          onClose: () {},
        ),
      );

      setState(() {
        _isSubmitting = false;
        _nopolController.clear();
        _notesController.clear();
        _selectedVehicle = null;
        _exitPhotos.clear();
      });
      widget.onClearInitialPlate?.call();
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal check-out.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card 1: Nomor Polisi Kendaraan Keluar
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.corporateNavy,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.exit_to_app_rounded, color: AppTheme.amberGold, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pemeriksaan Kendaraan Keluar',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppTheme.corporateNavy,
                                  ),
                                ),
                                Text(
                                  'Validasi invoice & terbitkan Gate Pass',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Input Plat Nomor
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
                                        setState(() => _selectedVehicle = null);
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: _lookupVehicle,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            // 1. Scan Kamera Keluar
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

                            // 2. Cari Kendaraan Keluar
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _lookupVehicle(_nopolController.text),
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
                                          child: const Icon(
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
                                                'Cek Plat',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                'Cek Invoice Lunas',
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
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Detail Card if vehicle found
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppTheme.corporateNavy),
                    ),
                  )
                else if (_selectedVehicle != null) ...[
                  Card(
                    elevation: 0,
                    color: AppTheme.surfaceWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: _selectedVehicle!.isSiapKeluar ? AppTheme.successGreen : AppTheme.amberGold,
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formatPlate(_selectedVehicle!.noPolisi),
                                    style: GoogleFonts.chivo(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.corporateNavy,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'Tiket: ${_selectedVehicle!.nomorTiket ?? '-'}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _selectedVehicle!.isSiapKeluar ? AppTheme.successLight : AppTheme.amberLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _selectedVehicle!.isSiapKeluar ? 'LUNAS • SIAP KELUAR' : 'BELUM LUNAS',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: _selectedVehicle!.isSiapKeluar ? AppTheme.successGreen : AppTheme.amberGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Driver & SPK Details
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Pengemudi', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                                    Text(
                                      _selectedVehicle!.namaPengemudi ?? '-',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Pelanggan / Armada', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                                    Text(
                                      _selectedVehicle!.namaPelanggan ?? '-',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Text('Keluhan Awal', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textMuted)),
                          Text(
                            (_selectedVehicle!.keluhan != null && _selectedVehicle!.keluhan!.isNotEmpty) ? _selectedVehicle!.keluhan! : '-',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 16),

                          // Notes
                          Text(
                            'Catatan Keluar (Opsional)',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              hintText: 'Keterangan kondisi saat keluar gerbang...',
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

                  // Exit Photos
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
                        photos: _exitPhotos,
                        onPhotoCaptured: (angle, b64) => setState(() => _exitPhotos[angle] = b64),
                        onPhotoRemoved: (angle) => setState(() => _exitPhotos.remove(angle)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Checkout Action Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleCheckOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedVehicle!.isSiapKeluar ? AppTheme.successGreen : AppTheme.corporateNavy,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Selesai & Terbitkan Memo Keluar (Gate Pass)',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
