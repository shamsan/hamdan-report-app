import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum PhotoPlacement {
  grid,             // شبكة صور
  standalonePage,   // صفحة صور مستقلة
  appendix,         // ملحق نهاية التقرير
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
  }) {
    return ReportPhoto(
      id: id,
      filePath: filePath ?? this.filePath,
      base64Data: base64Data ?? this.base64Data,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      timestamp: timestamp,
      placement: placement ?? this.placement,
      isLandscape: isLandscape ?? this.isLandscape,
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
  };

  factory ReportPhoto.fromJson(Map<String, dynamic> json) => ReportPhoto(
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
    isLandscape: json['isLandscape'] ?? false,
  );
}
