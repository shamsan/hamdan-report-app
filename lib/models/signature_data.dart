class ReportSignature {
  final String id;
  final String role;         // e.g. مهندس الصيانة، ممثل المستفيد، مدير المنشأة
  final String signerName;
  final String jobTitle;
  final String? signatureBase64;
  final String signedDate;

  const ReportSignature({
    required this.id,
    required this.role,
    this.signerName = '',
    this.jobTitle = '',
    this.signatureBase64,
    this.signedDate = '',
  });

  ReportSignature copyWith({
    String? signerName,
    String? jobTitle,
    String? signatureBase64,
    String? signedDate,
  }) {
    return ReportSignature(
      id: id,
      role: role,
      signerName: signerName ?? this.signerName,
      jobTitle: jobTitle ?? this.jobTitle,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      signedDate: signedDate ?? this.signedDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'signerName': signerName,
    'jobTitle': jobTitle,
    'signatureBase64': signatureBase64,
    'signedDate': signedDate,
  };

  factory ReportSignature.fromJson(Map<String, dynamic> json) => ReportSignature(
    id: json['id'] ?? '',
    role: json['role'] ?? '',
    signerName: json['signerName'] ?? '',
    jobTitle: json['jobTitle'] ?? '',
    signatureBase64: json['signatureBase64'],
    signedDate: json['signedDate'] ?? '',
  );
}

class AttendanceRecord {
  final int serialNo;
  final String name;
  final String role;         // مهندس / فني / مسؤول
  final String affiliation;  // الشركة المنفذة / المرفق
  final String? signatureBase64;
  final String notes;

  const AttendanceRecord({
    required this.serialNo,
    required this.name,
    required this.role,
    required this.affiliation,
    this.signatureBase64,
    this.notes = '',
  });

  AttendanceRecord copyWith({
    String? name,
    String? role,
    String? affiliation,
    String? signatureBase64,
    String? notes,
  }) {
    return AttendanceRecord(
      serialNo: serialNo,
      name: name ?? this.name,
      role: role ?? this.role,
      affiliation: affiliation ?? this.affiliation,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'serialNo': serialNo,
    'name': name,
    'role': role,
    'affiliation': affiliation,
    'signatureBase64': signatureBase64,
    'notes': notes,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
    serialNo: json['serialNo'] ?? 1,
    name: json['name'] ?? '',
    role: json['role'] ?? '',
    affiliation: json['affiliation'] ?? '',
    signatureBase64: json['signatureBase64'],
    notes: json['notes'] ?? '',
  );
}

class ApprovalStatement {
  final String projectTitle;
  final String facilityName;
  final String statementText;
  final String beneficiaryRepName;
  final String beneficiaryRepNameEn;
  final String beneficiaryRepRole;
  final String beneficiaryRepRoleEn;
  final String contractorRepName;
  final String contractorRepRole;
  final String approvalDate;
  final String? stampBase64;
  final String? beneficiarySignatureBase64;
  final String? contractorSignatureBase64;

  const ApprovalStatement({
    this.projectTitle = 'مشروع توريد وتركيب وصيانة منظومات الطاقة الشمسية',
    this.facilityName = 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
    this.statementText = 'نقر نحن ممثلي الجهة المستفيدة وإدارة المنشأة بأن فريق الصيانة التابع للجهة المنفذة قد قام بتنفيذ جميع أعمال الصيانة الدورية والفحوصات الفنية الموضحة في هذا التقرير، وقد تم التأكد من تشغيل المنظومة بكفاءة وانتظام.',
    this.beneficiaryRepName = 'د. عبد الله أحمد',
    this.beneficiaryRepNameEn = '',
    this.beneficiaryRepRole = 'مدير المركز الصحي',
    this.beneficiaryRepRoleEn = '',
    this.contractorRepName = 'م. أحمد سعيد العنسي',
    this.contractorRepRole = 'مهندس الصيانة المسؤول',
    this.approvalDate = '2025/08/15',
    this.stampBase64,
    this.beneficiarySignatureBase64,
    this.contractorSignatureBase64,
  });

  ApprovalStatement copyWith({
    String? projectTitle,
    String? facilityName,
    String? statementText,
    String? beneficiaryRepName,
    String? beneficiaryRepNameEn,
    String? beneficiaryRepRole,
    String? beneficiaryRepRoleEn,
    String? contractorRepName,
    String? contractorRepRole,
    String? approvalDate,
    String? stampBase64,
    String? beneficiarySignatureBase64,
    String? contractorSignatureBase64,
  }) {
    return ApprovalStatement(
      projectTitle: projectTitle ?? this.projectTitle,
      facilityName: facilityName ?? this.facilityName,
      statementText: statementText ?? this.statementText,
      beneficiaryRepName: beneficiaryRepName ?? this.beneficiaryRepName,
      beneficiaryRepNameEn: beneficiaryRepNameEn ?? this.beneficiaryRepNameEn,
      beneficiaryRepRole: beneficiaryRepRole ?? this.beneficiaryRepRole,
      beneficiaryRepRoleEn: beneficiaryRepRoleEn ?? this.beneficiaryRepRoleEn,
      contractorRepName: contractorRepName ?? this.contractorRepName,
      contractorRepRole: contractorRepRole ?? this.contractorRepRole,
      approvalDate: approvalDate ?? this.approvalDate,
      stampBase64: stampBase64 ?? this.stampBase64,
      beneficiarySignatureBase64: beneficiarySignatureBase64 ?? this.beneficiarySignatureBase64,
      contractorSignatureBase64: contractorSignatureBase64 ?? this.contractorSignatureBase64,
    );
  }

  Map<String, dynamic> toJson() => {
    'projectTitle': projectTitle,
    'facilityName': facilityName,
    'statementText': statementText,
    'beneficiaryRepName': beneficiaryRepName,
    'beneficiaryRepNameEn': beneficiaryRepNameEn,
    'beneficiaryRepRole': beneficiaryRepRole,
    'beneficiaryRepRoleEn': beneficiaryRepRoleEn,
    'contractorRepName': contractorRepName,
    'contractorRepRole': contractorRepRole,
    'approvalDate': approvalDate,
    'stampBase64': stampBase64,
    'beneficiarySignatureBase64': beneficiarySignatureBase64,
    'contractorSignatureBase64': contractorSignatureBase64,
  };

  factory ApprovalStatement.fromJson(Map<String, dynamic> json) => ApprovalStatement(
    projectTitle: json['projectTitle'] ?? '',
    facilityName: json['facilityName'] ?? '',
    statementText: json['statementText'] ?? '',
    beneficiaryRepName: json['beneficiaryRepName'] ?? '',
    beneficiaryRepNameEn: json['beneficiaryRepNameEn'] ?? '',
    beneficiaryRepRole: json['beneficiaryRepRole'] ?? '',
    beneficiaryRepRoleEn: json['beneficiaryRepRoleEn'] ?? '',
    contractorRepName: json['contractorRepName'] ?? '',
    contractorRepRole: json['contractorRepRole'] ?? '',
    approvalDate: json['approvalDate'] ?? '',
    stampBase64: json['stampBase64'],
    beneficiarySignatureBase64: json['beneficiarySignatureBase64'],
    contractorSignatureBase64: json['contractorSignatureBase64'],
  );
}
