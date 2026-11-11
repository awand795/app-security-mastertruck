class EmployeeItem {
  final int? id;
  final String name;
  final String? employeeId;
  final String position;
  final String? mobileNumber;
  final bool isServiceAdvisor;

  const EmployeeItem({
    this.id,
    required this.name,
    this.employeeId,
    required this.position,
    this.mobileNumber,
    this.isServiceAdvisor = false,
  });

  factory EmployeeItem.fromJson(Map<String, dynamic> json) {
    final name = (json['employeename'] ??
            json['nama'] ??
            json['name'] ??
            json['nama_lengkap'] ??
            '')
        .toString()
        .trim();
    final pos = (json['positionname'] ??
            json['jabatan'] ??
            (json['isserviceadvisor'] == true
                ? 'Service Advisor'
                : 'Karyawan'))
        .toString()
        .trim();

    return EmployeeItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      name: name,
      employeeId: json['employeeid']?.toString(),
      position: pos.isEmpty ? 'Karyawan' : pos,
      mobileNumber: json['mobilenumber']?.toString(),
      isServiceAdvisor: json['isserviceadvisor'] == true,
    );
  }

  String get displayName => name;
}
