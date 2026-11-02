class ActiveVehicle {
  final int id;
  final String? nomorTiket;
  final String noPolisi;
  final String? namaPengemudi;
  final String? noTeleponPengemudi;
  final String? picTujuan;
  final String? tipeKunjungan;
  final String? keluhan;
  final String? statusServis;
  final String? statusInvoice;
  final String? nomorSpk;
  final String? nomorInvoice;
  final DateTime? waktuCheckIn;
  final String? petugasSecurity;
  final String? jenisKedatangan;
  final String? namaPelanggan;

  ActiveVehicle({
    required this.id,
    this.nomorTiket,
    required this.noPolisi,
    this.namaPengemudi,
    this.noTeleponPengemudi,
    this.picTujuan,
    this.tipeKunjungan,
    this.keluhan,
    this.statusServis,
    this.statusInvoice,
    this.nomorSpk,
    this.nomorInvoice,
    this.waktuCheckIn,
    this.petugasSecurity,
    this.jenisKedatangan,
    this.namaPelanggan,
  });

  bool get isSiapKeluar =>
      (statusInvoice != null && statusInvoice!.toLowerCase() == 'lunas') ||
      (statusServis != null &&
          (statusServis!.toLowerCase().contains('selesai') ||
              statusServis!.toLowerCase().contains('closed')));

  factory ActiveVehicle.fromJson(Map<String, dynamic> json) {
    DateTime? checkInDate;
    final wci = json['waktu_check_in'] ?? json['waktu_masuk'];
    if (wci != null) {
      checkInDate = DateTime.tryParse(wci.toString());
    }

    return ActiveVehicle(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      nomorTiket: json['nomor_tiket']?.toString() ?? json['ticket_no']?.toString(),
      noPolisi: (json['no_polisi'] ?? json['nopol'] ?? '').toString().toUpperCase(),
      namaPengemudi: json['nama_pengemudi']?.toString(),
      noTeleponPengemudi: json['no_telepon_pengemudi']?.toString(),
      picTujuan: json['pic_tujuan']?.toString(),
      tipeKunjungan: json['tipe_kunjungan']?.toString(),
      keluhan: json['keluhan']?.toString(),
      statusServis: json['status_servis']?.toString(),
      statusInvoice: json['status_invoice']?.toString(),
      nomorSpk: json['nomor_spk']?.toString(),
      nomorInvoice: json['nomor_invoice']?.toString(),
      waktuCheckIn: checkInDate,
      petugasSecurity: (json['petugas_security_masuk'] ?? json['petugas_security'])?.toString(),
      jenisKedatangan: json['jenis_kedatangan']?.toString(),
      namaPelanggan: json['nama_pelanggan']?.toString() ?? json['customer_name']?.toString(),
    );
  }
}
