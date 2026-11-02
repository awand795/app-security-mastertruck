class CheckinCandidate {
  final String source; // 'BOOKING' or 'MEMBER_UNIT'
  final int? bookingId;
  final String? noBooking;
  final String noPolisi;
  final String noPolisiClean;
  final String? customerName;
  final String? customerTelepon;
  final String? jenisLayanan;
  final String? keluhan;
  final String? catatan;
  final String? tanggalBooking;
  final String? jamBooking;
  final String? statusBooking;
  final bool isConfirmed;
  final bool canCheckin;
  final bool isWithinWindow;
  final bool isStaleUnconfirmed;
  final int? unitId;
  final int? memberId;
  final String? namaPerusahaan;
  final String? namaPenggunaFleet;
  final String? namaPic;
  final String? unitTelepon;
  final String? jenisArmada;
  final String? merk;
  final String? model;
  final int? tahun;
  final bool hasActiveBooking;

  CheckinCandidate({
    required this.source,
    this.bookingId,
    this.noBooking,
    required this.noPolisi,
    required this.noPolisiClean,
    this.customerName,
    this.customerTelepon,
    this.jenisLayanan,
    this.keluhan,
    this.catatan,
    this.tanggalBooking,
    this.jamBooking,
    this.statusBooking,
    this.isConfirmed = false,
    this.canCheckin = true,
    this.isWithinWindow = true,
    this.isStaleUnconfirmed = false,
    this.unitId,
    this.memberId,
    this.namaPerusahaan,
    this.namaPenggunaFleet,
    this.namaPic,
    this.unitTelepon,
    this.jenisArmada,
    this.merk,
    this.model,
    this.tahun,
    this.hasActiveBooking = false,
  });

  factory CheckinCandidate.fromJson(Map<String, dynamic> json) {
    final rawClean = (json['no_polisi_clean'] ?? json['no_polisi'] ?? json['nopol'] ?? '')
        .toString()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '');

    final source = json['source']?.toString().toUpperCase() == 'BOOKING' ? 'BOOKING' : 'MEMBER_UNIT';

    return CheckinCandidate(
      source: source,
      bookingId: json['booking_id'] != null
          ? int.tryParse(json['booking_id'].toString())
          : (json['id'] != null ? int.tryParse(json['id'].toString()) : null),
      noBooking: json['no_booking']?.toString(),
      noPolisi: (json['no_polisi'] ?? json['nopol'] ?? rawClean).toString(),
      noPolisiClean: rawClean,
      customerName: json['customer_name']?.toString() ?? json['nama_pelanggan']?.toString(),
      customerTelepon: json['customer_telepon']?.toString() ?? json['telepon']?.toString(),
      jenisLayanan: json['jenis_layanan']?.toString(),
      keluhan: json['keluhan']?.toString() ?? json['catatan']?.toString(),
      catatan: json['catatan']?.toString(),
      tanggalBooking: json['tanggal_booking']?.toString(),
      jamBooking: json['jam_booking']?.toString(),
      statusBooking: json['status_booking']?.toString() ?? json['status']?.toString(),
      isConfirmed: json['is_confirmed'] == true ||
          json['is_confirmed']?.toString().toLowerCase() == 'true' ||
          json['is_confirmed']?.toString() == '1',
      canCheckin: json['can_checkin'] != false && json['can_checkin']?.toString() != '0',
      isWithinWindow: json['is_within_window'] != false,
      isStaleUnconfirmed: json['is_stale_unconfirmed'] == true,
      unitId: json['unit_id'] != null ? int.tryParse(json['unit_id'].toString()) : null,
      memberId: json['member_id'] != null ? int.tryParse(json['member_id'].toString()) : null,
      namaPerusahaan: json['nama_perusahaan']?.toString(),
      namaPenggunaFleet: json['nama_pengguna_fleet']?.toString(),
      namaPic: json['nama_pic']?.toString(),
      unitTelepon: json['unit_telepon']?.toString(),
      jenisArmada: json['jenis_armada']?.toString(),
      merk: json['merk']?.toString(),
      model: json['model']?.toString() ?? json['tipe_kendaraan']?.toString(),
      tahun: json['tahun'] != null ? int.tryParse(json['tahun'].toString()) : null,
      hasActiveBooking: json['has_active_booking'] == true,
    );
  }

  String get effectiveDriverName {
    if (source == 'BOOKING') {
      return customerName ?? '';
    }
    return namaPenggunaFleet ?? namaPic ?? customerName ?? '';
  }

  String get effectivePhone {
    if (source == 'BOOKING') {
      return customerTelepon ?? '';
    }
    return unitTelepon ?? customerTelepon ?? '';
  }

  String get effectiveComplaint {
    return catatan ?? keluhan ?? '';
  }

  String get mappedTipeKunjungan {
    if (source == 'BOOKING') {
      final layanan = (jenisLayanan ?? '').toLowerCase();
      if (layanan.contains('part') || layanan.contains('sparepart') || layanan.contains('beli')) {
        return 'Beli Part';
      } else if (layanan.contains('kunjungan') || layanan.contains('tamu')) {
        return 'Kunjungan';
      } else if (layanan.contains('service') || layanan.contains('servis')) {
        return 'Service';
      } else if (layanan.isNotEmpty) {
        return 'Lainnya';
      }
    }
    return 'Service';
  }
}
