import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/theme.dart';
import '../utils/plate_utils.dart';

class GatePassDialog extends StatelessWidget {
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
  final VoidCallback? onClose;

  const GatePassDialog({
    Key? key,
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
    this.onClose,
  })  : noPolisi = noPolisi ?? nopol ?? '',
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveCode = codeNumber ?? nomorMemo ?? nomorTiket ?? 'KIM3-PASS';
    final effectiveDriver = namaPengemudi ?? driverName ?? '-';
    final effectiveTitle = title ?? (nomorMemo != null ? 'Gate Pass Keluar Resmi' : 'Tiket Masuk Gerbang');
    final nowFormatted = DateFormat('dd MMM yyyy, HH:mm').format(dateTime ?? DateTime.now());

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Official Logo & Title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.corporateNavy,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/master-truck-logo-transparent.png',
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: AppTheme.amberGold, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          effectiveTitle,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Navigator.pop(context);
                          onClose?.call();
                        },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      // License Plate Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.corporateNavy,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          formatPlate(noPolisi),
                          style: GoogleFonts.chivo(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // QR Code
                      QrImageView(
                        data: effectiveCode,
                        version: QrVersions.auto,
                        size: 150.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppTheme.corporateNavy,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppTheme.corporateNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        effectiveCode,
                        style: GoogleFonts.chivo(
                          color: AppTheme.corporateNavy,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.0,
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppTheme.cardBorder),
                      const SizedBox(height: 12),

                      // Details
                      _detailRow('Waktu', nowFormatted),
                      _detailRow('Pengemudi', effectiveDriver),
                      if (customerName != null && customerName!.isNotEmpty)
                        _detailRow('Customer', customerName!),
                      if (tipeKunjungan != null && tipeKunjungan!.isNotEmpty)
                        _detailRow('Tujuan', tipeKunjungan!),
                      if (keluhan != null && keluhan!.isNotEmpty)
                        _detailRow('Keluhan', keluhan!),
                      if (spkNumber != null && spkNumber!.isNotEmpty)
                        _detailRow('No. SPK', spkNumber!),
                      if (invoiceNumber != null && invoiceNumber!.isNotEmpty)
                        _detailRow('No. Invoice', invoiceNumber!),
                      if (petugasSecurity != null && petugasSecurity!.isNotEmpty)
                        _detailRow('Petugas', petugasSecurity!),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onClose?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.corporateNavy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Selesai & Tutup',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
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
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
