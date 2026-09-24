import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum PhotoPlacement {
  grid,             // شبكة صور
  standalonePage,   // صفحة صور مستقلة
  appendix,         // ملحق نهاية التقرير
}

enum PhotoDisplaySize {
  halfWidth,   // نصف سطر (صورتان في السطر 50%) - الافتراضي
  fullWidth,   // سطر كامل (عرض كامل 100%)
  compact,     // ثلث سطر (3 صور في السطر 33%)
  beforeAfter, // زوج مقارنة قبل وبعد
}

class ReportPhoto {
  final String id;
  final String? filePath;
  final String base64Data;
  final String title;
  final String caption;
  final String location;
  final String timestamp;
  final PhotoPlacement placement;
  final bool isLandscape; // true: أفقي (عرض كامل الصفحة), false: عمودي (شبكي نصف صفحة)
  final PhotoDisplaySize displaySize;
  final String beforeAfterStage; // 'none', 'before', 'after'
  final double widthFactor; // 0.33 .. 1.0 (سحب العرض: 33% حتى 100%)

  const ReportPhoto({
    required this.id,
    this.filePath,
    this.base64Data = '',
    this.title = '',
    this.caption = '',
    this.location = '',
    this.timestamp = '',
    this.placement = PhotoPlacement.grid,
    this.isLandscape = false,
    this.displaySize = PhotoDisplaySize.halfWidth,
    this.beforeAfterStage = 'none',
    this.widthFactor = 0.5,
  });

  static Uint8List? _safeDecode(String raw) {
    if (raw.isEmpty) return null;
    var cleaned = raw.trim();
    if (cleaned.contains(',')) {
      cleaned = cleaned.substring(cleaned.indexOf(',') + 1).trim();
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return null;
    final remainder = cleaned.length % 4;
    if (remainder > 0) {
      cleaned = cleaned.padRight(cleaned.length + (4 - remainder), '=');
    }
    try {
      final bytes = base64Decode(cleaned);
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the binary bytes of the photo from disk or decodes from base64
  Future<Uint8List?> getBytes() async {
    if (filePath != null && filePath!.isNotEmpty) {
      final f = File(filePath!);
      if (await f.exists()) {
        try {
          return await f.readAsBytes();
        } catch (_) {}
      }
    }
    if (base64Data.isNotEmpty) {
      return _safeDecode(base64Data);
    }
    return null;
  }

  /// Synchronous byte retrieval when bytes are needed immediately
  Uint8List? getBytesSync() {
    if (filePath != null && filePath!.isNotEmpty) {
      final f = File(filePath!);
      if (f.existsSync()) {
        try {
          return f.readAsBytesSync();
        } catch (_) {}
      }
    }
    if (base64Data.isNotEmpty) {
      return _safeDecode(base64Data);
    }
    return null;
  }

  ReportPhoto copyWith({
    String? filePath,
    String? base64Data,
    String? title,
    String? caption,
    String? location,
    PhotoPlacement? placement,
    bool? isLandscape,
    PhotoDisplaySize? displaySize,
    String? beforeAfterStage,
    double? widthFactor,
  }) {
    final effectiveDisplaySize = displaySize ?? this.displaySize;
    final effectiveWidthFactor = widthFactor ??
        (displaySize != null
            ? (effectiveDisplaySize == PhotoDisplaySize.fullWidth
                ? 1.0
                : (effectiveDisplaySize == PhotoDisplaySize.compact ? 0.33 : 0.5))
            : this.widthFactor);

    return ReportPhoto(
      id: id,
      filePath: filePath ?? this.filePath,
      base64Data: base64Data ?? this.base64Data,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      timestamp: timestamp,
      placement: placement ?? this.placement,
      isLandscape: isLandscape ?? (effectiveDisplaySize == PhotoDisplaySize.fullWidth || effectiveWidthFactor >= 0.85),
      displaySize: effectiveDisplaySize,
      beforeAfterStage: beforeAfterStage ?? this.beforeAfterStage,
      widthFactor: effectiveWidthFactor,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'filePath': filePath,
    'base64Data': base64Data,
    'title': title,
    'caption': caption,
    'location': location,
    'timestamp': timestamp,
    'placement': placement.name,
    'isLandscape': isLandscape,
    'displaySize': displaySize.name,
    'beforeAfterStage': beforeAfterStage,
    'widthFactor': widthFactor,
  };

  factory ReportPhoto.fromJson(Map<String, dynamic> json) {
    final legacyLandscape = json['isLandscape'] == true;
    final displaySize = json['displaySize'] != null
        ? PhotoDisplaySize.values.firstWhere(
            (e) => e.name == json['displaySize'],
            orElse: () => legacyLandscape ? PhotoDisplaySize.fullWidth : PhotoDisplaySize.halfWidth,
          )
        : (legacyLandscape ? PhotoDisplaySize.fullWidth : PhotoDisplaySize.halfWidth);

    final rawWidth = (json['widthFactor'] as num?)?.toDouble();
    final defaultWidth = displaySize == PhotoDisplaySize.fullWidth
        ? 1.0
        : (displaySize == PhotoDisplaySize.compact ? 0.33 : 0.5);

    return ReportPhoto(
      id: json['id'] ?? '',
      filePath: json['filePath'],
      base64Data: json['base64Data'] ?? '',
      title: json['title'] ?? '',
      caption: json['caption'] ?? '',
      location: json['location'] ?? '',
      timestamp: json['timestamp'] ?? '',
      placement: PhotoPlacement.values.firstWhere(
        (e) => e.name == json['placement'],
        orElse: () => PhotoPlacement.grid,
      ),
      isLandscape: json['isLandscape'] ?? (displaySize == PhotoDisplaySize.fullWidth),
      displaySize: displaySize,
      beforeAfterStage: json['beforeAfterStage'] ?? 'none',
      widthFactor: rawWidth ?? defaultWidth,
    );
  }
}
