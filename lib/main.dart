import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'views/login_view.dart';
import 'views/home_nav_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surfaceWhite,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Load persistent user session
  await AuthService.loadSession();

  runApp(const SecurityMasterTruckApp());
}

class SecurityMasterTruckApp extends StatelessWidget {
  const SecurityMasterTruckApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MasterTruck Security',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthService.isAuthenticated ? const HomeNavView() : const LoginView(),
    );
  }
}
