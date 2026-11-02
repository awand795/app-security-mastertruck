import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/active_vehicle_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
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
      _nopolController.text = widget.initialPlate!;
      _lookupVehicle(widget.initialPlate!);
    }
  }

  void _openAnprScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnprScannerSheet(
        onPlateDetected: (plate) {
          setState(() => _nopolController.text = plate);
          _lookupVehicle(plate);
        },
      ),
    );
  }

  Future<void> _lookupVehicle(String nopol) async {
    final clean = nopol.replaceAll(' ', '').trim().toUpperCase();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _selectedVehicle = null;
    });

    final list = await ApiService.getActiveInside(query: clean);
    if (!mounted) return;

    ActiveVehicle? found;
    for (final v in list) {
      if (v.noPolisi.replaceAll(' ', '') == clean) {
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
        const SnackBar(content: Text('Kendaraan tidak ditemukan di dalam bengkel.')),
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
          title: Text('Peringatan Status Pembayaran', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: Text(
            'Invoice servis kendaraan ini belum berstatus LUNAS (${_selectedVehicle!.statusInvoice ?? 'Belum Lunas'}). Lanjutkan checkout gerbang?',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tetap Keluarkan'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);

    final petugas = AuthService.currentSession?.name ?? 'Security Gate';
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
      await showDialog(
        context: context,
        builder: (_) => GatePassDialog(
          title: 'Gate Pass / Memo Keluar Digital',
          codeNumber: nomorMemo,
          nopol: _selectedVehicle!.noPolisi,
          driverName: _selectedVehicle!.namaPengemudi,
          customerName: _selectedVehicle!.namaPelanggan,
          spkNumber: _selectedVehicle!.nomorSpk,
          invoiceNumber: _selectedVehicle!.nomorInvoice,
          dateTime: DateTime.now(),
          isExit: true,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search / Scan Bar
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
                    'Nomor Polisi Kendaraan Keluar',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nopolController,
                          textCapitalization: TextCapitalization.characters,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'CONTOH: B 1234 WLG',
                            prefixIcon: Icon(Icons.pin, color: AppTheme.textMuted),
                          ),
                          onSubmitted: _lookupVehicle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppTheme.corporateNavy),
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: () => _lookupVehicle(_nopolController.text),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.camera_alt, color: AppTheme.corporateNavy),
                        onPressed: _openAnprScanner,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Detail Card if vehicle found
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppTheme.corporateNavy),
                ),
              )
            else if (_selectedVehicle != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedVehicle!.isSiapKeluar ? AppTheme.successGreen : AppTheme.errorRed,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.navyDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedVehicle!.noPolisi,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _selectedVehicle!.isSiapKeluar
                                ? AppTheme.successLight
                                : AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _selectedVehicle!.isSiapKeluar ? 'INVOICE LUNAS' : 'BELUM LUNAS',
                            style: GoogleFonts.plusJakartaSans(
                              color: _selectedVehicle!.isSiapKeluar
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _itemDetail('Pengemudi', _selectedVehicle!.namaPengemudi ?? '-'),
                    _itemDetail('Customer / Pemilik', _selectedVehicle!.namaPelanggan ?? '-'),
                    _itemDetail('No. SPK', _selectedVehicle!.nomorSpk ?? '-'),
                    _itemDetail('Status Servis', _selectedVehicle!.statusServis ?? '-'),
                    _itemDetail('No. Invoice', _selectedVehicle!.nomorInvoice ?? '-'),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Keluar (Opsional)',
                        hintText: 'Contoh: Muatan kosong, kondisi unit baik',
                        prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Foto Keluar 4 Sudut
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: PhotoQuadPicker(
                  photos: _exitPhotos,
                  onPhotoCaptured: (angle, b64) {
                    setState(() => _exitPhotos[angle] = b64);
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Submit Checkout Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleCheckOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedVehicle!.isSiapKeluar
                        ? AppTheme.corporateNavy
                        : AppTheme.errorRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.exit_to_app, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Konfirmasi Check-Out & Buka Gerbang',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _itemDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 12)),
          Text(value, style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
