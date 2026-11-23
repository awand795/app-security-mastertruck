class PanduanApkItem {
  final int id;
  final String kode;
  final String judul;
  final String kategori;
  final String kontenHtml;
  final int urutan;
  final bool isActive;

  const PanduanApkItem({
    required this.id,
    required this.kode,
    required this.judul,
    this.kategori = 'SOP',
    required this.kontenHtml,
    this.urutan = 0,
    this.isActive = true,
  });

  factory PanduanApkItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return PanduanApkItem(
      id: parseInt(json['id'], 0),
      kode: (json['kode'] ?? '').toString().trim(),
      judul: (json['judul'] ?? '').toString().trim(),
      kategori: (json['kategori'] ?? 'SOP').toString().trim().toUpperCase(),
      kontenHtml: (json['konten_html'] ?? '').toString(),
      urutan: parseInt(json['urutan'], 0),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }
}
