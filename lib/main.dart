import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/theme.dart';
import 'services/auth_service.dart';
import 'views/home_nav_view.dart';
import 'views/login_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Semua bobot font yang dipakai sudah dibundel di assets/fonts.
  GoogleFonts.config.allowRuntimeFetching = false;
  await initializeDateFormatting('id_ID');
  await AuthService.loadSession();
  runApp(const SecurityMasterTruckApp());
}

class SecurityMasterTruckApp extends StatelessWidget {
  const SecurityMasterTruckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MasterTruck Security',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      themeAnimationDuration: AppDurations.normal,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlayStyle(
            Theme.of(context).brightness,
            Theme.of(context).colorScheme,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AuthService.isAuthenticated ? const HomeNavView() : const LoginView(),
    );
  }
}
