import 'dart:async';

import 'package:bengkel_kim3_security_app/config/theme.dart';
import 'package:bengkel_kim3_security_app/models/active_vehicle_model.dart';
import 'package:bengkel_kim3_security_app/views/check_out_view.dart';
import 'package:bengkel_kim3_security_app/widgets/app_button.dart';
import 'package:bengkel_kim3_security_app/widgets/app_text_field.dart';
import 'package:bengkel_kim3_security_app/widgets/plate_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Service + WO + FIR belum terbit -> alasan keluar wajib (Keluar Sementara).
final _requiredVehicle = ActiveVehicle(
  id: 101,
  nomorTiket: 'TG-261120-0001',
  noPolisi: 'BK 9393 RR',
  namaPengemudi: 'Ahmad Fauzi',
  tipeKunjungan: 'SERVICE',
  subTujuan: 'SERVICE',
  statusKunjungan: 'DI_BENGKEL',
  gateMasukId: 1,
  gateMasukNama: 'Gate 1',
  hasWo: true,
  hasFir: false,
  nomorSpk: 'WO-2611-0012',
  waktuCheckIn: DateTime(2026, 11, 20, 8, 10),
  namaPelanggan: 'PT Mitra Logistik Nusantara',
);

/// Service + WO + FIR sudah terbit -> alasan keluar opsional.
final _optionalVehicle = ActiveVehicle(
  id: 102,
  nomorTiket: 'TG-261120-0002',
  noPolisi: 'BK 7373 KJS',
  namaPengemudi: 'Dedi Kurniawan',
  tipeKunjungan: 'SERVICE',
  subTujuan: 'SERVICE',
  statusKunjungan: 'DI_BENGKEL',
  gateMasukId: 1,
  gateMasukNama: 'Gate 1',
  hasWo: true,
  hasFir: true,
  nomorSpk: 'WO-2611-0013',
  waktuCheckIn: DateTime(2026, 11, 20, 7, 45),
  namaPelanggan: 'PT Intan Tunas Cemerlang',
);

Future<void> _pumpCheckOut(
  WidgetTester tester,
  List<ActiveVehicle> vehicles, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  Future<List<ActiveVehicle>> Function(String query)? loader,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: Scaffold(
        body: CheckOutView(
          key: UniqueKey(),
          vehicleLoader: loader ?? (_) async => vehicles,
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _notesField => find.descendant(
  of: find.widgetWithText(AppTextField, 'Catatan keluar'),
  matching: find.byType(TextField),
);

Finder get _plateField => find.descendant(
  of: find.byType(PlateInput),
  matching: find.byType(TextField),
);

Future<void> _enterPlate(WidgetTester tester, String plate) async {
  await tester.enterText(_plateField, plate);
  await tester.pump();
}

Future<void> _tapCariUnit(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(AppButton, 'Cari Unit'));
  await tester.pump();
  await tester.tap(find.widgetWithText(AppButton, 'Cari Unit'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('semua section 1-4 tampil sejak halaman dibuka', (tester) async {
    await _pumpCheckOut(tester, const []);

    expect(find.text('Nomor polisi'), findsOneWidget);
    expect(find.text('Data kendaraan'), findsOneWidget);
    expect(find.text('Alasan keluar'), findsOneWidget);
    expect(find.text('Catatan & Foto keluar'), findsOneWidget);

    // Section 2 memakai placeholder, bukan kosong.
    expect(find.text('Data kendaraan belum dimuat'), findsOneWidget);
    expect(
      find.text(
        'Cari atau scan plat untuk menampilkan data gate, FIR, dan invoice.',
      ),
      findsOneWidget,
    );

    // Section 3 & 4 tidak lagi menunggu kendaraan ditemukan.
    expect(find.text('Opsional'), findsOneWidget);
    expect(
      find.text('Wajib untuk Keluar Sementara atau kunjungan non-service'),
      findsOneWidget,
    );
    expect(find.text('Selesai kunjungan'), findsOneWidget);
    expect(find.text('Lainnya'), findsOneWidget);
    expect(find.text('Kosongkan isian'), findsNothing);
    expect(find.text('0/2 wajib'), findsOneWidget);
  });

  testWidgets('CTA disabled dan hint tampil sebelum kendaraan ditemukan', (
    tester,
  ) async {
    await _pumpCheckOut(tester, [_requiredVehicle]);

    final cta = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Konfirmasi Check-Out'),
    );
    expect(cta.onPressed, isNull);
    expect(find.text('Cari kendaraan terlebih dahulu.'), findsOneWidget);
  });

  testWidgets('mengubah plat tidak menghapus catatan dan alasan terisi', (
    tester,
  ) async {
    await _pumpCheckOut(tester, [_requiredVehicle]);

    await _enterPlate(tester, 'BK 9393 RR');
    await _tapCariUnit(tester);
    expect(find.text('BK 9393 RR'), findsWidgets);

    await tester.enterText(_notesField, 'Bumper belakang lecet');
    await tester.pump();

    await tester.ensureVisible(find.text('Selesai kunjungan'));
    await tester.pump();
    await tester.tap(find.text('Selesai kunjungan'));
    await tester.pumpAndSettle();

    final selectedChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Selesai kunjungan'),
    );
    expect(selectedChip.selected, isTrue);

    // Ganti plat -> data kendaraan direset, isian tetap.
    await _enterPlate(tester, 'BK 1111 AA');

    expect(find.text('Bumper belakang lecet'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Selesai kunjungan'),
          )
          .selected,
      isTrue,
    );
    expect(find.text('Data kendaraan belum dimuat'), findsOneWidget);
  });

  testWidgets(
    'badge alasan berubah Opsional -> Wajib setelah kendaraan dicari',
    (tester) async {
      await _pumpCheckOut(tester, [_requiredVehicle]);

      expect(find.text('Opsional'), findsOneWidget);
      expect(find.text('Wajib'), findsNothing);

      await _enterPlate(tester, 'BK 9393 RR');
      await _tapCariUnit(tester);

      expect(find.text('Opsional'), findsNothing);
      expect(find.text('Wajib'), findsOneWidget);

      // Unit dengan FIR terbit tetap Opsional walau sudah ditemukan.
      await _pumpCheckOut(tester, [_optionalVehicle]);
      await _enterPlate(tester, 'BK 7373 KJS');
      await _tapCariUnit(tester);

      expect(find.text('Wajib'), findsNothing);
      expect(find.text('Opsional'), findsOneWidget);
      expect(find.text('Tidak wajib untuk unit ini'), findsOneWidget);
    },
  );

  testWidgets('Lainnya memunculkan field dan validasi wajib saat submit', (
    tester,
  ) async {
    await _pumpCheckOut(tester, [_requiredVehicle]);

    await _enterPlate(tester, 'BK 9393 RR');
    await _tapCariUnit(tester);
    expect(find.text('Wajib'), findsOneWidget);

    await tester.ensureVisible(find.text('Lainnya'));
    await tester.pump();
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jelaskan alasan'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Catat Keluar Sementara'));
    await tester.pumpAndSettle();

    expect(find.text('Jelaskan alasan keluar.'), findsOneWidget);
    expect(
      find.text('FIR belum terbit. Pilih atau isi alasan keluar sementara.'),
      findsOneWidget,
    );
  });

  testWidgets('skeleton tampil selagi data kendaraan dicari', (tester) async {
    final completer = Completer<List<ActiveVehicle>>();
    await _pumpCheckOut(tester, const [], loader: (_) => completer.future);

    await _enterPlate(tester, 'BK 9393 RR');
    await tester.tap(find.widgetWithText(AppButton, 'Cari Unit'));
    await tester.pump();
    // Beri waktu transisi AnimatedSwitcher menyelesaikan placeholder.
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Data kendaraan belum dimuat'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Memuat data kendaraan',
      ),
      findsOneWidget,
    );

    completer.complete([_requiredVehicle]);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Memuat data kendaraan',
      ),
      findsNothing,
    );
    expect(find.text('Wajib'), findsOneWidget);
  });

  testWidgets('layout aman di 360, 390, dan tablet 800 (light & dark)', (
    tester,
  ) async {
    for (final size in const [
      Size(360, 800),
      Size(390, 844),
      Size(800, 1024),
    ]) {
      for (final brightness in Brightness.values) {
        await _pumpCheckOut(
          tester,
          [_requiredVehicle],
          size: size,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);

        await _enterPlate(tester, 'BK 9393 RR');
        await _tapCariUnit(tester);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('tombol Kosongkan isian muncul dan mengosongkan form', (
    tester,
  ) async {
    await _pumpCheckOut(tester, [_requiredVehicle]);

    await _enterPlate(tester, 'BK 9393 RR');
    await _tapCariUnit(tester);

    expect(find.text('Kosongkan isian'), findsNothing);

    await tester.enterText(_notesField, 'Catatan sementara');
    await tester.pump();
    expect(find.text('Kosongkan isian'), findsOneWidget);

    await tester.ensureVisible(find.text('Kosongkan isian'));
    await tester.pump();
    await tester.tap(find.text('Kosongkan isian'));
    await tester.pumpAndSettle();

    expect(find.text('Catatan sementara'), findsNothing);
    expect(find.text('Kosongkan isian'), findsNothing);
    // Data kendaraan tidak ikut dihapus.
    expect(find.text('Data kendaraan belum dimuat'), findsNothing);
  });
}
