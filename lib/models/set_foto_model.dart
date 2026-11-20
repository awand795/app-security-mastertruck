class SetFotoItem {
  final int id;
  final String kodeFoto;
  final String namaFoto;
  final bool isWajib;
  final int urutan;
  final bool isActive;

  const SetFotoItem({
    required this.id,
    required this.kodeFoto,
    required this.namaFoto,
    this.isWajib = false,
    this.urutan = 0,
    this.isActive = true,
  });

  String get angleKey => kodeFoto.trim().toUpperCase();

  String get displayLabel => isWajib ? '$namaFoto *' : namaFoto;

  factory SetFotoItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return SetFotoItem(
      id: parseInt(json['id'], 0),
      kodeFoto: (json['kode_foto'] ?? '').toString().trim().toLowerCase(),
      namaFoto: (json['nama_foto'] ?? '').toString().trim(),
      isWajib: json['is_wajib'] == true || json['is_wajib'] == 1,
      urutan: parseInt(json['urutan'], 0),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }

  static const List<SetFotoItem> defaultSettings = [
    SetFotoItem(
      id: 1,
      kodeFoto: 'tampak_depan',
      namaFoto: 'Tampak Depan',
      isWajib: true,
      urutan: 1,
    ),
    SetFotoItem(
      id: 2,
      kodeFoto: 'foto_supir',
      namaFoto: 'Foto Supir',
      isWajib: true,
      urutan: 2,
    ),
    SetFotoItem(
      id: 3,
      kodeFoto: 'tampak_belakang',
      namaFoto: 'Tampak Belakang',
      isWajib: false,
      urutan: 3,
    ),
    SetFotoItem(
      id: 4,
      kodeFoto: 'tampak_kiri',
      namaFoto: 'Tampak Kiri',
      isWajib: false,
      urutan: 4,
    ),
    SetFotoItem(
      id: 5,
      kodeFoto: 'tampak_kanan',
      namaFoto: 'Tampak Kanan',
      isWajib: false,
      urutan: 5,
    ),
    SetFotoItem(
      id: 6,
      kodeFoto: 'foto_lainnya',
      namaFoto: 'Foto Lainnya',
      isWajib: false,
      urutan: 6,
    ),
  ];
}
