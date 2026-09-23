import 'package:flutter/material.dart';

class OrganizationProfile {
  final String id;
  final String name;
  final String subTitle;
  final String facilityLogoAsset;
  final String unopsLogoAsset;
  final String contractorLogoAsset;
  final String? facilityLogoBase64;
  final String? unopsLogoBase64;
  final String? contractorLogoBase64;
  final String contractorNameAr;
  final String contractorSubtitleAr;
  final String contractorNameEn;
  final String ministryNameAr;
  final String ministryNameEn;
  final bool showRightLogo;
  final String rightLogoNameEn;
  final String rightLogoNameAr;
  final String rightLogoColorHex;
  final int primaryColorValue;
  final int secondaryColorValue;
  final String contactPhone;
  final String contactEmail;
  final String address;

  const OrganizationProfile({
    required this.id,
    this.name = '',
    this.subTitle = '',
    this.facilityLogoAsset = 'assets/logos/logo_facility.png',
    this.unopsLogoAsset = 'assets/logos/logo_unops.png',
    this.contractorLogoAsset = 'assets/logos/logo_contractor.png',
    this.facilityLogoBase64,
    this.unopsLogoBase64,
    this.contractorLogoBase64,
    this.contractorNameAr = '',
    this.contractorSubtitleAr = '',
    this.contractorNameEn = '',
    this.ministryNameAr = '',
    this.ministryNameEn = '',
    this.showRightLogo = false,
    this.rightLogoNameEn = '',
    this.rightLogoNameAr = '',
    this.rightLogoColorHex = '0072CE',
    this.primaryColorValue = 0xFF1565C0,
    this.secondaryColorValue = 0xFF00897B,
    this.contactPhone = '',
    this.contactEmail = '',
    this.address = '',
  });

  Color get primaryColor => Color(primaryColorValue);
  Color get secondaryColor => Color(secondaryColorValue);

  OrganizationProfile copyWith({
    String? name,
    String? subTitle,
    String? facilityLogoBase64,
    String? unopsLogoBase64,
    String? contractorLogoBase64,
    String? contractorNameAr,
    String? contractorSubtitleAr,
    String? contractorNameEn,
    String? ministryNameAr,
    String? ministryNameEn,
    bool? showRightLogo,
    String? rightLogoNameEn,
    String? rightLogoNameAr,
    String? rightLogoColorHex,
    bool clearFacilityLogo = false,
    bool clearUnopsLogo = false,
    bool clearContractorLogo = false,
    int? primaryColorValue,
    int? secondaryColorValue,
    String? contactPhone,
    String? contactEmail,
    String? address,
  }) {
    return OrganizationProfile(
      id: id,
      name: name ?? this.name,
      subTitle: subTitle ?? this.subTitle,
      facilityLogoAsset: facilityLogoAsset,
      unopsLogoAsset: unopsLogoAsset,
      contractorLogoAsset: contractorLogoAsset,
      facilityLogoBase64: clearFacilityLogo ? null : (facilityLogoBase64 ?? this.facilityLogoBase64),
      unopsLogoBase64: clearUnopsLogo ? null : (unopsLogoBase64 ?? this.unopsLogoBase64),
      contractorLogoBase64: clearContractorLogo ? null : (contractorLogoBase64 ?? this.contractorLogoBase64),
      contractorNameAr: contractorNameAr ?? this.contractorNameAr,
      contractorSubtitleAr: contractorSubtitleAr ?? this.contractorSubtitleAr,
      contractorNameEn: contractorNameEn ?? this.contractorNameEn,
      ministryNameAr: ministryNameAr ?? this.ministryNameAr,
      ministryNameEn: ministryNameEn ?? this.ministryNameEn,
      showRightLogo: showRightLogo ?? this.showRightLogo,
      rightLogoNameEn: rightLogoNameEn ?? this.rightLogoNameEn,
      rightLogoNameAr: rightLogoNameAr ?? this.rightLogoNameAr,
      rightLogoColorHex: rightLogoColorHex ?? this.rightLogoColorHex,
      primaryColorValue: primaryColorValue ?? this.primaryColorValue,
      secondaryColorValue: secondaryColorValue ?? this.secondaryColorValue,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subTitle': subTitle,
    'facilityLogoBase64': facilityLogoBase64,
    'unopsLogoBase64': unopsLogoBase64,
    'contractorLogoBase64': contractorLogoBase64,
    'contractorNameAr': contractorNameAr,
    'contractorSubtitleAr': contractorSubtitleAr,
    'contractorNameEn': contractorNameEn,
    'ministryNameAr': ministryNameAr,
    'ministryNameEn': ministryNameEn,
    'showRightLogo': showRightLogo,
    'rightLogoNameEn': rightLogoNameEn,
    'rightLogoNameAr': rightLogoNameAr,
    'rightLogoColorHex': rightLogoColorHex,
    'primaryColorValue': primaryColorValue,
    'secondaryColorValue': secondaryColorValue,
    'contactPhone': contactPhone,
    'contactEmail': contactEmail,
    'address': address,
  };

  factory OrganizationProfile.fromJson(Map<String, dynamic> json) {
    return OrganizationProfile(
      id: json['id'] ?? 'org_default',
      name: json['name'] ?? '',
      subTitle: json['subTitle'] ?? '',
      facilityLogoBase64: json['facilityLogoBase64'],
      unopsLogoBase64: json['unopsLogoBase64'],
      contractorLogoBase64: json['contractorLogoBase64'],
      contractorNameAr: json['contractorNameAr'] ?? '',
      contractorSubtitleAr: json['contractorSubtitleAr'] ?? '',
      contractorNameEn: json['contractorNameEn'] ?? '',
      ministryNameAr: json['ministryNameAr'] ?? '',
      ministryNameEn: json['ministryNameEn'] ?? '',
      showRightLogo: json['showRightLogo'] ?? false,
      rightLogoNameEn: json['rightLogoNameEn'] ?? '',
      rightLogoNameAr: json['rightLogoNameAr'] ?? '',
      rightLogoColorHex: json['rightLogoColorHex'] ?? '0072CE',
      primaryColorValue: json['primaryColorValue'] ?? 0xFF1565C0,
      secondaryColorValue: json['secondaryColorValue'] ?? 0xFF00897B,
      contactPhone: json['contactPhone'] ?? '',
      contactEmail: json['contactEmail'] ?? '',
      address: json['address'] ?? '',
    );
  }
}
