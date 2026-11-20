import 'package:geolocator/geolocator.dart';

import '../models/lokasi_model.dart';

class LocationCheckResult {
  final bool allowed;
  final String? message;
  final double? distanceMeters;

  const LocationCheckResult({
    required this.allowed,
    this.message,
    this.distanceMeters,
  });
}

class LocationService {
  /// Validasi posisi GPS terhadap koordinat lokasi jika [lokasi.cekLokasi] aktif.
  static Future<LocationCheckResult> validateLokasiPosition(
    LokasiItem lokasi,
  ) async {
    if (!lokasi.cekLokasi) {
      return const LocationCheckResult(allowed: true);
    }

    if (lokasi.latitude == null || lokasi.longitude == null) {
      return LocationCheckResult(
        allowed: false,
        message:
            'Koordinat GPS untuk lokasi ${lokasi.namaLokasi} (${lokasi.kodeLokasi}) belum diatur di database.',
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationCheckResult(
        allowed: false,
        message: 'GPS / Layanan Lokasi perangkat tidak aktif. Aktifkan GPS untuk melanjutkan.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return LocationCheckResult(
        allowed: false,
        message:
            'Izin akses lokasi ditolak. Berikan izin lokasi pada aplikasi untuk memvalidasi area ${lokasi.namaLokasi}.',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        lokasi.latitude!,
        lokasi.longitude!,
      );

      if (distance > lokasi.radiusMeter) {
        return LocationCheckResult(
          allowed: false,
          distanceMeters: distance,
          message:
              'Posisi Anda berada ${distance.round()} m dari ${lokasi.namaLokasi} (maksimal ${lokasi.radiusMeter} m). Silakan menuju area ${lokasi.namaLokasi} untuk melanjutkan.',
        );
      }

      return LocationCheckResult(allowed: true, distanceMeters: distance);
    } catch (e) {
      return LocationCheckResult(
        allowed: false,
        message: 'Gagal membaca koordinat GPS perangkat: $e',
      );
    }
  }
}
