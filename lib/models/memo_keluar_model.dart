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
  });

  factory MemoKeluar.fromJson(Map<String, dynamic> json) {
    DateTime? keluarDate;
    final wk = json['waktu_keluar'] ?? json['waktu_check_out'];
    if (wk != null) {
      keluarDate = DateTime.tryParse(wk.toString());
    }

    return MemoKeluar(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      nomorMemo: (json['nomor_memo'] ?? json['memo_no'] ?? '-').toString(),
      noPolisi: (json['no_polisi'] ?? json['nopol'] ?? '').toString().toUpperCase(),
      namaPengemudi: json['nama_pengemudi']?.toString(),
      nomorSpk: json['nomor_spk']?.toString(),
      nomorInvoice: json['nomor_invoice']?.toString(),
      waktuKeluar: keluarDate,
      petugasSecurityKeluar: (json['petugas_security_keluar'] ?? json['petugas_keluar'])?.toString(),
      catatanKeluar: json['catatan_keluar']?.toString(),
      namaPelanggan: json['nama_pelanggan']?.toString(),
    );
  }
}
