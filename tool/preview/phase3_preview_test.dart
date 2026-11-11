// Preview / screenshot harness untuk Fase 3 (Check-in, Check-out, Gate Pass).
//
// Jalankan:
//   flutter test tool/preview/phase3_preview_test.dart --update-goldens
//
// File ini tidak berada di folder test/ sehingga tidak ikut `flutter test`.
import 'dart:convert';
import 'dart:io';

import 'package:bengkel_kim3_security_app/config/theme.dart';
import 'package:bengkel_kim3_security_app/models/active_vehicle_model.dart';
import 'package:bengkel_kim3_security_app/models/booking_candidate_model.dart';
import 'package:bengkel_kim3_security_app/models/employee_model.dart';
import 'package:bengkel_kim3_security_app/models/memo_keluar_model.dart';
import 'package:bengkel_kim3_security_app/services/auth_service.dart';
import 'package:bengkel_kim3_security_app/views/home_nav_view.dart';
import 'package:bengkel_kim3_security_app/widgets/app_widgets.dart';
import 'package:bengkel_kim3_security_app/widgets/gate_pass_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _goldenPath = '../../docs/revamp/fase-3';

const List<EmployeeItem> _employees = [
  EmployeeItem(id: 8, name: 'EDI', employeeId: '000008', position: 'Service Advisor', mobileNumber: '081325262773', isServiceAdvisor: true),
  EmployeeItem(id: 303, name: 'Fajar Rivaldi', employeeId: '000239', position: 'Service Advisor', mobileNumber: '086467378383', isServiceAdvisor: true),
  EmployeeItem(id: 302, name: 'Itadori Yuji', employeeId: '000238', position: 'Service Advisor', mobileNumber: '08727272727', isServiceAdvisor: true),
  EmployeeItem(id: 295, name: 'Hisar Mangapul Paidaon Tambunan', employeeId: '3', position: 'ADMIN', mobileNumber: '81375320851', isServiceAdvisor: false),
];

void main() {
  setUpAll(() async {
    Directory('docs/revamp/fase-3').createSync(recursive: true);
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

  testWidgets('phone light - check-in', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await _openCheckIn(tester);
    await _capture(tester, 'phone_light_checkin.png');
  });

  testWidgets('phone dark - check-in', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await _openCheckIn(tester);
    await _capture(tester, 'phone_dark_checkin.png');
  });

  testWidgets('phone light - check-in photos', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await _openCheckIn(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_light_checkin_photos.png');
  });

  testWidgets('phone dark - check-in photos', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await _openCheckIn(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_dark_checkin_photos.png');
  });

  testWidgets('tablet light - check-in', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.light, _home());
    await _openCheckIn(tester);
    await _capture(tester, 'tablet_light_checkin.png');
  });

  testWidgets('tablet dark - check-in', (tester) async {
    await _pump(tester, const Size(800, 1280), Brightness.dark, _home());
    await _openCheckIn(tester);
    await _capture(tester, 'tablet_dark_checkin.png');
  });

  testWidgets('phone light - check-in result', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.light, _home());
    await _openCheckIn(tester);
    await _searchBooking(tester);
    await _capture(tester, 'phone_light_checkin_result.png');
  });

  testWidgets('phone dark - check-in result', (tester) async {
    await _pump(tester, const Size(360, 800), Brightness.dark, _home());
    await _openCheckIn(tester);
    await _searchBooking(tester);
    await _capture(tester, 'phone_dark_checkin_result.png');
  });

  testWidgets('phone light - booking warning', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      _home(unconfirmedBooking: true),
    );
    await _openCheckIn(tester);
    await _searchBooking(tester);
    await _capture(tester, 'phone_light_booking_warning.png');
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
  });

  testWidgets('phone light - checkout', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      _home(initialCheckoutPlate: 'B 2156 TQR'),
    );
    await _openCheckout(tester);
    await _capture(tester, 'phone_light_checkout.png');
  });

  testWidgets('phone dark - checkout unpaid', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.dark,
      _home(initialCheckoutPlate: 'D 8821 KIM'),
    );
    await _openCheckout(tester);
    await _capture(tester, 'phone_dark_checkout.png');
  });

  testWidgets('phone dark - unpaid warning', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.dark,
      _home(initialCheckoutPlate: 'D 8821 KIM'),
    );
    await _openCheckout(tester);
    await tester.tap(find.text('Konfirmasi Check-Out'));
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_dark_unpaid_warning.png');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });

  testWidgets('tablet light - checkout', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.light,
      _home(initialCheckoutPlate: 'B 2156 TQR'),
    );
    await _openCheckout(tester);
    await _capture(tester, 'tablet_light_checkout.png');
  });

  testWidgets('tablet dark - checkout unpaid', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.dark,
      _home(initialCheckoutPlate: 'D 8821 KIM'),
    );
    await _openCheckout(tester);
    await _capture(tester, 'tablet_dark_checkout.png');
  });

  testWidgets('phone light - checkout photos', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      _home(initialCheckoutPlate: 'B 2156 TQR'),
    );
    await _openCheckout(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_light_checkout_photos.png');
  });

  testWidgets('phone dark - checkout photos', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.dark,
      _home(initialCheckoutPlate: 'D 8821 KIM'),
    );
    await _openCheckout(tester);
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await _capture(tester, 'phone_dark_checkout_photos.png');
  });

  testWidgets('phone light - gate pass masuk', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      const _ReceiptPreview(isExit: false),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'phone_light_gatepass_masuk.png');
  });

  testWidgets('phone dark - gate pass masuk', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.dark,
      const _ReceiptPreview(isExit: false),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'phone_dark_gatepass_masuk.png');
  });

  testWidgets('tablet light - gate pass masuk', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.light,
      const _ReceiptPreview(isExit: false),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'tablet_light_gatepass_masuk.png');
  });

  testWidgets('tablet dark - gate pass masuk', (tester) async {
    await _pump(
      tester,
      const Size(800, 1280),
      Brightness.dark,
      const _ReceiptPreview(isExit: false),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'tablet_dark_gatepass_masuk.png');
  });

  testWidgets('phone light - gate pass keluar', (tester) async {
    await _pump(
      tester,
      const Size(360, 800),
      Brightness.light,
      const _ReceiptPreview(isExit: true),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await _capture(tester, 'phone_light_gatepass_keluar.png');
  });
}

Future<void> _openCheckIn(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Masuk'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCheckout(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Keluar'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _searchBooking(WidgetTester tester) async {
  final plateField = find.descendant(
    of: find.byType(PlateInput),
    matching: find.byType(TextField),
  );
  await tester.enterText(plateField, 'B 2156 TQR');
  await tester.tap(find.text('Cek Data'));
  await tester.pumpAndSettle();
}

Widget _home({String? initialCheckoutPlate, bool unconfirmedBooking = false}) {
  final now = DateTime(2026, 11, 6, 10, 30);
  final active = [
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
      waktuCheckIn: now.subtract(const Duration(hours: 2, minutes: 15)),
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
      waktuCheckIn: now.subtract(const Duration(minutes: 48)),
    ),
  ];
  final exited = [
    MemoKeluar(
      id: 2,
      nomorMemo: 'MEMO-2026-002',
      noPolisi: 'D 7788 ABC',
      waktuKeluar: now.subtract(const Duration(minutes: 20)),
    ),
  ];

  return HomeNavView(
    dashboardLoader: () async => (active: active, exited: exited),
    checkInEmployeeLoader: () async => _employees,
    checkInCandidateSearcher: (query) async => [
      _bookingCandidate(confirmed: !unconfirmedBooking),
    ],
    checkOutVehicleLoader: (query) async => active,
    initialCheckoutPlate: initialCheckoutPlate,
    clock: () => now,
  );
}

CheckinCandidate _bookingCandidate({bool confirmed = true}) {
  return CheckinCandidate(
    source: 'BOOKING',
    bookingId: 77,
    noBooking: 'BK-2026-001',
    noPolisi: 'B 2156 TQR',
    noPolisiClean: 'B2156TQR',
    customerName: 'PT Sinar Jaya',
    customerTelepon: '081234567890',
    jenisLayanan: 'Service Berkala',
    keluhan: 'Ganti oli berkala',
    tanggalBooking: '06 Nov 2026',
    jamBooking: '08:00',
    statusBooking: confirmed ? 'Terkonfirmasi' : 'Menunggu Konfirmasi',
    isConfirmed: confirmed,
    canCheckin: true,
    isWithinWindow: true,
  );
}

class _ReceiptPreview extends StatefulWidget {
  const _ReceiptPreview({required this.isExit});

  final bool isExit;

  @override
  State<_ReceiptPreview> createState() => _ReceiptPreviewState();
}

class _ReceiptPreviewState extends State<_ReceiptPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => GatePassDialog(
          nomorTiket: widget.isExit ? 'TKT-1042' : 'TKT-1043',
          nomorMemo: widget.isExit ? 'MEMO-2026-002' : null,
          noPolisi: 'B 2156 TQR',
          namaPengemudi: 'Joko Santoso',
          customerName: 'PT Sinar Jaya',
          tipeKunjungan: 'Service',
          keluhan: 'Ganti oli berkala dan periksa rem',
          waktuMasuk: '08:15',
          waktuKeluar: widget.isExit ? '10:30' : null,
          spkNumber: widget.isExit ? 'SPK-2026-1042' : null,
          invoiceNumber: widget.isExit ? 'INV-2026-1042' : null,
          petugasSecurity: 'Bambang Sutrisno',
          dateTime: widget.isExit
              ? DateTime(2026, 11, 6, 10, 30)
              : DateTime(2026, 11, 6, 8, 15),
          onClose: () {},
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
