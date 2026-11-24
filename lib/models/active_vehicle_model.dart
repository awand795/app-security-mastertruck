class ActiveVehicle {
  final int id;
  final String? nomorTiket;
  final String noPolisi;
  final String? namaPengemudi;
  final String? noTeleponPengemudi;
  final String? picTujuan;
  final String? tipeKunjungan;
  final String? subTujuan;
  final String statusKunjungan; // DI_BENGKEL | KELUAR_SEMENTARA | SELESAI
  final String? alasanKeluar;
  final int? gateMasukId;
  final String? gateMasukNama;
  final int? gateKeluarId;
  final String? gateKeluarNama;
  final String? lokasiKode;
  final String? lokasiNama;
  final DateTime? checkin2;
  final DateTime? checkout2;
  final bool hasWo;
  final bool hasFir;
  final String? keluhan;
  final String? statusServis;
  final String? statusInvoice;
  final String? nomorSpk;
  final String? nomorInvoice;
  final DateTime? waktuCheckIn;
  final DateTime? waktuCheckOut;
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
    this.subTujuan,
    this.statusKunjungan = 'DI_BENGKEL',
    this.alasanKeluar,
    this.gateMasukId,
    this.gateMasukNama,
    this.gateKeluarId,
    this.gateKeluarNama,
    this.lokasiKode,
    this.lokasiNama,
    this.checkin2,
    this.checkout2,
    this.hasWo = false,
    this.hasFir = false,
    this.keluhan,
    this.statusServis,
    this.statusInvoice,
    this.nomorSpk,
    this.nomorInvoice,
    this.waktuCheckIn,
    this.waktuCheckOut,
    this.petugasSecurity,
    this.jenisKedatangan,
    this.namaPelanggan,
  });

  bool get isKeluarSementara =>
      statusKunjungan.toUpperCase() == 'KELUAR_SEMENTARA';

  bool get isServicePengerjaan =>
      (subTujuan ?? tipeKunjungan ?? '').toUpperCase() == 'SERVICE';

  bool isLokasiMt([String? overrideLokasiKode]) =>
      (overrideLokasiKode ?? lokasiKode ?? '').trim().toUpperCase() == 'MT';

  /// Khusus lokasi MT: jika ada SPK/proses pengerjaan (hasWo) dan FIR belum ada -> KELUAR_SEMENTARA.
  /// Lokasi selain MT tidak ada pengecekan SPK/FIR (langsung keluar biasa).
  bool willBeKeluarSementaraFor([String? overrideLokasiKode]) =>
      isLokasiMt(overrideLokasiKode) && hasWo && !hasFir;

  bool get willBeKeluarSementara => willBeKeluarSementaraFor();

  /// Alasan keluar wajib diisi di lokasi MT bila Keluar Sementara (hasWo && !hasFir)
  /// atau tidak memiliki SPK + FIR (!hasWo || !hasFir). Jika sudah ada SPK & FIR -> false.
  bool requiresExitReasonFor([String? overrideLokasiKode]) {
    if (!isLokasiMt(overrideLokasiKode)) return false;
    return !(hasWo && hasFir);
  }

  bool get requiresExitReason => requiresExitReasonFor();

  bool get isSiapKeluar => !isLokasiMt() || (hasWo && hasFir) || !hasWo;

  factory ActiveVehicle.fromJson(Map<String, dynamic> json) {
    DateTime? checkInDate;
    final wci = json['waktu_check_in'] ?? json['waktu_masuk'];
    if (wci != null) {
      checkInDate = DateTime.tryParse(wci.toString());
    }
    DateTime? checkOutDate;
    final wco = json['waktu_check_out'] ?? json['waktu_keluar'];
    if (wco != null) {
      checkOutDate = DateTime.tryParse(wco.toString());
    }
    DateTime? checkin2Date;
    if (json['checkin2'] != null) {
      checkin2Date = DateTime.tryParse(json['checkin2'].toString());
    }
    DateTime? checkout2Date;
    if (json['checkout2'] != null) {
      checkout2Date = DateTime.tryParse(json['checkout2'].toString());
    }

    int? parseOptInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return ActiveVehicle(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      nomorTiket:
          json['nomor_tiket']?.toString() ?? json['ticket_no']?.toString(),
      noPolisi: (json['no_polisi'] ?? json['nopol'] ?? '')
          .toString()
          .toUpperCase(),
      namaPengemudi: json['nama_pengemudi']?.toString(),
      noTeleponPengemudi: json['no_telepon_pengemudi']?.toString(),
      picTujuan: json['pic_tujuan']?.toString(),
      tipeKunjungan: json['tipe_kunjungan']?.toString(),
      subTujuan: json['sub_tujuan']?.toString(),
      statusKunjungan: (json['status_kunjungan'] ?? 'DI_BENGKEL').toString(),
      alasanKeluar: json['alasan_keluar']?.toString(),
      gateMasukId: parseOptInt(json['gate_masuk_id']),
      gateMasukNama: json['gate_masuk_nama']?.toString(),
      gateKeluarId: parseOptInt(json['gate_keluar_id']),
      gateKeluarNama: json['gate_keluar_nama']?.toString(),
      lokasiKode: json['lokasi_kode']?.toString(),
      lokasiNama: json['lokasi_nama']?.toString(),
      checkin2: checkin2Date,
      checkout2: checkout2Date,
      hasWo: json['has_wo'] == true,
      hasFir: json['has_fir'] == true,
      keluhan: json['keluhan']?.toString(),
      statusServis: json['status_servis']?.toString(),
      statusInvoice: json['status_invoice']?.toString(),
      nomorSpk: (json['no_spk'] ?? json['nomor_spk'])?.toString(),
      nomorInvoice: json['nomor_invoice']?.toString(),
      waktuCheckIn: checkInDate,
      waktuCheckOut: checkOutDate,
      petugasSecurity:
          (json['petugas_security_masuk'] ?? json['petugas_security'])
              ?.toString(),
      jenisKedatangan: json['jenis_kedatangan']?.toString(),
      namaPelanggan:
          json['nama_pelanggan']?.toString() ??
          json['customer_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nomor_tiket': nomorTiket,
    'no_polisi': noPolisi,
    'nama_pengemudi': namaPengemudi,
    'no_telepon_pengemudi': noTeleponPengemudi,
    'pic_tujuan': picTujuan,
    'tipe_kunjungan': tipeKunjungan,
    'sub_tujuan': subTujuan,
    'status_kunjungan': statusKunjungan,
    'alasan_keluar': alasanKeluar,
    'gate_masuk_id': gateMasukId,
    'gate_masuk_nama': gateMasukNama,
    'gate_keluar_id': gateKeluarId,
    'gate_keluar_nama': gateKeluarNama,
    'lokasi_kode': lokasiKode,
    'lokasi_nama': lokasiNama,
    'checkin2': checkin2?.toIso8601String(),
    'checkout2': checkout2?.toIso8601String(),
    'has_wo': hasWo,
    'has_fir': hasFir,
    'keluhan': keluhan,
    'status_servis': statusServis,
    'status_invoice': statusInvoice,
    'no_spk': nomorSpk,
    'nomor_invoice': nomorInvoice,
    'waktu_check_in': waktuCheckIn?.toIso8601String(),
    'waktu_check_out': waktuCheckOut?.toIso8601String(),
    'petugas_security_masuk': petugasSecurity,
    'jenis_kedatangan': jenisKedatangan,
    'nama_pelanggan': namaPelanggan,
  };
}
