import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/memo_keluar_model.dart';
import '../services/api_service.dart';
import '../utils/plate_utils.dart';
import '../widgets/gate_pass_dialog.dart';

class TodayExitView extends StatefulWidget {
  const TodayExitView({Key? key}) : super(key: key);

  @override
  State<TodayExitView> createState() => _TodayExitViewState();
}

class _TodayExitViewState extends State<TodayExitView> {
  final _searchController = TextEditingController();
  List<MemoKeluar> _memos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData([String q = '']) async {
    setState(() => _isLoading = true);
    final data = await ApiService.getMemoKeluar(query: q);
    if (mounted) {
      setState(() {
        _memos = data;
        _isLoading = false;
      });
    }
  }

  void _showGatePass(MemoKeluar m) {
    showDialog(
      context: context,
      builder: (_) => GatePassDialog(
        title: 'Gate Pass / Memo Keluar Digital',
        codeNumber: m.nomorMemo,
        nopol: formatPlate(m.noPolisi),
        driverName: m.namaPengemudi,
        customerName: m.namaPelanggan,
        spkNumber: m.nomorSpk,
        invoiceNumber: m.nomorInvoice,
        dateTime: m.waktuKeluar ?? DateTime.now(),
        isExit: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                color: AppTheme.surfaceWhite,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => _loadData(v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Cari Nopol atau No. Memo...',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.corporateNavy),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadData('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.refresh, color: AppTheme.corporateNavy),
                      onPressed: () => _loadData(_searchController.text.trim()),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.cardBorder),

              // List of Memos
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.corporateNavy))
                    : _memos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada kendaraan keluar hari ini.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadData(_searchController.text.trim()),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _memos.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final m = _memos[index];
                                final timeStr = m.waktuKeluar != null
                                    ? DateFormat('dd MMM, HH:mm').format(m.waktuKeluar!)
                                    : '-';

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceWhite,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.cardBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Row: Plate + Memo Badge
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.corporateNavy,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              formatPlate(m.noPolisi),
                                              style: GoogleFonts.chivo(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.backgroundLight,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.cardBorder),
                                            ),
                                            child: Text(
                                              m.nomorMemo,
                                              style: GoogleFonts.chivo(
                                                color: AppTheme.corporateNavy,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Driver & Info
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                                          const SizedBox(width: 6),
                                          Text(
                                            m.namaPengemudi ?? '-',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            timeStr,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      Text(
                                        'Pelanggan: ${m.namaPelanggan ?? '-'} • Petugas: ${m.petugasSecurityKeluar}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Actions
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.qr_code, size: 16),
                                          label: Text(
                                            'Lihat Gate Pass',
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.corporateNavy,
                                            side: const BorderSide(color: AppTheme.corporateNavy),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _showGatePass(m),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
