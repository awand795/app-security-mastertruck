// Preview / screenshot harness untuk Fase 2 (Login, App Shell, Beranda, Profil).
//
// Jalankan:
//   flutter test tool/preview/phase2_preview_test.dart --update-goldens
//
// File ini tidak berada di folder test/ sehingga tidak ikut `flutter test`.
import 'dart:convert';
import 'dart:io';

import 'package:bengkel_kim3_security_app/config/theme.dart';
import 'package:bengkel_kim3_security_app/models/active_vehicle_model.dart';
import 'package:bengkel_kim3_security_app/models/memo_keluar_model.dart';
import 'package:bengkel_kim3_security_app/services/auth_service.dart';
import 'package:bengkel_kim3_security_app/views/home_nav_view.dart';
import 'package:bengkel_kim3_security_app/views/login_view.dart';
import 'package:bengkel_kim3_security_app/widgets/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _goldenPath = '../../docs/revamp/fase-2';
final DateTime _now = DateTime(2026, 11, 9, 10, 30);

void main() {
  setUpAll(() async {
    Directory('docs/revamp/fase-2').createSync(recursive: true);
    await initializeDateFormatting('id_ID');
    GoogleFonts.config.allowRuntimeFetching = false;

    final separator = Platform.pathSeparator;
    final fontDir = 'assets${separator}fonts$separator';
    const pjs = 'PlusJakartaSans';
    await _loadLocalFont('${fontDir}PlusJakartaSans-Regular.ttf', [
      pjs,
      '${pjs}_regular',
    ]);
    await _loadLocalFont('${fontDir}PlusJakartaSans-Medium.ttf', [
      '${pjs}_500',
    ]);
    await _loadLocalFont('${fontDir}PlusJakartaSans-SemiBold.ttf', [
      '${pjs}_600',
    ]);
    await _loadLocalFont('${fontDir}PlusJakartaSans-Bold.ttf', [
      '${pjs}_700',
    ]);
    await _loadLocalFont('${fontDir}PlusJakartaSans-ExtraBold.ttf', [
      '${pjs}_800',
    ]);
    await _loadLocalFont('${fontDir}Chivo-Bold.ttf', ['Chivo', 'Chivo_700']);
    await _loadLocalFont('${fontDir}Chivo-ExtraBold.ttf', ['Chivo_800']);
    await _loadLocalFont('${fontDir}Chivo-Black.ttf', ['Chivo_900']);

    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && flutterRoot.isNotEmpty) {
      final iconFont = File(
        '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}'
        'cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}'
        'material_fonts${Platform.pathSeparator}materialicons-regular.otf',
      );
      if (iconFont.existsSync()) {
        final bytes = await iconFont.readAsBytes();
        final loader = FontLoader('MaterialIcons')
          ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
        await loader.load();
      }
    }

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'security_user_session': jsonEncode(
        UserSession(
          userId: 'SEC001',
          name: 'Bambang Sutrisno',
          role: 'SECURITY',
        ).toJson(),
      ),
    });
    await AuthService.loadSession();
  });

  testWidgets('phone light - login', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, const LoginView());
    await _capture(tester, 'phone_light_login.png');
  });

  testWidgets('phone dark - login', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, const LoginView());
    await _capture(tester, 'phone_dark_login.png');
  });

  testWidgets('tablet light - login', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.light,
      const LoginView(),
    );
    await _capture(tester, 'tablet_light_login.png');
  });

  testWidgets('tablet dark - login', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.dark,
      const LoginView(),
    );
    await _capture(tester, 'tablet_dark_login.png');
  });

  testWidgets('phone light - beranda', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await _capture(tester, 'phone_light_beranda.png');
  });

  testWidgets('phone dark - beranda', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await _capture(tester, 'phone_dark_beranda.png');
  });

  testWidgets('tablet light - beranda', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.light, _home());
    await _capture(tester, 'tablet_light_beranda.png');
  });

  testWidgets('tablet dark - beranda', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.dark, _home());
    await _capture(tester, 'tablet_dark_beranda.png');
  });

  testWidgets('phone light - profil', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await tester.tap(find.byType(InitialsAvatar).first);
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_light_profil.png');
  });

  testWidgets('phone dark - profil', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await tester.tap(find.byType(InitialsAvatar).first);
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_dark_profil.png');
  });

  testWidgets('tablet light - profil', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.light, _home());
    await tester.tap(find.byType(InitialsAvatar).first);
    await tester.pumpAndSettle();
    await _capture(tester, 'tablet_light_profil.png');
  });

  testWidgets('tablet dark - profil', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.dark, _home());
    await tester.tap(find.byType(InitialsAvatar).first);
    await tester.pumpAndSettle();
    await _capture(tester, 'tablet_dark_profil.png');
  });
}

Widget _home() {
  final now = _now;
  final active = [
    ActiveVehicle(
      id: 3,
      nomorTiket: 'TKT-1042',
      noPolisi: 'B 2156 TQR',
      namaPengemudi: 'Joko Santoso',
      tipeKunjungan: 'Service',
      statusInvoice: 'LUNAS',
      statusServis: 'Pengerjaan',
      waktuCheckIn: now.subtract(const Duration(hours: 2, minutes: 15)),
    ),
    ActiveVehicle(
      id: 2,
      nomorTiket: 'TKT-1041',
      noPolisi: 'D 8821 KIM',
      namaPengemudi: 'Agus Pratama',
      tipeKunjungan: 'Service',
      statusInvoice: 'Belum Lunas',
      statusServis: 'Pengerjaan',
      waktuCheckIn: now.subtract(const Duration(minutes: 48)),
    ),
    ActiveVehicle(
      id: 1,
      nomorTiket: 'TKT-1040',
      noPolisi: 'F 9012 TRK',
      namaPengemudi: 'Slamet Riyadi',
      tipeKunjungan: 'Booking',
      statusInvoice: 'Lunas',
      statusServis: 'Selesai',
      waktuCheckIn: now.subtract(const Duration(hours: 5, minutes: 10)),
    ),
  ];
  final exited = [
    MemoKeluar(
      id: 2,
      nomorMemo: 'MEMO-2026-002',
      noPolisi: 'D 7788 ABC',
      waktuKeluar: now.subtract(const Duration(minutes: 20)),
    ),
    MemoKeluar(
      id: 1,
      nomorMemo: 'MEMO-2026-001',
      noPolisi: 'B 1234 XYZ',
      waktuKeluar: now.subtract(const Duration(hours: 1)),
    ),
  ];

  return HomeNavView(
    dashboardLoader: () async => (active: active, exited: exited),
    clock: () => now,
  );
}

Future<void> _loadLocalFont(String path, List<String> families) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  for (final family in families) {
    final loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

Future<void> _pump(
  WidgetTester tester,
  Size logicalSize,
  Brightness brightness,
  Widget home,
) async {
  const double dpr = 2;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(
    logicalSize.width * dpr,
    logicalSize.height * dpr,
  );
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _PreviewApp(brightness: brightness, home: home),
  );
  await tester.pump(const Duration(milliseconds: 50));

  // Pastikan aset logo sudah ter-decode sebelum capture (terutama frame pertama).
  final imageContext = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/images/master-truck-logo-transparent.png'),
      imageContext,
    );
    await precacheImage(
      const AssetImage('assets/images/master-truck-logo.png'),
      imageContext,
    );
  });
  await tester.pump(const Duration(milliseconds: 50));

  await GoogleFonts.pendingFonts();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _capture(WidgetTester tester, String fileName) async {
  await expectLater(
    find.byType(_PreviewApp),
    matchesGoldenFile('$_goldenPath/$fileName'),
  );
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.brightness, required this.home});

  final Brightness brightness;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: home,
    );
  }
}
