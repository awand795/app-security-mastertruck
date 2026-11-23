/// Model foto dokumentasi kunjungan (tabel `ms_foto`), setara dengan `MsFoto`
/// pada aplikasi web pos security.
class MsFoto {
  final int? id;
  final int kunjunganId;
  final String jenisEvent; // 'MASUK' | 'KELUAR'
  final String sudutPandang;
  final String fotoData; // base64 data url / path / bytea hex

  const MsFoto({
    this.id,
    required this.kunjunganId,
    this.jenisEvent = 'MASUK',
    required this.sudutPandang,
    this.fotoData = '',
  });

  factory MsFoto.fromJson(Map<String, dynamic> json) {
    int? parseOptInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return MsFoto(
      id: parseOptInt(json['id']),
      kunjunganId: parseOptInt(json['kunjungan_id']) ?? 0,
      jenisEvent: (json['jenis_event'] ?? 'MASUK').toString(),
      sudutPandang: (json['sudut_pandang'] ?? '').toString(),
      fotoData: (json['foto_data'] ?? '').toString(),
    );
  }
}
