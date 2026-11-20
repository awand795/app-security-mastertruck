class GateModel {
  final int id;
  final String kodeGate;
  final String namaGate;
  final String? keterangan;
  final bool isActive;

  const GateModel({
    required this.id,
    required this.kodeGate,
    required this.namaGate,
    this.keterangan,
    this.isActive = true,
  });

  factory GateModel.fromJson(Map<String, dynamic> json) {
    return GateModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      kodeGate: (json['kode_gate'] ?? '').toString(),
      namaGate: (json['nama_gate'] ?? '').toString(),
      keterangan: json['keterangan']?.toString(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kode_gate': kodeGate,
    'nama_gate': namaGate,
    'keterangan': keterangan,
    'is_active': isActive,
  };
}
