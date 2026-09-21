import 'inspection_item.dart';
import 'measurement_data.dart';
import 'signature_data.dart';
import 'report_photo.dart';
import 'maintenance_need.dart';

enum ReportStatus {
  draft,        // مسودة قيد التحرير
  completed,    // مكتمل وجاهز
  exported,     // تم تصديره
}

class ProjectInfo {
  final String projectName;
  final String ownerEntity;
  final String implementingContractor;
  final String funder;
  final String governorate;
  final String district;
  final String location;

  const ProjectInfo({
    this.projectName = '',
    this.ownerEntity = '',
    this.implementingContractor = '',
    this.funder = '',
    this.governorate = '',
    this.district = '',
    this.location = '',
  });

  ProjectInfo copyWith({
    String? projectName,
    String? ownerEntity,
    String? implementingContractor,
    String? funder,
    String? governorate,
    String? district,
    String? location,
  }) {
    return ProjectInfo(
      projectName: projectName ?? this.projectName,
      ownerEntity: ownerEntity ?? this.ownerEntity,
      implementingContractor: implementingContractor ?? this.implementingContractor,
      funder: funder ?? this.funder,
      governorate: governorate ?? this.governorate,
      district: district ?? this.district,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
    'projectName': projectName,
    'ownerEntity': ownerEntity,
    'implementingContractor': implementingContractor,
    'funder': funder,
    'governorate': governorate,
    'district': district,
    'location': location,
  };

  factory ProjectInfo.fromJson(Map<String, dynamic> json) => ProjectInfo(
    projectName: json['projectName'] ?? '',
    ownerEntity: json['ownerEntity'] ?? '',
    implementingContractor: json['implementingContractor'] ?? '',
    funder: json['funder'] ?? '',
    governorate: json['governorate'] ?? '',
    district: json['district'] ?? '',
    location: json['location'] ?? '',
  );
}

class FacilityInfo {
  final String facilityName;
  final String facilityNameEn;
  final String facilityType;
  final String category;
  final String contactPerson;
  final String phone;
  final String email;
  final String governorate;
  final String directorate;
  final String visitDate;
  final String visitNumber;
  final String installationDate;

  const FacilityInfo({
    this.facilityName = '',
    this.facilityNameEn = '',
    this.facilityType = '',
    this.category = '',
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.governorate = '',
    this.directorate = '',
    this.visitDate = '',
    this.visitNumber = '1',
    this.installationDate = '',
  });

  String get facilityNameEnglish => facilityNameEn;

  FacilityInfo copyWith({
    String? facilityName,
    String? facilityNameEn,
    String? facilityNameEnglish,
    String? facilityType,
    String? category,
    String? contactPerson,
    String? phone,
    String? email,
    String? governorate,
    String? directorate,
    String? visitDate,
    String? visitNumber,
    String? installationDate,
  }) {
    return FacilityInfo(
      facilityName: facilityName ?? this.facilityName,
      facilityNameEn: facilityNameEnglish ?? facilityNameEn ?? this.facilityNameEn,
      facilityType: facilityType ?? this.facilityType,
      category: category ?? this.category,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      governorate: governorate ?? this.governorate,
      directorate: directorate ?? this.directorate,
      visitDate: visitDate ?? this.visitDate,
      visitNumber: visitNumber ?? this.visitNumber,
      installationDate: installationDate ?? this.installationDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'facilityName': facilityName,
    'facilityNameEn': facilityNameEn,
    'facilityType': facilityType,
    'category': category,
    'contactPerson': contactPerson,
    'phone': phone,
    'email': email,
    'governorate': governorate,
    'directorate': directorate,
    'visitDate': visitDate,
    'visitNumber': visitNumber,
    'installationDate': installationDate,
  };

  factory FacilityInfo.fromJson(Map<String, dynamic> json) => FacilityInfo(
    facilityName: json['facilityName'] ?? '',
    facilityNameEn: json['facilityNameEn'] ?? '',
    facilityType: json['facilityType'] ?? '',
    category: json['category'] ?? '',
    contactPerson: json['contactPerson'] ?? '',
    phone: json['phone'] ?? '',
    email: json['email'] ?? '',
    governorate: json['governorate'] ?? '',
    directorate: json['directorate'] ?? '',
    visitDate: json['visitDate'] ?? '',
    visitNumber: json['visitNumber'] ?? '1',
    installationDate: json['installationDate'] ?? '',
  );
}

class SystemSpecs {
  final String systemType;
  final String capacityKw;
  final String panelsCountAndWatt;
  final String invertersCapacity;
  final String invertersCount;
  final String chargeControllersCapacity;
  final String chargeControllersCount;
  final String batteryUnitsCapacity;
  final String batteryUnitsCount;
  final String otherAppliances;

  const SystemSpecs({
    this.systemType = '',
    this.capacityKw = '',
    this.panelsCountAndWatt = '',
    this.invertersCapacity = '',
    this.invertersCount = '',
    this.chargeControllersCapacity = '',
    this.chargeControllersCount = '',
    this.batteryUnitsCapacity = '',
    this.batteryUnitsCount = '',
    this.otherAppliances = '',
  });

  String get inverterCapacity => invertersCapacity;
  String get inverterCount => invertersCount;
  String get chargeControllerCapacity => chargeControllersCapacity;
  String get chargeControllerCount => chargeControllersCount;
  String get batteryUnitsCountAndVoltage => batteryUnitsCount;
  String get batteryBankCapacityAh => batteryUnitsCapacity;

  SystemSpecs copyWith({
    String? systemType,
    String? capacityKw,
    String? panelsCountAndWatt,
    String? invertersCapacity,
    String? invertersCount,
    String? chargeControllersCapacity,
    String? chargeControllersCount,
    String? batteryUnitsCapacity,
    String? batteryUnitsCount,
    String? otherAppliances,
    String? inverterCapacity,
    String? inverterCount,
    String? chargeControllerCapacity,
    String? chargeControllerCount,
    String? batteryUnitsCountAndVoltage,
    String? batteryBankCapacityAh,
  }) {
    return SystemSpecs(
      systemType: systemType ?? this.systemType,
      capacityKw: capacityKw ?? this.capacityKw,
      panelsCountAndWatt: panelsCountAndWatt ?? this.panelsCountAndWatt,
      invertersCapacity: inverterCapacity ?? invertersCapacity ?? this.invertersCapacity,
      invertersCount: inverterCount ?? invertersCount ?? this.invertersCount,
      chargeControllersCapacity: chargeControllerCapacity ?? chargeControllersCapacity ?? this.chargeControllersCapacity,
      chargeControllersCount: chargeControllerCount ?? chargeControllersCount ?? this.chargeControllersCount,
      batteryUnitsCapacity: batteryBankCapacityAh ?? batteryUnitsCapacity ?? this.batteryUnitsCapacity,
      batteryUnitsCount: batteryUnitsCountAndVoltage ?? batteryUnitsCount ?? this.batteryUnitsCount,
      otherAppliances: otherAppliances ?? this.otherAppliances,
    );
  }

  Map<String, dynamic> toJson() => {
    'systemType': systemType,
    'capacityKw': capacityKw,
    'panelsCountAndWatt': panelsCountAndWatt,
    'invertersCapacity': invertersCapacity,
    'invertersCount': invertersCount,
    'chargeControllersCapacity': chargeControllersCapacity,
    'chargeControllersCount': chargeControllersCount,
    'batteryUnitsCapacity': batteryUnitsCapacity,
    'batteryUnitsCount': batteryUnitsCount,
    'otherAppliances': otherAppliances,
  };

  factory SystemSpecs.fromJson(Map<String, dynamic> json) => SystemSpecs(
    systemType: json['systemType'] ?? '',
    capacityKw: json['capacityKw'] ?? '',
    panelsCountAndWatt: json['panelsCountAndWatt'] ?? '',
    invertersCapacity: json['invertersCapacity'] ?? '',
    invertersCount: json['invertersCount'] ?? '',
    chargeControllersCapacity: json['chargeControllersCapacity'] ?? '',
    chargeControllersCount: json['chargeControllersCount'] ?? '',
    batteryUnitsCapacity: json['batteryUnitsCapacity'] ?? '',
    batteryUnitsCount: json['batteryUnitsCount'] ?? '',
    otherAppliances: json['otherAppliances'] ?? '',
  );
}

class CorrectiveAction {
  final String id;
  final String observation;
  final String correctiveAction;
  final String responsiblePerson;
  final String targetDate;
  final String priority;

  const CorrectiveAction({
    required this.id,
    required this.observation,
    required this.correctiveAction,
    this.responsiblePerson = 'فريق الصيانة',
    this.targetDate = 'خلال أسبوع',
    this.priority = 'متوسطة',
  });

  CorrectiveAction copyWith({
    String? id,
    String? observation,
    String? correctiveAction,
    String? responsiblePerson,
    String? targetDate,
    String? priority,
  }) {
    return CorrectiveAction(
      id: id ?? this.id,
      observation: observation ?? this.observation,
      correctiveAction: correctiveAction ?? this.correctiveAction,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      targetDate: targetDate ?? this.targetDate,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'observation': observation,
    'correctiveAction': correctiveAction,
    'responsiblePerson': responsiblePerson,
    'targetDate': targetDate,
    'priority': priority,
  };

  factory CorrectiveAction.fromJson(Map<String, dynamic> json) => CorrectiveAction(
    id: json['id'] ?? '',
    observation: json['observation'] ?? '',
    correctiveAction: json['correctiveAction'] ?? '',
    responsiblePerson: json['responsiblePerson'] ?? '',
    targetDate: json['targetDate'] ?? '',
    priority: json['priority'] ?? 'متوسطة',
  );
}

class Report {
  final String id;
  final String templateId;
  final String title;
  final String reportNumber;
  final String contractNumber;
  final String visitDate;
  final String visitTime;
  final String visitNumber;
  final bool? showRightLogo;
  final String? funderLogoBase64;
  final String? funderNameAr;
  final String? funderNameEn;
  final String? contractorLogoBase64;
  final String? contractorNameAr;
  final String? contractorNameEn;
  final String? contractorSubtitleAr;
  final String? ministryLogoBase64;
  final String? ministryNameAr;
  final String? ministryNameEn;
  final String description;
  final ProjectInfo projectInfo;
  final FacilityInfo facilityInfo;
  final SystemSpecs systemSpecs;
  final List<InspectionGroup> inspectionGroups;
  final List<BatteryMeasurement> batteryMeasurements;
  final List<OperationalData> operationalData;
  final List<StringMeasurement> stringMeasurements;
  final List<CorrectiveAction> correctiveActions;
  final List<ReportPhoto> photos;
  final List<ReportSignature> signatures;
  final ApprovalStatement approvalStatement;
  final List<AttendanceRecord> attendanceList;
  final bool showNeedsInReport;
  final List<MaintenanceNeedItem> requestedNeeds;
  final List<int> activeBatteryGroups;
  final List<int> activeCombinerBoxes;
  final Map<int, String> pageOrientations;
  final String? clientId;
  final String? siteId;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Report({
    required this.id,
    required this.templateId,
    required this.title,
    required this.reportNumber,
    required this.contractNumber,
    required this.visitDate,
    this.visitTime = '09:30 ص',
    this.visitNumber = '1',
    this.showRightLogo,
    this.funderLogoBase64,
    this.funderNameAr,
    this.funderNameEn,
    this.contractorLogoBase64,
    this.contractorNameAr,
    this.contractorNameEn,
    this.contractorSubtitleAr,
    this.ministryLogoBase64,
    this.ministryNameAr,
    this.ministryNameEn,
    this.description = 'تقرير الصيانة الدورية الشاملة للمنظومة الشمسية',
    required this.projectInfo,
    required this.facilityInfo,
    required this.systemSpecs,
    required this.inspectionGroups,
    required this.batteryMeasurements,
    required this.operationalData,
    required this.stringMeasurements,
    required this.correctiveActions,
    required this.photos,
    required this.signatures,
    required this.approvalStatement,
    required this.attendanceList,
    this.showNeedsInReport = true,
    this.requestedNeeds = const [],
    this.activeBatteryGroups = const [1, 2, 3, 4],
    this.activeCombinerBoxes = const [1, 2, 3, 4],
    this.pageOrientations = const {},
    this.clientId,
    this.siteId,
    this.status = ReportStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculates the completion ratio of the overall report (0.0 to 1.0)
  double get completionRatio {
    int totalPoints = 0;
    int earnedPoints = 0;

    // Metadata points
    totalPoints += 5;
    if (title.isNotEmpty) earnedPoints++;
    if (reportNumber.isNotEmpty) earnedPoints++;
    if (contractNumber.isNotEmpty) earnedPoints++;
    if (projectInfo.projectName.isNotEmpty) earnedPoints++;
    if (facilityInfo.facilityName.isNotEmpty) earnedPoints++;

    // Inspection groups
    for (final group in inspectionGroups) {
      for (final item in group.items) {
        totalPoints++;
        if (item.status != InspectionStatus.uninspected) {
          earnedPoints++;
        }
      }
    }

    // Battery measurements
    if (batteryMeasurements.isNotEmpty) {
      totalPoints += 10;
      final measured = batteryMeasurements.where((b) => b.voltage > 0).length;
      earnedPoints += (measured * 10 / batteryMeasurements.length).round();
    }

    // Signatures
    totalPoints += 3;
    if (signatures.any((s) => s.signatureBase64 != null && s.signatureBase64!.isNotEmpty)) earnedPoints++;
    if (approvalStatement.beneficiarySignatureBase64 != null) earnedPoints++;
    if (approvalStatement.contractorSignatureBase64 != null) earnedPoints++;

    if (totalPoints == 0) return 1.0;
    return (earnedPoints / totalPoints).clamp(0.0, 1.0);
  }

  String get installationDate => facilityInfo.installationDate;

  /// Validation of missing fields before export
  List<String> validateMissingFields() {
    final missing = <String>[];
    if (projectInfo.projectName.trim().isEmpty) missing.add('اسم المشروع فارغ');
    if (facilityInfo.facilityName.trim().isEmpty) missing.add('اسم المنشأة الخدمية فارغ');
    if (contractNumber.trim().isEmpty) missing.add('رقم العقد غير محدد');
    if (visitDate.trim().isEmpty) missing.add('تاريخ الزيارة غير محدد');

    final uninspectedCount = inspectionGroups.fold<int>(
      0, (sum, g) => sum + g.items.where((i) => i.status == InspectionStatus.uninspected).length,
    );
    if (uninspectedCount > 0) {
      missing.add('يوجد $uninspectedCount بند فحص لم يتم تقييمه بعد');
    }

    final hasNoSig = signatures.every((s) => s.signatureBase64 == null || s.signatureBase64!.isEmpty);
    if (hasNoSig) {
      missing.add('لم يتم إضافة توقيع مهندس الصيانة بعد');
    }

    return missing;
  }

  /// Number of incomplete/missing fields in Phase 1 (Project & Facility Info)
  int get phase1IncompleteCount {
    int count = 0;
    if (projectInfo.projectName.trim().isEmpty) count++;
    if (facilityInfo.facilityName.trim().isEmpty) count++;
    if (contractNumber.trim().isEmpty) count++;
    if (visitDate.trim().isEmpty) count++;
    return count;
  }

  /// Number of incomplete/uninspected items in Phase 2 (Field Inspection)
  int get phase2IncompleteCount {
    return inspectionGroups.fold<int>(
      0, (sum, g) => sum + g.items.where((i) => i.status == InspectionStatus.uninspected).length,
    );
  }

  /// Number of incomplete/unmeasured cells in Phase 3 (Batteries & Operational Data)
  int get phase3IncompleteCount {
    int count = 0;
    for (final g in activeBatteryGroups) {
      final start = (g - 1) * 24;
      if (start < batteryMeasurements.length) {
        final cells = batteryMeasurements.skip(start).take(24);
        count += cells.where((c) => c.voltage <= 0).length;
      }
    }
    return count;
  }

  /// Number of items in Phase 4 (Needs & Requisitions for Next Visit)
  int get phase4NeedsCount => requestedNeeds.length;

  /// Number of missing signatures in Phase 5 (Signatures & Approval)
  int get phase5IncompleteCount {
    int count = 0;
    final hasEngSig = signatures.any((s) => s.signatureBase64 != null && s.signatureBase64!.isNotEmpty);
    if (!hasEngSig) count++;
    if (approvalStatement.beneficiarySignatureBase64 == null || approvalStatement.beneficiarySignatureBase64!.isEmpty) count++;
    if (approvalStatement.contractorSignatureBase64 == null || approvalStatement.contractorSignatureBase64!.isEmpty) count++;
    return count;
  }

  /// Number of missing signatures (alias for backwards compatibility)
  int get phase4IncompleteCount => phase5IncompleteCount;

  /// المحافظة المعتمدة للتقرير
  String get effectiveGovernorate {
    if (facilityInfo.governorate.trim().isNotEmpty) return facilityInfo.governorate.trim();
    if (projectInfo.governorate.trim().isNotEmpty) return projectInfo.governorate.trim();
    return '';
  }

  /// المديرية المعتمدة للتقرير
  String get effectiveDistrict {
    if (facilityInfo.directorate.trim().isNotEmpty) return facilityInfo.directorate.trim();
    if (projectInfo.district.trim().isNotEmpty) return projectInfo.district.trim();
    return '';
  }

  Report copyWith({
    String? title,
    String? reportNumber,
    String? contractNumber,
    String? visitDate,
    String? visitTime,
    String? visitNumber,
    bool? showRightLogo,
    String? funderLogoBase64,
    String? funderNameAr,
    String? funderNameEn,
    String? contractorLogoBase64,
    String? contractorNameAr,
    String? contractorNameEn,
    String? contractorSubtitleAr,
    String? ministryLogoBase64,
    String? ministryNameAr,
    String? ministryNameEn,
    bool clearFunderLogo = false,
    bool clearContractorLogo = false,
    bool clearMinistryLogo = false,
    String? description,
    ProjectInfo? projectInfo,
    FacilityInfo? facilityInfo,
    SystemSpecs? systemSpecs,
    List<InspectionGroup>? inspectionGroups,
    List<BatteryMeasurement>? batteryMeasurements,
    List<OperationalData>? operationalData,
    List<StringMeasurement>? stringMeasurements,
    List<CorrectiveAction>? correctiveActions,
    List<ReportPhoto>? photos,
    List<ReportSignature>? signatures,
    ApprovalStatement? approvalStatement,
    List<AttendanceRecord>? attendanceList,
    bool? showNeedsInReport,
    List<MaintenanceNeedItem>? requestedNeeds,
    List<int>? activeBatteryGroups,
    List<int>? activeCombinerBoxes,
    Map<int, String>? pageOrientations,
    String? clientId,
    String? siteId,
    ReportStatus? status,
    DateTime? updatedAt,
  }) {
    return Report(
      id: id,
      templateId: templateId,
      title: title ?? this.title,
      reportNumber: reportNumber ?? this.reportNumber,
      contractNumber: contractNumber ?? this.contractNumber,
      visitDate: visitDate ?? this.visitDate,
      visitTime: visitTime ?? this.visitTime,
      visitNumber: visitNumber ?? this.visitNumber,
      showRightLogo: showRightLogo ?? this.showRightLogo,
      funderLogoBase64: clearFunderLogo ? null : (funderLogoBase64 ?? this.funderLogoBase64),
      funderNameAr: funderNameAr ?? this.funderNameAr,
      funderNameEn: funderNameEn ?? this.funderNameEn,
      contractorLogoBase64: clearContractorLogo ? null : (contractorLogoBase64 ?? this.contractorLogoBase64),
      contractorNameAr: contractorNameAr ?? this.contractorNameAr,
      contractorNameEn: contractorNameEn ?? this.contractorNameEn,
      contractorSubtitleAr: contractorSubtitleAr ?? this.contractorSubtitleAr,
      ministryLogoBase64: clearMinistryLogo ? null : (ministryLogoBase64 ?? this.ministryLogoBase64),
      ministryNameAr: ministryNameAr ?? this.ministryNameAr,
      ministryNameEn: ministryNameEn ?? this.ministryNameEn,
      description: description ?? this.description,
      projectInfo: projectInfo ?? this.projectInfo,
      facilityInfo: facilityInfo ?? this.facilityInfo,
      systemSpecs: systemSpecs ?? this.systemSpecs,
      inspectionGroups: inspectionGroups ?? this.inspectionGroups,
      batteryMeasurements: batteryMeasurements ?? this.batteryMeasurements,
      operationalData: operationalData ?? this.operationalData,
      stringMeasurements: stringMeasurements ?? this.stringMeasurements,
      correctiveActions: correctiveActions ?? this.correctiveActions,
      photos: photos ?? this.photos,
      signatures: signatures ?? this.signatures,
      approvalStatement: approvalStatement ?? this.approvalStatement,
      attendanceList: attendanceList ?? this.attendanceList,
      showNeedsInReport: showNeedsInReport ?? this.showNeedsInReport,
      requestedNeeds: requestedNeeds ?? this.requestedNeeds,
      activeBatteryGroups: activeBatteryGroups ?? this.activeBatteryGroups,
      activeCombinerBoxes: activeCombinerBoxes ?? this.activeCombinerBoxes,
      pageOrientations: pageOrientations ?? this.pageOrientations,
      clientId: clientId ?? this.clientId,
      siteId: siteId ?? this.siteId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'templateId': templateId,
    'title': title,
    'reportNumber': reportNumber,
    'contractNumber': contractNumber,
    'visitDate': visitDate,
    'visitTime': visitTime,
    'visitNumber': visitNumber,
    'showRightLogo': showRightLogo,
    'funderLogoBase64': funderLogoBase64,
    'funderNameAr': funderNameAr,
    'funderNameEn': funderNameEn,
    'contractorLogoBase64': contractorLogoBase64,
    'contractorNameAr': contractorNameAr,
    'contractorNameEn': contractorNameEn,
    'contractorSubtitleAr': contractorSubtitleAr,
    'ministryLogoBase64': ministryLogoBase64,
    'ministryNameAr': ministryNameAr,
    'ministryNameEn': ministryNameEn,
    'description': description,
    'projectInfo': projectInfo.toJson(),
    'facilityInfo': facilityInfo.toJson(),
    'systemSpecs': systemSpecs.toJson(),
    'inspectionGroups': inspectionGroups.map((e) => e.toJson()).toList(),
    'batteryMeasurements': batteryMeasurements.map((e) => e.toJson()).toList(),
    'operationalData': operationalData.map((e) => e.toJson()).toList(),
    'stringMeasurements': stringMeasurements.map((e) => e.toJson()).toList(),
    'correctiveActions': correctiveActions.map((e) => e.toJson()).toList(),
    'photos': photos.map((e) => e.toJson()).toList(),
    'signatures': signatures.map((e) => e.toJson()).toList(),
    'approvalStatement': approvalStatement.toJson(),
    'attendanceList': attendanceList.map((e) => e.toJson()).toList(),
    'showNeedsInReport': showNeedsInReport,
    'requestedNeeds': requestedNeeds.map((e) => e.toJson()).toList(),
    'activeBatteryGroups': activeBatteryGroups,
    'activeCombinerBoxes': activeCombinerBoxes,
    'pageOrientations': pageOrientations.map((k, v) => MapEntry(k.toString(), v)),
    'clientId': clientId,
    'siteId': siteId,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'] ?? '',
    templateId: json['templateId'] ?? 'tmpl_solar_11p',
    title: json['title'] ?? 'تقرير الصيانة الدورية لمنظومة الطاقة الشمسية',
    reportNumber: json['reportNumber'] ?? 'REP-2025-001',
    contractNumber: json['contractNumber'] ?? '1010720',
    visitDate: json['visitDate'] ?? '2025/08/15',
    visitTime: json['visitTime'] ?? '09:30 ص',
    visitNumber: json['visitNumber'] ?? json['facilityInfo']?['visitNumber'] ?? '1',
    showRightLogo: json['showRightLogo'] as bool?,
    funderLogoBase64: json['funderLogoBase64'] as String?,
    funderNameAr: json['funderNameAr'] as String?,
    funderNameEn: json['funderNameEn'] as String?,
    contractorLogoBase64: json['contractorLogoBase64'] as String?,
    contractorNameAr: json['contractorNameAr'] as String?,
    contractorNameEn: json['contractorNameEn'] as String?,
    contractorSubtitleAr: json['contractorSubtitleAr'] as String?,
    ministryLogoBase64: json['ministryLogoBase64'] as String?,
    ministryNameAr: json['ministryNameAr'] as String?,
    ministryNameEn: json['ministryNameEn'] as String?,
    description: json['description'] ?? '',
    projectInfo: ProjectInfo.fromJson(json['projectInfo'] ?? {}),
    facilityInfo: FacilityInfo.fromJson(json['facilityInfo'] ?? {}),
    systemSpecs: SystemSpecs.fromJson(json['systemSpecs'] ?? {}),
    inspectionGroups: (json['inspectionGroups'] as List? ?? [])
        .map((e) => InspectionGroup.fromJson(e))
        .toList(),
    batteryMeasurements: (json['batteryMeasurements'] as List? ?? [])
        .map((e) => BatteryMeasurement.fromJson(e))
        .toList(),
    operationalData: (json['operationalData'] as List? ?? [])
        .map((e) => OperationalData.fromJson(e))
        .toList(),
    stringMeasurements: (json['stringMeasurements'] as List? ?? [])
        .map((e) => StringMeasurement.fromJson(e))
        .toList(),
    correctiveActions: (json['correctiveActions'] as List? ?? [])
        .map((e) => CorrectiveAction.fromJson(e))
        .toList(),
    photos: (json['photos'] as List? ?? [])
        .map((e) => ReportPhoto.fromJson(e))
        .toList(),
    signatures: (json['signatures'] as List? ?? [])
        .map((e) => ReportSignature.fromJson(e))
        .toList(),
    approvalStatement: ApprovalStatement.fromJson(json['approvalStatement'] ?? {}),
    attendanceList: (json['attendanceList'] as List? ?? [])
        .map((e) => AttendanceRecord.fromJson(e))
        .toList(),
    showNeedsInReport: json['showNeedsInReport'] as bool? ?? true,
    requestedNeeds: (json['requestedNeeds'] as List? ?? [])
        .map((e) => MaintenanceNeedItem.fromJson(e))
        .toList(),
    activeBatteryGroups: (json['activeBatteryGroups'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 2, 3, 4],
    activeCombinerBoxes: (json['activeCombinerBoxes'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 2, 3, 4],
    pageOrientations: json['pageOrientations'] != null
        ? (json['pageOrientations'] as Map).map(
            (k, v) => MapEntry(int.tryParse(k.toString()) ?? 1, v.toString()),
          )
        : const {},
    clientId: json['clientId'] as String?,
    siteId: json['siteId'] as String?,
    status: ReportStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => ReportStatus.draft,
    ),
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
  );
}
