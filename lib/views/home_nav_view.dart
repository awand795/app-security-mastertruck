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
        title: Text('Konfirmasi Logout', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Keluar dari sesi petugas security?', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
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
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.corporateNavy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: AppTheme.amberGold, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_currentIndex],
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'MASTER TRUCK GATE',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: AppTheme.amberGold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, size: 14, color: AppTheme.corporateNavy),
                const SizedBox(width: 5),
                Text(
                  officerName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.corporateNavy,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: AppTheme.errorRed),
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
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) {
            setState(() {
              _currentIndex = idx;
              if (idx != 2) _checkoutTargetPlate = null;
            });
          },
          backgroundColor: Colors.transparent,
          indicatorColor: AppTheme.corporateNavy.withOpacity(0.1),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.login_outlined),
              selectedIcon: Icon(Icons.login, color: AppTheme.corporateNavy),
              label: 'Check-In',
            ),
            NavigationDestination(
              icon: Icon(Icons.garage_outlined),
              selectedIcon: Icon(Icons.garage, color: AppTheme.corporateNavy),
              label: 'Di Dalam',
            ),
            NavigationDestination(
              icon: Icon(Icons.exit_to_app_outlined),
              selectedIcon: Icon(Icons.exit_to_app, color: AppTheme.corporateNavy),
              label: 'Check-Out',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: AppTheme.corporateNavy),
              label: 'Hari Ini',
            ),
          ],
        ),
      ),
    );
  }
}
