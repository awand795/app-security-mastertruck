class CheckinCandidate {
  final int? bookingId;
  final String noPolisi;
  final String? namaPelanggan;
  final String? noTelepon;
  final String? jenisKedatangan;
  final String? tipeKendaraan;
  final String? keluhan;
  final String? picTujuan;

  CheckinCandidate({
    this.bookingId,
    required this.noPolisi,
    this.namaPelanggan,
    this.noTelepon,
    this.jenisKedatangan,
    this.tipeKendaraan,
    this.keluhan,
    this.picTujuan,
  });

  factory CheckinCandidate.fromJson(Map<String, dynamic> json) {
    return CheckinCandidate(
      bookingId: json['booking_id'] != null
          ? int.tryParse(json['booking_id'].toString())
          : (json['id'] != null ? int.tryParse(json['id'].toString()) : null),
      noPolisi: (json['no_polisi'] ?? json['nopol'] ?? '').toString().toUpperCase(),
      namaPelanggan: json['nama_pelanggan']?.toString() ?? json['nama_pemilik']?.toString(),
      noTelepon: json['no_telepon']?.toString() ?? json['telepon']?.toString(),
      jenisKedatangan: json['jenis_kedatangan']?.toString() ??
          (json['booking_id'] != null ? 'BOOKING' : 'WALK_IN_MEMBER'),
      tipeKendaraan: json['tipe_kendaraan']?.toString() ?? json['model']?.toString(),
      keluhan: json['keluhan']?.toString() ?? json['deskripsi_keluhan']?.toString(),
      picTujuan: json['pic_tujuan']?.toString(),
    );
  }
}
