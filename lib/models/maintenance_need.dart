import 'package:flutter/material.dart';

/// درجة أهمية المادة أو قطعة الغيار المطلوبة
enum NeedPriority {
  normal,    // عادية: صيانة وقائية أو استباقية
  urgent,    // عاجلة: تدهور في الأداء أو كفاءة جزئية
  critical,  // حرجة: توقف تام للمنظومة أو خطر كهربائي/أمني
}

extension NeedPriorityX on NeedPriority {
  String get labelAr {
    switch (this) {
      case NeedPriority.normal: return 'عادية';
      case NeedPriority.urgent: return 'عاجلة';
      case NeedPriority.critical: return 'حرجة';
    }
  }

  Color get color {
    switch (this) {
      case NeedPriority.normal: return const Color(0xFF2E7D32); // Green
      case NeedPriority.urgent: return const Color(0xFFED6C02); // Orange
      case NeedPriority.critical: return const Color(0xFFD32F2F); // Red
    }
  }

  Color get backgroundColor {
    switch (this) {
      case NeedPriority.normal: return const Color(0xFFE8F5E9);
      case NeedPriority.urgent: return const Color(0xFFFFF3E0);
      case NeedPriority.critical: return const Color(0xFFFFEBEE);
    }
  }

  IconData get icon {
    switch (this) {
      case NeedPriority.normal: return Icons.info_outline;
      case NeedPriority.urgent: return Icons.warning_amber_rounded;
      case NeedPriority.critical: return Icons.error_outline_rounded;
    }
  }
}

/// دورة حياة الاحتياج عبر الزيارات
enum NeedStatus {
  requested,  // تم طلبها في الزيارة الحالية للزيارة القادمة
  supplied,   // تم توفيرها من المخزن / جاهزة في السيارة
  installed,  // تم تركيبها واختبارها بنجاح في الموقع
  cancelled,  // تم إلغاؤها لعدم الحاجة أو توفر بديل
}

extension NeedStatusX on NeedStatus {
  String get labelAr {
    switch (this) {
      case NeedStatus.requested: return 'مطلوبة';
      case NeedStatus.supplied: return 'تم التوفير';
      case NeedStatus.installed: return 'تم التركيب';
      case NeedStatus.cancelled: return 'ملغية';
    }
  }

  Color get color {
    switch (this) {
      case NeedStatus.requested: return const Color(0xFF0288D1); // Blue
      case NeedStatus.supplied: return const Color(0xFF7B1FA2); // Purple
      case NeedStatus.installed: return const Color(0xFF2E7D32); // Green
      case NeedStatus.cancelled: return const Color(0xFF78909C); // Grey
    }
  }

  IconData get icon {
    switch (this) {
      case NeedStatus.requested: return Icons.schedule_rounded;
      case NeedStatus.supplied: return Icons.inventory_2_outlined;
      case NeedStatus.installed: return Icons.check_circle_rounded;
      case NeedStatus.cancelled: return Icons.cancel_outlined;
    }
  }
}

class MaintenanceNeedItem {
  final String id;
  final String facilityName;
  final String currentVisitNumber;
  final String targetVisitNumber;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final NeedPriority priority;
  final String reason;
  final String? relatedInspectionItemId;
  final String? relatedInspectionItemTitle;
  final String? photoBase64;
  final NeedStatus status;
  final bool includeInPdf;
  final DateTime createdAt;
  final DateTime? installedAt;

  const MaintenanceNeedItem({
    required this.id,
    required this.facilityName,
    required this.currentVisitNumber,
    required this.targetVisitNumber,
    required this.name,
    required this.quantity,
    this.unit = 'حبة',
    this.category = 'عام',
    this.priority = NeedPriority.normal,
    this.reason = '',
    this.relatedInspectionItemId,
    this.relatedInspectionItemTitle,
    this.photoBase64,
    this.status = NeedStatus.requested,
    this.includeInPdf = true,
    required this.createdAt,
    this.installedAt,
  });

  MaintenanceNeedItem copyWith({
    String? id,
    String? facilityName,
    String? currentVisitNumber,
    String? targetVisitNumber,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    NeedPriority? priority,
    String? reason,
    String? relatedInspectionItemId,
    String? relatedInspectionItemTitle,
    String? photoBase64,
    NeedStatus? status,
    bool? includeInPdf,
    DateTime? createdAt,
    DateTime? installedAt,
    bool clearPhoto = false,
  }) {
    return MaintenanceNeedItem(
      id: id ?? this.id,
      facilityName: facilityName ?? this.facilityName,
      currentVisitNumber: currentVisitNumber ?? this.currentVisitNumber,
      targetVisitNumber: targetVisitNumber ?? this.targetVisitNumber,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      reason: reason ?? this.reason,
      relatedInspectionItemId: relatedInspectionItemId ?? this.relatedInspectionItemId,
      relatedInspectionItemTitle: relatedInspectionItemTitle ?? this.relatedInspectionItemTitle,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      status: status ?? this.status,
      includeInPdf: includeInPdf ?? this.includeInPdf,
      createdAt: createdAt ?? this.createdAt,
      installedAt: installedAt ?? this.installedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'facilityName': facilityName,
    'currentVisitNumber': currentVisitNumber,
    'targetVisitNumber': targetVisitNumber,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'category': category,
    'priority': priority.name,
    'reason': reason,
    'relatedInspectionItemId': relatedInspectionItemId,
    'relatedInspectionItemTitle': relatedInspectionItemTitle,
    'photoBase64': photoBase64,
    'status': status.name,
    'includeInPdf': includeInPdf,
    'createdAt': createdAt.toIso8601String(),
    'installedAt': installedAt?.toIso8601String(),
  };

  factory MaintenanceNeedItem.fromJson(Map<String, dynamic> json) => MaintenanceNeedItem(
    id: json['id'] ?? '',
    facilityName: json['facilityName'] ?? '',
    currentVisitNumber: json['currentVisitNumber'] ?? '1',
    targetVisitNumber: json['targetVisitNumber'] ?? '2',
    name: json['name'] ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unit: json['unit'] ?? 'حبة',
    category: json['category'] ?? 'عام',
    priority: NeedPriority.values.firstWhere(
      (p) => p.name == json['priority'],
      orElse: () => NeedPriority.normal,
    ),
    reason: json['reason'] ?? '',
    relatedInspectionItemId: json['relatedInspectionItemId'],
    relatedInspectionItemTitle: json['relatedInspectionItemTitle'],
    photoBase64: json['photoBase64'],
    status: NeedStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => NeedStatus.requested,
    ),
    includeInPdf: json['includeInPdf'] as bool? ?? true,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    installedAt: json['installedAt'] != null ? DateTime.tryParse(json['installedAt']) : null,
  );
}
