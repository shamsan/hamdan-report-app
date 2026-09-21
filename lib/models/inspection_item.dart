import 'package:flutter/material.dart';

enum InspectionStatus {
  good,           // جيد
  acceptable,     // مقبول
  needsFollowup,  // يحتاج متابعة
  rejected,       // مرفوض
  notApplicable,  // غير منطبق
  uninspected,    // لم يتم الفحص
}

extension InspectionStatusX on InspectionStatus {
  String get labelAr {
    switch (this) {
      case InspectionStatus.good: return 'جيد';
      case InspectionStatus.acceptable: return 'مقبول';
      case InspectionStatus.needsFollowup: return 'يحتاج متابعة';
      case InspectionStatus.rejected: return 'مرفوض';
      case InspectionStatus.notApplicable: return 'غير منطبق';
      case InspectionStatus.uninspected: return 'لم يُفحص';
    }
  }

  Color get color {
    switch (this) {
      case InspectionStatus.good: return const Color(0xFF2E7D32);
      case InspectionStatus.acceptable: return const Color(0xFF0288D1);
      case InspectionStatus.needsFollowup: return const Color(0xFFED6C02);
      case InspectionStatus.rejected: return const Color(0xFFD32F2F);
      case InspectionStatus.notApplicable: return const Color(0xFF78909C);
      case InspectionStatus.uninspected: return const Color(0xFF9E9E9E);
    }
  }

  IconData get icon {
    switch (this) {
      case InspectionStatus.good: return Icons.check_circle_outline;
      case InspectionStatus.acceptable: return Icons.thumb_up_alt_outlined;
      case InspectionStatus.needsFollowup: return Icons.warning_amber_outlined;
      case InspectionStatus.rejected: return Icons.cancel_outlined;
      case InspectionStatus.notApplicable: return Icons.remove_circle_outline;
      case InspectionStatus.uninspected: return Icons.help_outline;
    }
  }
}

class InspectionItem {
  final String id;
  final int serialNo;
  final String description;
  final InspectionStatus status;
  final String notes;
  final String? photoBase64;
  final String priority; // Normal, High, Urgent
  final String? subcategory; // e.g. 'صندوق قواطع البطاريات (DC)'

  const InspectionItem({
    required this.id,
    required this.serialNo,
    required this.description,
    this.status = InspectionStatus.good,
    this.notes = '',
    this.photoBase64,
    this.priority = 'Normal',
    this.subcategory,
  });

  InspectionItem copyWith({
    InspectionStatus? status,
    String? notes,
    String? photoBase64,
    String? priority,
    String? subcategory,
  }) {
    return InspectionItem(
      id: id,
      serialNo: serialNo,
      description: description,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      photoBase64: photoBase64 ?? this.photoBase64,
      priority: priority ?? this.priority,
      subcategory: subcategory ?? this.subcategory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'serialNo': serialNo,
    'description': description,
    'status': status.name,
    'notes': notes,
    'photoBase64': photoBase64,
    'priority': priority,
    'subcategory': subcategory,
  };

  factory InspectionItem.fromJson(Map<String, dynamic> json) => InspectionItem(
    id: json['id'] ?? '',
    serialNo: json['serialNo'] ?? 1,
    description: json['description'] ?? '',
    status: InspectionStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => InspectionStatus.good,
    ),
    notes: json['notes'] ?? '',
    photoBase64: json['photoBase64'],
    priority: json['priority'] ?? 'Normal',
    subcategory: json['subcategory'] ?? _defaultSubcategoryForId(json['id']),
  );

  static String? _defaultSubcategoryForId(dynamic id) {
    if (id == null) return null;
    final str = id.toString();
    if (str.startsWith('g4_')) {
      final numStr = str.replaceFirst('g4_', '');
      final num = int.tryParse(numStr);
      if (num != null) {
        if (num >= 1 && num <= 7) return 'صندوق قواطع البطاريات "تيار مستمر"';
        if (num >= 8 && num <= 14) return 'صندوق قواطع العاكس "تيار مستمر"';
        if (num >= 15 && num <= 21) return 'صندوق تجميع كابلات التيار المستمر';
        if (num >= 22 && num <= 28) return 'صندوق دمج وقواطع حماية التيار المتردد';
        if (num >= 29 && num <= 35) return 'لوحة التوزيع الرئيسية';
        if (num >= 36 && num <= 42) return 'مفتاح تبديل يدوي لمصدر الطاقة';
      }
    } else if (str.startsWith('g7_')) {
      final numStr = str.replaceFirst('g7_', '');
      final num = int.tryParse(numStr);
      if (num != null) {
        if (num >= 1 && num <= 3) return 'نظام التهوية وتكييف الغرفة';
        if (num >= 4 && num <= 7) return 'نظام إنذار ومكافحة الحرائق والسلامة';
        if (num >= 8 && num <= 13) return 'نظام المراقبة والمتابعة';
      }
    }
    return null;
  }
}

class InspectionGroup {
  final String id;
  final int groupNumber;
  final String title;
  final String? subtitle;
  final List<InspectionItem> items;

  const InspectionGroup({
    required this.id,
    required this.groupNumber,
    required this.title,
    this.subtitle,
    required this.items,
  });

  double get completionRatio {
    if (items.isEmpty) return 1.0;
    final inspectedCount = items.where((i) => i.status != InspectionStatus.uninspected).length;
    return inspectedCount / items.length;
  }

  InspectionGroup copyWith({
    String? title,
    String? subtitle,
    List<InspectionItem>? items,
  }) {
    return InspectionGroup(
      id: id,
      groupNumber: groupNumber,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupNumber': groupNumber,
    'title': title,
    'subtitle': subtitle,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory InspectionGroup.fromJson(Map<String, dynamic> json) => InspectionGroup(
    id: json['id'] ?? '',
    groupNumber: json['groupNumber'] ?? 1,
    title: json['title'] ?? '',
    subtitle: json['subtitle'],
    items: (json['items'] as List? ?? [])
        .map((e) => InspectionItem.fromJson(e))
        .toList(),
  );
}
