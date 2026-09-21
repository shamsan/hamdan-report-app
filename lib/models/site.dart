import 'report.dart';

class Site {
  final String id;
  final String clientId;
  final String nameAr;
  final String nameEn;
  final String facilityType;
  final String category;
  final String governorate;
  final String directorate;
  final String locationAddress;
  final double? latitude;
  final double? longitude;

  // الممول الخاص بهذا الموقع (Dedicated Site Funder)
  final String funderNameAr;
  final String funderNameEn;
  final String? funderLogoBase64;
  final bool showFunderLogo;

  // بيانات التعاقد والمشروع
  final String projectName;
  final String contractNumber;
  final String implementingContractor;
  final String? contractorLogoBase64;

  // المواصفات الفنية لمنظومة الطاقة
  final SystemSpecs systemSpecs;

  // ضابط الاتصال بالموقع
  final String contactPerson;
  final String phone;
  final String email;
  final String installationDate;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Site({
    required this.id,
    required this.clientId,
    required this.nameAr,
    this.nameEn = '',
    this.facilityType = 'مركز صحي',
    this.category = 'CAT 8',
    this.governorate = '',
    this.directorate = '',
    this.locationAddress = '',
    this.latitude,
    this.longitude,
    this.funderNameAr = 'مكتب الأمم المتحدة لخدمات المشاريع - UNOPS',
    this.funderNameEn = 'UNOPS',
    this.funderLogoBase64,
    this.showFunderLogo = true,
    this.projectName = '',
    this.contractNumber = '',
    this.implementingContractor = '',
    this.contractorLogoBase64,
    this.systemSpecs = const SystemSpecs(),
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.installationDate = '',
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => nameAr.isNotEmpty ? nameAr : nameEn;

  Site copyWith({
    String? id,
    String? clientId,
    String? nameAr,
    String? nameEn,
    String? facilityType,
    String? category,
    String? governorate,
    String? directorate,
    String? locationAddress,
    double? latitude,
    double? longitude,
    String? funderNameAr,
    String? funderNameEn,
    String? funderLogoBase64,
    bool? showFunderLogo,
    String? projectName,
    String? contractNumber,
    String? implementingContractor,
    String? contractorLogoBase64,
    SystemSpecs? systemSpecs,
    String? contactPerson,
    String? phone,
    String? email,
    String? installationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Site(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      facilityType: facilityType ?? this.facilityType,
      category: category ?? this.category,
      governorate: governorate ?? this.governorate,
      directorate: directorate ?? this.directorate,
      locationAddress: locationAddress ?? this.locationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      funderNameAr: funderNameAr ?? this.funderNameAr,
      funderNameEn: funderNameEn ?? this.funderNameEn,
      funderLogoBase64: funderLogoBase64 ?? this.funderLogoBase64,
      showFunderLogo: showFunderLogo ?? this.showFunderLogo,
      projectName: projectName ?? this.projectName,
      contractNumber: contractNumber ?? this.contractNumber,
      implementingContractor: implementingContractor ?? this.implementingContractor,
      contractorLogoBase64: contractorLogoBase64 ?? this.contractorLogoBase64,
      systemSpecs: systemSpecs ?? this.systemSpecs,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      installationDate: installationDate ?? this.installationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'nameAr': nameAr,
    'nameEn': nameEn,
    'facilityType': facilityType,
    'category': category,
    'governorate': governorate,
    'directorate': directorate,
    'locationAddress': locationAddress,
    'latitude': latitude,
    'longitude': longitude,
    'funderNameAr': funderNameAr,
    'funderNameEn': funderNameEn,
    'funderLogoBase64': funderLogoBase64,
    'showFunderLogo': showFunderLogo,
    'projectName': projectName,
    'contractNumber': contractNumber,
    'implementingContractor': implementingContractor,
    'contractorLogoBase64': contractorLogoBase64,
    'systemSpecs': systemSpecs.toJson(),
    'contactPerson': contactPerson,
    'phone': phone,
    'email': email,
    'installationDate': installationDate,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Site.fromJson(Map<String, dynamic> json) => Site(
    id: json['id'] ?? '',
    clientId: json['clientId'] ?? '',
    nameAr: json['nameAr'] ?? '',
    nameEn: json['nameEn'] ?? '',
    facilityType: json['facilityType'] ?? 'مركز صحي',
    category: json['category'] ?? 'CAT 8',
    governorate: json['governorate'] ?? '',
    directorate: json['directorate'] ?? '',
    locationAddress: json['locationAddress'] ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    funderNameAr: json['funderNameAr'] ?? 'مكتب الأمم المتحدة لخدمات المشاريع - UNOPS',
    funderNameEn: json['funderNameEn'] ?? 'UNOPS',
    funderLogoBase64: json['funderLogoBase64'],
    showFunderLogo: json['showFunderLogo'] ?? true,
    projectName: json['projectName'] ?? '',
    contractNumber: json['contractNumber'] ?? '',
    implementingContractor: json['implementingContractor'] ?? '',
    contractorLogoBase64: json['contractorLogoBase64'],
    systemSpecs: SystemSpecs.fromJson(json['systemSpecs'] ?? {}),
    contactPerson: json['contactPerson'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'] ?? '',
    installationDate: json['installationDate'] ?? '',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
        : DateTime.now(),
  );
}
