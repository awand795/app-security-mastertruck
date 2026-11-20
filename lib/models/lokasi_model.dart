class LokasiItem {
  final int id;
  final String kodeLokasi;
  final String namaLokasi;
  final double? latitude;
  final double? longitude;
  final int radiusMeter;
  final bool cekLokasi;
  final bool isActive;

  const LokasiItem({
    required this.id,
    required this.kodeLokasi,
    required this.namaLokasi,
    this.latitude,
    this.longitude,
    this.radiusMeter = 150,
    this.cekLokasi = false,
    this.isActive = true,
  });

  bool get isBengkelMt => kodeLokasi.trim().toUpperCase() == 'MT';

  factory LokasiItem.fromJson(Map<String, dynamic> json) {
    double? parseOptDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int parseInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return LokasiItem(
      id: parseInt(json['id'], 0),
      kodeLokasi: (json['kode_lokasi'] ?? '').toString().trim().toUpperCase(),
      namaLokasi: (json['nama_lokasi'] ?? '').toString().trim(),
      latitude: parseOptDouble(json['latitude']),
      longitude: parseOptDouble(json['longitude']),
      radiusMeter: parseInt(json['radius_meter'], 150),
      cekLokasi: json['cek_lokasi'] == true || json['cek_lokasi'] == 1,
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }
}
