import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/memo_keluar_model.dart';
import '../services/api_service.dart';
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
        nopol: m.noPolisi,
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
      body: Column(
        children: [
          // Search Header Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surfaceWhite,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => _loadData(v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Cari Nopol atau No. Memo...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadData('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                            Icon(Icons.history_outlined, size: 48, color: AppTheme.textMuted),
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
                                ? DateFormat('HH:mm WIB • dd MMM yyyy').format(m.waktuKeluar!)
                                : '-';

                            return InkWell(
                              onTap: () => _showGatePass(m),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
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
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AppTheme.navyDark,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            m.noPolisi,
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.corporateNavy.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            m.nomorMemo,
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppTheme.corporateNavy,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                                        const SizedBox(width: 6),
                                        Text(
                                          m.namaPengemudi ?? 'Pengemudi',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.check_circle, size: 14, color: AppTheme.successGreen),
                                            const SizedBox(width: 4),
                                            Text(
                                              timeStr,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.qr_code, size: 16, color: AppTheme.corporateBlue),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Lihat Gate Pass',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: AppTheme.corporateBlue,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
