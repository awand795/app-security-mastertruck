import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/active_vehicle_model.dart';
import '../services/api_service.dart';

class ActiveInsideView extends StatefulWidget {
  final Function(String plate)? onNavigateToCheckout;

  const ActiveInsideView({Key? key, this.onNavigateToCheckout}) : super(key: key);

  @override
  State<ActiveInsideView> createState() => _ActiveInsideViewState();
}

class _ActiveInsideViewState extends State<ActiveInsideView> {
  final _searchController = TextEditingController();
  List<ActiveVehicle> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData([String q = '']) async {
    setState(() => _isLoading = true);
    final data = await ApiService.getActiveInside(query: q);
    if (mounted) {
      setState(() {
        _vehicles = data;
        _isLoading = false;
      });
    }
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
                      hintText: 'Cari Nopol, Pengemudi, atau SPK...',
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

          // Vehicle List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.corporateNavy))
                : _vehicles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_filled_outlined, size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada kendaraan di dalam bengkel.',
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
                          itemCount: _vehicles.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final v = _vehicles[index];
                            final timeStr = v.waktuCheckIn != null
                                ? DateFormat('dd MMM, HH:mm').format(v.waktuCheckIn!)
                                : '-';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: v.isSiapKeluar ? AppTheme.successGreen : AppTheme.cardBorder,
                                  width: v.isSiapKeluar ? 1.5 : 1,
                                ),
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
                                  // Top Row: Plate + Siap Keluar Badge
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
                                          v.noPolisi,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                      if (v.isSiapKeluar)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.successLight,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                'SIAP CHECKOUT',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: AppTheme.successGreen,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.amberLight,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            v.statusServis ?? 'PENGERJAAN',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppTheme.amberGold,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Driver & Complaint info
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16, color: AppTheme.textMuted),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${v.namaPengemudi ?? 'Pengemudi'} (${v.noTeleponPengemudi ?? '-'})',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (v.keluhan != null && v.keluhan!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.build_outlined, size: 16, color: AppTheme.textMuted),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            v.keluhan!,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),

                                  // Footer: Check-in Time & Action Button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Masuk: $timeStr',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (v.isSiapKeluar && widget.onNavigateToCheckout != null)
                                        TextButton.icon(
                                          onPressed: () => widget.onNavigateToCheckout!(v.noPolisi),
                                          icon: const Icon(Icons.exit_to_app, size: 16, color: AppTheme.corporateNavy),
                                          label: Text(
                                            'Checkout',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppTheme.corporateNavy,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            backgroundColor: AppTheme.backgroundLight,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                    ],
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
    );
  }
}
