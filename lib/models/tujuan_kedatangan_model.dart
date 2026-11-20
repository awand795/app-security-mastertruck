class TujuanKedatanganItem {
  final int id;
  final String kodeTujuan;
  final String namaTujuan;
  final int urutan;
  final bool isActive;

  const TujuanKedatanganItem({
    required this.id,
    required this.kodeTujuan,
    required this.namaTujuan,
    this.urutan = 0,
    this.isActive = true,
  });

  factory TujuanKedatanganItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return TujuanKedatanganItem(
      id: parseInt(json['id'], 0),
      kodeTujuan: (json['kode_tujuan'] ?? '').toString().trim().toUpperCase(),
      namaTujuan: (json['nama_tujuan'] ?? '').toString().trim(),
      urutan: parseInt(json['urutan'], 0),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }
}
