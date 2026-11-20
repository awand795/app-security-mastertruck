class MemoKeluar {
  final int id;
  final String nomorMemo;
  final String noPolisi;
  final String? namaPengemudi;
  final String? nomorSpk;
  final String? nomorInvoice;
  final DateTime? waktuKeluar;
  final String? petugasSecurityKeluar;
  final String? catatanKeluar;
  final String? namaPelanggan;
  final String statusKunjungan;
  final String? alasanKeluar;
  final String? subTujuan;
  final int? gateMasukId;
  final String? gateMasukNama;
  final int? gateKeluarId;
  final String? gateKeluarNama;

  MemoKeluar({
    required this.id,
    required this.nomorMemo,
    required this.noPolisi,
    this.namaPengemudi,
    this.nomorSpk,
    this.nomorInvoice,
    this.waktuKeluar,
    this.petugasSecurityKeluar,
    this.catatanKeluar,
    this.namaPelanggan,
    this.statusKunjungan = 'SELESAI',
    this.alasanKeluar,
    this.subTujuan,
    this.gateMasukId,
    this.gateMasukNama,
    this.gateKeluarId,
    this.gateKeluarNama,
  });

  bool get isKeluarSementara =>
      statusKunjungan.toUpperCase() == 'KELUAR_SEMENTARA';

  factory MemoKeluar.fromJson(Map<String, dynamic> json) {
    DateTime? keluarDate;
    final wk = json['waktu_keluar'] ?? json['waktu_check_out'];
    if (wk != null) {
      keluarDate = DateTime.tryParse(wk.toString());
    }

    int? parseOptInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return MemoKeluar(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      nomorMemo: (json['nomor_memo'] ?? json['memo_no'] ?? '-').toString(),
      noPolisi: (json['no_polisi'] ?? json['nopol'] ?? '')
          .toString()
          .toUpperCase(),
      namaPengemudi: json['nama_pengemudi']?.toString(),
      nomorSpk: json['nomor_spk']?.toString(),
      nomorInvoice: json['nomor_invoice']?.toString(),
      waktuKeluar: keluarDate,
      petugasSecurityKeluar:
          (json['petugas_security_keluar'] ?? json['petugas_keluar'])
              ?.toString(),
      catatanKeluar: json['catatan_keluar']?.toString(),
      namaPelanggan: json['nama_pelanggan']?.toString(),
      statusKunjungan: (json['status_kunjungan'] ?? 'SELESAI').toString(),
      alasanKeluar: json['alasan_keluar']?.toString(),
      subTujuan: json['sub_tujuan']?.toString(),
      gateMasukId: parseOptInt(json['gate_masuk_id']),
      gateMasukNama: json['gate_masuk_nama']?.toString(),
      gateKeluarId: parseOptInt(json['gate_keluar_id']),
      gateKeluarNama: json['gate_keluar_nama']?.toString(),
    );
  }
}
