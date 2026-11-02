import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import 'check_in_view.dart';
import 'active_inside_view.dart';
import 'check_out_view.dart';
import 'today_exit_view.dart';
import 'login_view.dart';

class HomeNavView extends StatefulWidget {
  const HomeNavView({Key? key}) : super(key: key);

  @override
  State<HomeNavView> createState() => _HomeNavViewState();
}

class _HomeNavViewState extends State<HomeNavView> {
  int _currentIndex = 0;
  String? _checkoutTargetPlate;

  void _navigateToCheckout(String plate) {
    setState(() {
      _checkoutTargetPlate = plate;
      _currentIndex = 2; // Index of Check-Out tab
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: AppTheme.errorRed, size: 22),
            const SizedBox(width: 8),
            Text('Konfirmasi Logout', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Keluar dari sesi petugas security pos gerbang?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Keluar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.currentSession;
    final officerName = session?.name ?? 'Petugas';

    final views = [
      const CheckInView(),
      ActiveInsideView(onNavigateToCheckout: _navigateToCheckout),
      CheckOutView(
        initialPlate: _checkoutTargetPlate,
        onClearInitialPlate: () => setState(() => _checkoutTargetPlate = null),
      ),
      const TodayExitView(),
    ];

    final titles = [
      'Pemeriksaan Masuk',
      'Kendaraan di Dalam',
      'Pemeriksaan Keluar',
      'Histori Keluar Hari Ini',
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: AppTheme.surfaceWhite,
        titleSpacing: 14,
        title: Row(
          children: [
            // Master Truck Official Logo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.corporateNavy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/master-truck-logo.png',
                height: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: AppTheme.amberGold, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'MasterTruck',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppTheme.corporateNavy,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.amberGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'KIM 3',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    titles[_currentIndex],
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Security Officer Badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: AppTheme.corporateNavy,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/avatar-bambang.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 12, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 75),
                  child: Text(
                    officerName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.corporateNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20, color: AppTheme.textSecondary),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: views,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: const Border(top: BorderSide(color: AppTheme.cardBorder, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          height: 64,
          elevation: 0,
          onDestinationSelected: (idx) {
            setState(() {
              _currentIndex = idx;
              if (idx != 2) _checkoutTargetPlate = null;
            });
          },
          backgroundColor: Colors.transparent,
          indicatorColor: AppTheme.corporateNavy.withOpacity(0.08),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.login_rounded, size: 22),
              selectedIcon: Icon(Icons.login_rounded, color: AppTheme.corporateNavy, size: 24),
              label: 'Check-In',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined, size: 22),
              selectedIcon: Icon(Icons.local_shipping_rounded, color: AppTheme.corporateNavy, size: 24),
              label: 'Di Dalam',
            ),
            NavigationDestination(
              icon: Icon(Icons.logout_rounded, size: 22),
              selectedIcon: Icon(Icons.logout_rounded, color: AppTheme.corporateNavy, size: 24),
              label: 'Check-Out',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, size: 22),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: AppTheme.corporateNavy, size: 24),
              label: 'Histori Keluar',
            ),
          ],
        ),
      ),
    );
  }
}
