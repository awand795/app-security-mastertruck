import 'package:bengkel_kim3_security_app/config/theme.dart';
import 'package:bengkel_kim3_security_app/models/active_vehicle_model.dart';
import 'package:bengkel_kim3_security_app/models/lokasi_model.dart';
import 'package:bengkel_kim3_security_app/models/tujuan_kedatangan_model.dart';
import 'package:bengkel_kim3_security_app/services/auth_service.dart';
import 'package:bengkel_kim3_security_app/views/check_in_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _pumpCheckIn(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: CheckInView(
          employeeLoader: () async => const [],
          candidateSearcher: (_) async => const [],
          lokasiLoader: () async => const [
            LokasiItem(id: 1, kodeLokasi: 'MT', namaLokasi: 'Bengkel'),
            LokasiItem(id: 2, kodeLokasi: 'G1', namaLokasi: 'Gudang 1'),
            LokasiItem(id: 3, kodeLokasi: 'G2', namaLokasi: 'Gudang 2'),
          ],
          tujuanLoader: () async => const [
            TujuanKedatanganItem(
              id: 1,
              kodeTujuan: 'SERVICE',
              namaTujuan: 'Service',
              urutan: 1,
            ),
            TujuanKedatanganItem(
              id: 2,
              kodeTujuan: 'KUNJUNGAN',
              namaTujuan: 'Kunjungan',
              urutan: 2,
            ),
            TujuanKedatanganItem(
              id: 3,
              kodeTujuan: 'BELI_SPAREPART',
              namaTujuan: 'Beli Sparepart',
              urutan: 3,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'Lokasi tampil, Tujuan dinamis + Tujuan lainnya, Keperluan & Catatan selalu opsional',
    (tester) async {
      await _pumpCheckIn(tester);

      // Lokasi tampil di bawah scan plat tanpa kode lokasi
      expect(find.text('Bengkel'), findsOneWidget);
      expect(find.text('Gudang 1'), findsOneWidget);
      expect(find.text('Gudang 2'), findsOneWidget);
      expect(find.text('Bengkel (MT)'), findsNothing);

      // Tujuan kedatangan dari tabel + Tujuan lainnya terpisah + Keperluan/Catatan opsional
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Kunjungan'), findsOneWidget);
      expect(find.text('Beli Sparepart'), findsOneWidget);
      expect(find.text('Tujuan lainnya (Opsional)'), findsOneWidget);
      expect(find.text('Keperluan (Opsional)'), findsOneWidget);
      expect(find.text('Catatan (Opsional)'), findsOneWidget);

      // Isi Tujuan lainnya -> PIC otomatis berubah ke input manual wajib
      await tester.ensureVisible(find.text('Tujuan lainnya (Opsional)'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Isi jika tujuan tidak ada di daftar atas (otomatis dipakai)',
        ),
        'Bongkar Barang',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ketik nama PIC secara manual'), findsOneWidget);
    },
  );

  test('Aturan lokasi MT vs non-MT dan masa sesi 2 hari', () {
    final vehicle = ActiveVehicle(
      id: 1,
      noPolisi: 'BK 9393 RR',
      lokasiKode: 'MT',
      hasWo: true,
      hasFir: false,
    );

    expect(vehicle.willBeKeluarSementaraFor('MT'), isTrue);
    expect(vehicle.requiresExitReasonFor('MT'), isTrue);
    expect(vehicle.willBeKeluarSementaraFor('G1'), isFalse);
    expect(vehicle.requiresExitReasonFor('G1'), isFalse);
    expect(AuthService.sessionMaxAge, const Duration(days: 2));
  });
}
