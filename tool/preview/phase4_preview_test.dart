// Preview / screenshot harness untuk Fase 4 (Di Dalam, Riwayat, Pemindai Plat).
//
// Jalankan:
//   flutter test tool/preview/phase4_preview_test.dart --update-goldens
//
// File ini tidak berada di folder test/ sehingga tidak ikut `flutter test`.
import 'dart:convert';
import 'dart:io';

import 'package:bengkel_kim3_security_app/config/theme.dart';
import 'package:bengkel_kim3_security_app/models/active_vehicle_model.dart';
import 'package:bengkel_kim3_security_app/models/memo_keluar_model.dart';
import 'package:bengkel_kim3_security_app/services/auth_service.dart';
import 'package:bengkel_kim3_security_app/views/home_nav_view.dart';
import 'package:bengkel_kim3_security_app/widgets/anpr_scanner_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _goldenPath = '../../docs/revamp/fase-4';
final DateTime _now = DateTime(2026, 11, 9, 10, 30);

void main() {
  setUpAll(() async {
    Directory('docs/revamp/fase-4').createSync(recursive: true);
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
    await _loadLocalFont('${fontDir}PlusJakartaSans-Bold.ttf', ['${pjs}_700']);
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

  testWidgets('phone light - di dalam', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await _openTab(tester, 'Di Dalam');
    await _capture(tester, 'phone_light_inside.png');
  });

  testWidgets('phone dark - di dalam', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await _openTab(tester, 'Di Dalam');
    await _capture(tester, 'phone_dark_inside.png');
  });

  testWidgets('tablet light - di dalam', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.light, _home());
    await _openTab(tester, 'Di Dalam');
    await _capture(tester, 'tablet_light_inside.png');
  });

  testWidgets('tablet dark - di dalam', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.dark, _home());
    await _openTab(tester, 'Di Dalam');
    await _capture(tester, 'tablet_dark_inside.png');
  });

  testWidgets('phone light - di dalam filter siap keluar', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await _openTab(tester, 'Di Dalam');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Siap keluar'));
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_light_inside_filter_ready.png');
  });

  testWidgets('phone light - di dalam kosong', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      _home(activeInsideLoader: (_) async => const []),
    );
    await _openTab(tester, 'Di Dalam');
    await _capture(tester, 'phone_light_inside_empty.png');
  });

  testWidgets('phone light - di dalam error', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      _home(
        activeInsideLoader: (_) async =>
            throw StateError('Koneksi gagal untuk preview'),
      ),
    );
    await _openTab(tester, 'Di Dalam');
    await _capture(tester, 'phone_light_inside_error.png');
  });

  testWidgets('phone light - riwayat', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await _openTab(tester, 'Riwayat');
    await _capture(tester, 'phone_light_history.png');
  });

  testWidgets('phone dark - riwayat', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await _openTab(tester, 'Riwayat');
    await _capture(tester, 'phone_dark_history.png');
  });

  testWidgets('tablet light - riwayat', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.light, _home());
    await _openTab(tester, 'Riwayat');
    await _capture(tester, 'tablet_light_history.png');
  });

  testWidgets('tablet dark - riwayat', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.dark, _home());
    await _openTab(tester, 'Riwayat');
    await _capture(tester, 'tablet_dark_history.png');
  });

  testWidgets('phone dark - riwayat hari ini', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await _openTab(tester, 'Riwayat');
    await tester.tap(find.text('Hari ini').first);
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_dark_history_today.png');
  });

  testWidgets('phone light - pemindai plat', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      const _ScannerPreview(),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'phone_light_scanner.png');
  });

  testWidgets('phone dark - pemindai plat', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.dark,
      const _ScannerPreview(),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'phone_dark_scanner.png');
  });

  testWidgets('tablet light - pemindai plat', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.light,
      const _ScannerPreview(),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'tablet_light_scanner.png');
  });

  testWidgets('tablet dark - pemindai plat', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.dark,
      const _ScannerPreview(),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'tablet_dark_scanner.png');
  });
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Widget _home({
  Future<List<ActiveVehicle>> Function(String query)? activeInsideLoader,
  Future<List<MemoKeluar>> Function(String query)? memoLoader,
}) {
  final active = _activeVehicles();
  final exited = _memos();

  return HomeNavView(
    dashboardLoader: () async => (active: active, exited: exited),
    activeInsideLoader: activeInsideLoader ?? (_) async => active,
    memoLoader: memoLoader ?? (_) async => exited,
    clock: () => _now,
  );
}

List<ActiveVehicle> _activeVehicles() {
  return [
    ActiveVehicle(
      id: 3,
      nomorTiket: 'TKT-1042',
      noPolisi: 'B 2156 TQR',
      namaPengemudi: 'Joko Santoso',
      namaPelanggan: 'PT Sinar Jaya',
      tipeKunjungan: 'Service',
      keluhan: 'Ganti oli berkala dan periksa rem',
      statusInvoice: 'LUNAS',
      statusServis: 'Selesai',
      nomorSpk: 'SPK-2026-1042',
      nomorInvoice: 'INV-2026-1042',
      picTujuan: 'Budi Santoso',
      waktuCheckIn: _now.subtract(const Duration(hours: 2, minutes: 15)),
    ),
    ActiveVehicle(
      id: 2,
      nomorTiket: 'TKT-1041',
      noPolisi: 'D 8821 KIM',
      namaPengemudi: 'Agus Pratama',
      namaPelanggan: 'CV Karya Abadi',
      tipeKunjungan: 'Service',
      keluhan: 'Perbaikan sistem rem',
      statusInvoice: 'Belum Lunas',
      statusServis: 'Pengerjaan',
      nomorSpk: 'SPK-2026-1041',
      nomorInvoice: 'INV-2026-1041',
      picTujuan: 'Rina Wulandari',
      waktuCheckIn: _now.subtract(const Duration(minutes: 48)),
    ),
    ActiveVehicle(
      id: 1,
      nomorTiket: 'TKT-1040',
      noPolisi: 'F 9021 TRK',
      namaPengemudi: 'Slamet Riyadi',
      namaPelanggan: 'UD Maju Bersama',
      tipeKunjungan: 'Service',
      keluhan: 'Servis berkala 40.000 km',
      statusInvoice: 'LUNAS',
      statusServis: 'Selesai',
      nomorSpk: 'SPK-2026-1040',
      nomorInvoice: 'INV-2026-1040',
      picTujuan: 'Agus Setiawan',
      waktuCheckIn: _now.subtract(const Duration(hours: 1, minutes: 5)),
    ),
  ];
}

List<MemoKeluar> _memos() {
  return [
    MemoKeluar(
      id: 5,
      nomorMemo: 'MEMO-2026-005',
      noPolisi: 'D 7788 ABC',
      namaPengemudi: 'Hendra Wijaya',
      namaPelanggan: 'PT Cahaya Logistik',
      nomorSpk: 'SPK-2026-1035',
      nomorInvoice: 'INV-2026-1035',
      waktuKeluar: DateTime(2026, 11, 9, 9, 45),
      petugasSecurityKeluar: 'Bambang Sutrisno',
    ),
    MemoKeluar(
      id: 4,
      nomorMemo: 'MEMO-2026-004',
      noPolisi: 'B 9911 XYZ',
      namaPengemudi: 'Rudi Hartono',
      namaPelanggan: 'CV Sumber Makmur',
      nomorSpk: 'SPK-2026-1032',
      nomorInvoice: 'INV-2026-1032',
      waktuKeluar: DateTime(2026, 11, 9, 8, 15),
      petugasSecurityKeluar: 'Bambang Sutrisno',
    ),
    MemoKeluar(
      id: 3,
      nomorMemo: 'MEMO-2026-003',
      noPolisi: 'F 8123 TRK',
      namaPengemudi: 'Yusuf Maulana',
      namaPelanggan: 'UD Karya Tani',
      nomorSpk: 'SPK-2026-1028',
      nomorInvoice: 'INV-2026-1028',
      waktuKeluar: DateTime(2026, 11, 6, 15, 20),
      petugasSecurityKeluar: 'Dedi Kurniawan',
    ),
    MemoKeluar(
      id: 2,
      nomorMemo: 'MEMO-2026-002',
      noPolisi: 'B 7001 KIM',
      namaPengemudi: 'Anton Saputra',
      namaPelanggan: 'PT Nusantara Jaya',
      nomorSpk: 'SPK-2026-1021',
      nomorInvoice: 'INV-2026-1021',
      waktuKeluar: DateTime(2026, 10, 29, 11, 10),
      petugasSecurityKeluar: 'Dedi Kurniawan',
    ),
  ];
}

class _ScannerPreview extends StatefulWidget {
  const _ScannerPreview();

  @override
  State<_ScannerPreview> createState() => _ScannerPreviewState();
}

class _ScannerPreviewState extends State<_ScannerPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        builder: (_) =>
            AnprScannerSheet(autoStartCamera: false, onPlateDetected: (_) {}),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
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

  await tester.pumpWidget(_PreviewApp(brightness: brightness, home: home));
  await tester.pump(const Duration(milliseconds: 50));

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
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: home,
    );
  }
}
