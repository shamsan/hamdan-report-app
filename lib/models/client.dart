class Client {
  final String id;
  final String nameAr;
  final String nameEn;
  final String clientType; // وزارة حكومية، منظمة دولية، مؤسسة محلية، قطاع خاص...
  final String? logoBase64;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.id,
    required this.nameAr,
    this.nameEn = '',
    this.clientType = 'جهة حكومية / وزارة',
    this.logoBase64,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => nameAr.isNotEmpty ? nameAr : nameEn;

  Client copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? clientType,
    String? logoBase64,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      clientType: clientType ?? this.clientType,
      logoBase64: logoBase64 ?? this.logoBase64,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameAr': nameAr,
    'nameEn': nameEn,
    'clientType': clientType,
    'logoBase64': logoBase64,
    'contactPerson': contactPerson,
    'phone': phone,
    'email': email,
    'address': address,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id'] ?? '',
    nameAr: json['nameAr'] ?? '',
    nameEn: json['nameEn'] ?? '',
    clientType: json['clientType'] ?? 'جهة حكومية / وزارة',
    logoBase64: json['logoBase64'],
    contactPerson: json['contactPerson'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'] ?? '',
    address: json['address'] ?? '',
    notes: json['notes'] ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
        : DateTime.now(),
  );
}
