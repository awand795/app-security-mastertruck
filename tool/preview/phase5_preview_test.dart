// Preview / screenshot harness untuk Fase 5 (hardening & final polish).
//
// Jalankan:
//   flutter test tool/preview/phase5_preview_test.dart --update-goldens
//
// File ini tidak berada di folder test/ sehingga tidak ikut `flutter test`.
import 'dart:convert';
import 'dart:io';

import 'package:bengkel_kim3_security_app/config/theme.dart';
import 'package:bengkel_kim3_security_app/models/active_vehicle_model.dart';
import 'package:bengkel_kim3_security_app/models/employee_model.dart';
import 'package:bengkel_kim3_security_app/models/memo_keluar_model.dart';
import 'package:bengkel_kim3_security_app/services/auth_service.dart';
import 'package:bengkel_kim3_security_app/views/home_nav_view.dart';
import 'package:bengkel_kim3_security_app/widgets/gate_pass_dialog.dart';
import 'package:bengkel_kim3_security_app/widgets/profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _goldenPath = '../../docs/revamp/fase-5';
final DateTime _now = DateTime(2026, 11, 10, 10, 30);

void main() {
  setUpAll(() async {
    Directory('docs/revamp/fase-5').createSync(recursive: true);
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
          namaCabang: 'Bengkel Master Truck KIM 3',
        ).toJson(),
      ),
    });
    await AuthService.loadSession();
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

  testWidgets('phone light - check-in', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await _openTab(tester, 'Masuk');
    await _capture(tester, 'phone_light_checkin.png');
  });

  testWidgets('phone dark - check-in', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await _openTab(tester, 'Masuk');
    await _capture(tester, 'phone_dark_checkin.png');
  });

  testWidgets('tablet light - check-in', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.light, _home());
    await _openTab(tester, 'Masuk');
    await _capture(tester, 'tablet_light_checkin.png');
  });

  testWidgets('tablet dark - check-in', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.dark, _home());
    await _openTab(tester, 'Masuk');
    await _capture(tester, 'tablet_dark_checkin.png');
  });

  testWidgets('phone light - checkout', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      _home(initialCheckoutPlate: 'B 2156 TQR'),
    );
    await _openTab(tester, 'Keluar');
    await _capture(tester, 'phone_light_checkout.png');
  });

  testWidgets('phone dark - checkout', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.dark,
      _home(initialCheckoutPlate: 'B 2156 TQR'),
    );
    await _openTab(tester, 'Keluar');
    await _capture(tester, 'phone_dark_checkout.png');
  });

  testWidgets('tablet light - checkout', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.light,
      _home(initialCheckoutPlate: 'B 2156 TQR'),
    );
    await _openTab(tester, 'Keluar');
    await _capture(tester, 'tablet_light_checkout.png');
  });

  testWidgets('tablet dark - checkout', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.dark,
      _home(initialCheckoutPlate: 'B 2156 TQR'),
    );
    await _openTab(tester, 'Keluar');
    await _capture(tester, 'tablet_dark_checkout.png');
  });

  testWidgets('phone light - checkout tidak cocok', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      _home(initialCheckoutPlate: 'B 9999 XXX'),
    );
    await _openTab(tester, 'Keluar');
    await _capture(tester, 'phone_light_checkout_not_found.png');
  });

  testWidgets('phone light - gate pass', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      const _GatePassPreview(),
    );
    await _capture(tester, 'phone_light_gatepass.png');
  });

  testWidgets('phone dark - gate pass', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.dark,
      const _GatePassPreview(),
    );
    await _capture(tester, 'phone_dark_gatepass.png');
  });

  testWidgets('tablet light - gate pass', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.light,
      const _GatePassPreview(),
    );
    await _capture(tester, 'tablet_light_gatepass.png');
  });

  testWidgets('tablet dark - gate pass', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.dark,
      const _GatePassPreview(),
    );
    await _capture(tester, 'tablet_dark_gatepass.png');
  });

  testWidgets('phone light - gate pass dengan peringatan foto', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      const _GatePassPreview(uploadWarning: true),
    );
    await _capture(tester, 'phone_light_gatepass_warning.png');
  });

  testWidgets('phone light - profil', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      const _ProfilePreview(),
    );
    await _capture(tester, 'phone_light_profile.png');
  });

  testWidgets('phone dark - profil', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.dark,
      const _ProfilePreview(),
    );
    await _capture(tester, 'phone_dark_profile.png');
  });
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Widget _home({String? initialCheckoutPlate}) {
  final active = _activeVehicles();
  final exited = _memos();

  return HomeNavView(
    dashboardLoader: () async => (active: active, exited: exited),
    checkInEmployeeLoader: () async => _employees,
    checkOutVehicleLoader: (_) async => active,
    activeInsideLoader: (_) async => active,
    memoLoader: (_) async => exited,
    initialCheckoutPlate: initialCheckoutPlate,
    clock: () => _now,
  );
}

const List<EmployeeItem> _employees = [
  EmployeeItem(id: 8, name: 'EDI', employeeId: '000008', position: 'Service Advisor', mobileNumber: '081325262773', isServiceAdvisor: true),
  EmployeeItem(id: 303, name: 'Fajar Rivaldi', employeeId: '000239', position: 'Service Advisor', mobileNumber: '086467378383', isServiceAdvisor: true),
  EmployeeItem(id: 302, name: 'Itadori Yuji', employeeId: '000238', position: 'Service Advisor', mobileNumber: '08727272727', isServiceAdvisor: true),
  EmployeeItem(id: 295, name: 'Hisar Mangapul Paidaon Tambunan', employeeId: '3', position: 'ADMIN', mobileNumber: '81375320851', isServiceAdvisor: false),
];

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
      picTujuan: 'EDI',
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
      waktuKeluar: DateTime(2026, 11, 10, 9, 45),
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
      waktuKeluar: DateTime(2026, 11, 10, 8, 15),
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
      waktuKeluar: DateTime(2026, 11, 7, 15, 20),
      petugasSecurityKeluar: 'Dedi Kurniawan',
    ),
  ];
}

class _GatePassPreview extends StatefulWidget {
  const _GatePassPreview({this.uploadWarning = false});

  final bool uploadWarning;

  @override
  State<_GatePassPreview> createState() => _GatePassPreviewState();
}

class _GatePassPreviewState extends State<_GatePassPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => GatePassDialog(
          title: 'Gate Pass / Memo Keluar Digital',
          codeNumber: 'MEMO-2026-005',
          nopol: 'D 7788 ABC',
          driverName: 'Hendra Wijaya',
          customerName: 'PT Cahaya Logistik',
          spkNumber: 'SPK-2026-1035',
          invoiceNumber: 'INV-2026-1035',
          dateTime: _now,
          isExit: true,
          uploadWarning: widget.uploadWarning
              ? '1 dari 4 foto gagal diunggah. Data check-out tetap tersimpan, '
                    'tetapi foto keluar belum lengkap.'
              : null,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}

class _ProfilePreview extends StatefulWidget {
  const _ProfilePreview();

  @override
  State<_ProfilePreview> createState() => _ProfilePreviewState();
}

class _ProfilePreviewState extends State<_ProfilePreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ProfileSheet(
          session: AuthService.currentSession,
          onLogout: () {},
        ),
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
  await tester.pumpAndSettle();
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
