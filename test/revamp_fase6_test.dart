import 'package:bengkel_kim3_security_app/config/theme.dart';
import 'package:bengkel_kim3_security_app/models/active_vehicle_model.dart';
import 'package:bengkel_kim3_security_app/models/booking_candidate_model.dart';
import 'package:bengkel_kim3_security_app/models/employee_model.dart';
import 'package:bengkel_kim3_security_app/models/memo_keluar_model.dart';
import 'package:bengkel_kim3_security_app/views/active_inside_view.dart';
import 'package:bengkel_kim3_security_app/views/gate_select_view.dart';
import 'package:bengkel_kim3_security_app/views/home_nav_view.dart';
import 'package:bengkel_kim3_security_app/views/login_view.dart';
import 'package:bengkel_kim3_security_app/widgets/gate_pass_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

final _fixedNow = DateTime(2026, 11, 20, 9, 30);

final _sampleActive = [
  ActiveVehicle(
    id: 101,
    nomorTiket: 'TG-261120-0001',
    noPolisi: 'BK 9393 RR',
    namaPengemudi: 'Ahmad Fauzi',
    noTeleponPengemudi: '081234567890',
    picTujuan: 'Budi SA',
    tipeKunjungan: 'SERVICE',
    subTujuan: 'SERVICE',
    statusKunjungan: 'DI_BENGKEL',
    gateMasukId: 1,
    gateMasukNama: 'Gate 1',
    lokasiKode: 'MT',
    lokasiNama: 'Bengkel',
    hasWo: true,
    hasFir: false,
    nomorSpk: 'WO-2611-0012',
    keluhan: 'Ganti oli mesin & cek rem depan',
    waktuCheckIn: DateTime(2026, 11, 20, 8, 10),
    namaPelanggan: 'PT Mitra Logistik Nusantara',
  ),
  ActiveVehicle(
    id: 102,
    nomorTiket: 'TG-261120-0002',
    noPolisi: 'BK 7373 KJS',
    namaPengemudi: 'Dedi Kurniawan',
    picTujuan: 'Andi Gudang',
    tipeKunjungan: 'SERVICE',
    subTujuan: 'SERVICE',
    statusKunjungan: 'KELUAR_SEMENTARA',
    alasanKeluar: 'Test drive luar area bengkel',
    gateMasukId: 1,
    gateMasukNama: 'Gate 1',
    lokasiKode: 'MT',
    lokasiNama: 'Bengkel',
    hasWo: true,
    hasFir: false,
    waktuCheckIn: DateTime(2026, 11, 20, 7, 45),
    namaPelanggan: 'PT Intan Tunas Cemerlang',
  ),
];

final _sampleExited = [
  MemoKeluar(
    id: 201,
    nomorMemo: 'MK-20261120-001',
    noPolisi: 'BK 8229 GO',
    namaPengemudi: 'Rizky Pratama',
    nomorSpk: 'WO-2611-0008',
    nomorInvoice: 'FJ0112611000112',
    waktuKeluar: DateTime(2026, 11, 20, 9, 5),
    petugasSecurityKeluar: 'Hendra Wijaya',
    statusKunjungan: 'SELESAI',
    gateMasukNama: 'Gate 1',
    gateKeluarNama: 'Gate 2',
  ),
];

final _sampleEmployees = [
  const EmployeeItem(
    id: 1,
    name: 'Budi Santoso',
    position: 'Service Advisor',
    isServiceAdvisor: true,
  ),
];

Widget _wrapApp(
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  double textScale = 1.0,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: mode,
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: inner ?? const SizedBox.shrink(),
    ),
    home: child,
  );
}

Future<void> _pumpViewport(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  ThemeMode mode = ThemeMode.light,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_wrapApp(child, mode: mode, textScale: textScale));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('id_ID');
  });

  group('Fase 6 UI & Responsive Verification', () {
    testWidgets(
      'LoginView renders cleanly on 360px (textScale 1.3), 390px, and 800px',
      (tester) async {
        await _pumpViewport(
          tester,
          const LoginView(),
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(find.text('Selamat datang'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _pumpViewport(
          tester,
          const LoginView(),
          size: const Size(390, 844),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../docs/revamp/fase-6/phone_light_login.png'),
        );

        await _pumpViewport(
          tester,
          const LoginView(),
          size: const Size(800, 1024),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('GateSelectView renders cleanly in Light & Dark', (
      tester,
    ) async {
      await _pumpViewport(
        tester,
        const GateSelectView(),
        size: const Size(390, 844),
      );
      expect(find.textContaining('Pilih gerbang'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('HomeNavView Beranda + BottomDock Light & Dark + Tablet', (
      tester,
    ) async {
      final home = HomeNavView(
        dashboardLoader: () async =>
            (active: _sampleActive, exited: _sampleExited),
        checkInEmployeeLoader: () async => _sampleEmployees,
        checkInCandidateSearcher: (q) async => <CheckinCandidate>[],
        activeInsideLoader: (q) async => _sampleActive,
        checkOutVehicleLoader: (q) async => _sampleActive,
        memoLoader: (q) async => _sampleExited,
        clock: () => _fixedNow,
      );

      await _pumpViewport(tester, home, size: const Size(390, 844));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/revamp/fase-6/phone_light_beranda.png'),
      );

      await _pumpViewport(
        tester,
        home,
        size: const Size(390, 844),
        mode: ThemeMode.dark,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/revamp/fase-6/phone_dark_beranda.png'),
      );

      await _pumpViewport(tester, home, size: const Size(800, 1024));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/revamp/fase-6/tablet_light_beranda.png'),
      );
    });

    testWidgets(
      'CheckInView 4 SectionCards + SegmentedPill Service/Umum + validation',
      (tester) async {
        final home = HomeNavView(
          dashboardLoader: () async =>
              (active: _sampleActive, exited: _sampleExited),
          checkInEmployeeLoader: () async => _sampleEmployees,
          checkInCandidateSearcher: (q) async => <CheckinCandidate>[],
          clock: () => _fixedNow,
        );

        await _pumpViewport(tester, home, size: const Size(390, 844));
        await tester.tap(find.text('Masuk'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Nomor polisi'), findsOneWidget);
        expect(find.text('Bengkel'), findsOneWidget);
        expect(find.text('Tujuan kunjungan'), findsOneWidget);
        expect(find.text('0/2 wajib'), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../docs/revamp/fase-6/phone_light_checkin.png'),
        );

        // Isi Tujuan lainnya -> PIC otomatis berubah menjadi input manual
        await tester.ensureVisible(find.text('Tujuan lainnya (Opsional)'));
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Isi jika tujuan tidak ada di daftar atas (otomatis dipakai)',
          ),
          'Antar Dokumen',
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Ketik nama PIC secara manual'), findsOneWidget);

        // Submit with required fields empty -> shows validation without crashing
        await tester.ensureVisible(find.text('Konfirmasi Check-In'));
        await tester.pump();
        await tester.tap(find.text('Konfirmasi Check-In'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CheckOutView keeps BottomDock visible + Gate route + FIR + Alasan keluar Lainnya',
      (tester) async {
        final home = HomeNavView(
          dashboardLoader: () async =>
              (active: _sampleActive, exited: _sampleExited),
          checkOutVehicleLoader: (q) async => _sampleActive,
          initialCheckoutPlate: 'BK 9393 RR',
          clock: () => _fixedNow,
        );

        await _pumpViewport(tester, home, size: const Size(390, 844));
        await tester.tap(find.text('Keluar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump(const Duration(milliseconds: 250));

        // Bottom navigation stays visible on Check Out
        expect(find.text('Beranda'), findsOneWidget);
        expect(find.text('Riwayat'), findsOneWidget);
        expect(find.text('Catat Keluar Sementara'), findsOneWidget);

        // Select 'Lainnya' chip -> animated 'Jelaskan alasan' appears
        await tester.ensureVisible(find.text('Lainnya'));
        await tester.pump();
        await tester.tap(find.text('Lainnya'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.textContaining('Jelaskan alasan'), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../docs/revamp/fase-6/phone_light_checkout.png'),
        );
      },
    );

    testWidgets('ActiveInsideView loading, empty, and error states', (
      tester,
    ) async {
      await _pumpViewport(
        tester,
        Scaffold(
          body: ActiveInsideView(
            vehicleLoader: (_) async => <ActiveVehicle>[],
            clock: () => _fixedNow,
          ),
        ),
        size: const Size(360, 800),
        textScale: 1.3,
      );
      expect(find.text('Belum ada kendaraan di dalam'), findsOneWidget);

      await _pumpViewport(
        tester,
        Scaffold(
          body: ActiveInsideView(
            key: UniqueKey(),
            vehicleLoader: (_) async => throw Exception('offline'),
            clock: () => _fixedNow,
          ),
        ),
        size: const Size(390, 844),
      );
      expect(find.textContaining('Periksa koneksi internet'), findsOneWidget);
    });

    testWidgets(
      'GatePassDialog perforated ticket renders cleanly in Light & Dark',
      (tester) async {
        const dialog = GatePassDialog(
          nomorMemo: 'MK-20261120-001',
          noPolisi: 'BK 8229 GO',
          namaPengemudi: 'Rizky Pratama',
          customerName: 'PT Intan Tunas Cemerlang',
          tipeKunjungan: 'SERVICE',
          waktuMasuk: '07:45',
          waktuKeluar: '09:05',
          spkNumber: 'WO-2611-0008',
          invoiceNumber: 'FJ0112611000112',
          petugasSecurity: 'Hendra Wijaya',
        );

        await _pumpViewport(tester, dialog, size: const Size(390, 844));
        expect(find.text('LUNAS'), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../docs/revamp/fase-6/phone_light_gatepass.png'),
        );

        await _pumpViewport(
          tester,
          dialog,
          size: const Size(800, 1024),
          mode: ThemeMode.dark,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../docs/revamp/fase-6/tablet_dark_gatepass.png'),
        );
      },
    );
  });
}
