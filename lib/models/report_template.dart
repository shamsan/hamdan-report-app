import 'report.dart';
import 'signature_data.dart';
import '../services/default_templates.dart';

enum ElementType {
  header,
  richText,
  logoImage,
  table,
  inspectionTable,
  measurementTable,
  signatureBox,
  approvalStatement,
  photoGrid,
  divider,
}

class PageElement {
  final String id;
  final ElementType type;
  final String title;
  final Map<String, dynamic> config;

  const PageElement({
    required this.id,
    required this.type,
    required this.title,
    this.config = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'config': config,
  };

  factory PageElement.fromJson(Map<String, dynamic> json) => PageElement(
    id: json['id'] ?? '',
    type: ElementType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ElementType.richText,
    ),
    title: json['title'] ?? '',
    config: json['config'] ?? {},
  );
}

class TemplatePage {
  final int pageNumber;
  final String title;
  final bool isLandscape;
  final List<PageElement> elements;

  const TemplatePage({
    required this.pageNumber,
    required this.title,
    this.isLandscape = false,
    this.elements = const [],
  });

  TemplatePage copyWith({
    String? title,
    bool? isLandscape,
    List<PageElement>? elements,
  }) {
    return TemplatePage(
      pageNumber: pageNumber,
      title: title ?? this.title,
      isLandscape: isLandscape ?? this.isLandscape,
      elements: elements ?? this.elements,
    );
  }

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'title': title,
    'isLandscape': isLandscape,
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  factory TemplatePage.fromJson(Map<String, dynamic> json) => TemplatePage(
    pageNumber: json['pageNumber'] ?? 1,
    title: json['title'] ?? '',
    isLandscape: json['isLandscape'] ?? false,
    elements: (json['elements'] as List? ?? [])
        .map((e) => PageElement.fromJson(e))
        .toList(),
  );
}

class ReportTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final bool isDefault;
  final bool isLocked;
  final List<TemplatePage> pages;
  final DateTime updatedAt;

  const ReportTemplate({
    required this.id,
    required this.title,
    required this.description,
    this.category = 'طاقة شمسية',
    this.isDefault = false,
    this.isLocked = false,
    required this.pages,
    required this.updatedAt,
  });

  int get pagesCount => pages.length;
  String get contractorName => 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة';
  Report instantiateReport({
    String? facilityName,
    String? contractNo,
    ProjectInfo? projectInfo,
    FacilityInfo? facilityInfo,
    SystemSpecs? systemSpecs,
    List<int>? activeBatteryGroups,
    List<int>? activeCombinerBoxes,
  }) {
    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    return Report(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      templateId: id,
      title: facilityName != null && facilityName.isNotEmpty
          ? 'تقرير صيانة - $facilityName'
          : 'تقرير صيانة دورية لمنظومة الطاقة الشمسية',
      reportNumber: 'REP-${now.year}-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}',
      contractNumber: contractNo ?? '',
      visitDate: dateStr,
      visitTime: '09:00 ص',
      description: 'تقرير الصيانة الدورية لمنظومة الطاقة الشمسية',
      projectInfo: projectInfo ?? const ProjectInfo(),
      facilityInfo: facilityInfo ??
          FacilityInfo(
            facilityName: facilityName ?? '',
          ),
      systemSpecs: systemSpecs ?? const SystemSpecs(),
      inspectionGroups: DefaultTemplates.blankInspectionGroups,
      batteryMeasurements: DefaultTemplates.blankBatteryMeasurements,
      operationalData: DefaultTemplates.blankOperationalData,
      stringMeasurements: DefaultTemplates.blankStringMeasurements,
      correctiveActions: const [],
      photos: const [],
      signatures: const [],
      approvalStatement: ApprovalStatement(),
      attendanceList: const [],
      activeBatteryGroups: activeBatteryGroups ?? const [1, 2, 3, 4],
      activeCombinerBoxes: activeCombinerBoxes ?? const [1, 2, 3, 4],
      status: ReportStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  ReportTemplate copyWith({
    String? title,
    String? description,
    String? category,
    bool? isDefault,
    bool? isLocked,
    List<TemplatePage>? pages,
    DateTime? updatedAt,
  }) {
    return ReportTemplate(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      isDefault: isDefault ?? this.isDefault,
      isLocked: isLocked ?? this.isLocked,
      pages: pages ?? this.pages,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'isDefault': isDefault,
    'isLocked': isLocked,
    'pages': pages.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ReportTemplate.fromJson(Map<String, dynamic> json) => ReportTemplate(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    category: json['category'] ?? '',
    isDefault: json['isDefault'] ?? false,
    isLocked: json['isLocked'] ?? false,
    pages: (json['pages'] as List? ?? [])
        .map((e) => TemplatePage.fromJson(e))
        .toList(),
    updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
  );
}
