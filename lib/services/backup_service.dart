import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

class BackupInspectionResult {
  final bool isValid;
  final int reportCount;
  final int templateCount;
  final int clientCount;
  final int siteCount;
  final int photosCount;
  final String exportedAt;
  final String version;
  final String rawJson;
  final List<int>? rawZipBytes;
  final bool isArchive;
  final String errorMessage;

  const BackupInspectionResult({
    required this.isValid,
    this.reportCount = 0,
    this.templateCount = 0,
    this.clientCount = 0,
    this.siteCount = 0,
    this.photosCount = 0,
    this.exportedAt = '',
    this.version = '',
    this.rawJson = '',
    this.rawZipBytes,
    this.isArchive = false,
    this.errorMessage = '',
  });
}

class BackupService {
  static const String _keyLastBackup = 'reportcraft_last_backup_time';

  /// 1. تصدير حزمة أرشيف شاملة (.rcbackup) مع كافة الصور وقاعدة البيانات وحفظها محلياً
  static Future<String> exportArchiveLocalFile() async {
    final storage = StorageService();
    final zipBytes = await storage.exportFullArchiveZip();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'reportcraft_archive_$dateStr.rcbackup';

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(zipBytes, flush: true);

    await _recordBackupTime(now);
    return file.path;
  }

  /// 2. تصدير ومشاركة حزمة الأرشيف الشاملة مع كافة الصور مباشرة عبر التطبيقات
  static Future<void> exportAndShareArchive() async {
    final storage = StorageService();
    final zipBytes = await storage.exportFullArchiveZip();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileName = 'reportcraft_archive_$dateStr.rcbackup';

    await Printing.sharePdf(bytes: Uint8List.fromList(zipBytes), filename: fileName);
    await _recordBackupTime(now);
  }

  /// 3. تصدير ملف JSON خفيف (بيانات وقوالب فقط) وحفظه في الذاكرة
  static Future<String> exportLocalFile() async {
    final storage = StorageService();
    final jsonStr = await storage.exportFullBackup();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'reportcraft_backup_$dateStr.json';

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr);

    await _recordBackupTime(now);
    return file.path;
  }

  /// 4. تصدير ومشاركة ملف JSON خفيف
  static Future<void> exportAndShare() async {
    final storage = StorageService();
    final jsonStr = await storage.exportFullBackup();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileName = 'reportcraft_backup_$dateStr.json';

    final bytes = utf8.encode(jsonStr);
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    await _recordBackupTime(now);
  }

  /// 5. فحص ومعاينة ملف النسخة الاحتياطية (يدعم .rcbackup, .zip, .json تلقائياً)
  static Future<BackupInspectionResult> pickAndInspectBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return const BackupInspectionResult(
          isValid: false,
          errorMessage: 'لم يتم اختيار أي ملف',
        );
      }

      final pickedFile = result.files.first;
      List<int>? rawBytes;

      if (pickedFile.bytes != null) {
        rawBytes = pickedFile.bytes;
      } else if (pickedFile.path != null) {
        final file = File(pickedFile.path!);
        rawBytes = await file.readAsBytes();
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        return const BackupInspectionResult(
          isValid: false,
          errorMessage: 'تعذر قراءة بيانات الملف المختار أو الملف فارغ',
        );
      }

      final name = (pickedFile.name).toLowerCase();
      // تحقق هل الملف حزمة مضغوطة (ZIP magic header: PK\x03\x04 أو الامتداد)
      final isZip = (rawBytes.length >= 4 &&
              rawBytes[0] == 0x50 &&
              rawBytes[1] == 0x4B &&
              rawBytes[2] == 0x03 &&
              rawBytes[3] == 0x04) ||
          name.endsWith('.rcbackup') ||
          name.endsWith('.zip');

      if (isZip) {
        final archive = ZipDecoder().decodeBytes(rawBytes);
        ArchiveFile? dbFile;
        int photoCount = 0;

        for (final file in archive) {
          if (file.name == 'database.json') {
            dbFile = file;
          } else if (file.name.startsWith('photos/') && !file.isDirectory) {
            photoCount++;
          }
        }

        if (dbFile == null) {
          return const BackupInspectionResult(
            isValid: false,
            errorMessage: 'حزمة الأرشيف لا تحتوي على ملف قاعدة البيانات database.json',
          );
        }

        final content = utf8.decode(dbFile.content as List<int>);
        final Map<String, dynamic> data = jsonDecode(content);

        final reportsList = (data['reports'] as List? ?? []);
        final templatesList = (data['templates'] as List? ?? []);
        final clientsList = (data['clients'] as List? ?? []);
        final sitesList = (data['sites'] as List? ?? []);
        final exportedAt = data['exportedAt']?.toString() ?? 'غير محدد';
        final version = data['version']?.toString() ?? '2.1.0';

        return BackupInspectionResult(
          isValid: true,
          reportCount: reportsList.length,
          templateCount: templatesList.length,
          clientCount: clientsList.length,
          siteCount: sitesList.length,
          photosCount: photoCount,
          exportedAt: exportedAt,
          version: version,
          rawJson: content,
          rawZipBytes: rawBytes,
          isArchive: true,
        );
      } else {
        // معالجة كملف JSON قياسي
        final content = utf8.decode(rawBytes);
        final Map<String, dynamic> data = jsonDecode(content);
        if (!data.containsKey('reports') && !data.containsKey('templates')) {
          return const BackupInspectionResult(
            isValid: false,
            errorMessage: 'الملف المختار ليس ملف نسخة احتياطية صالح لنظام ReportCraft',
          );
        }

        final reportsList = (data['reports'] as List? ?? []);
        final templatesList = (data['templates'] as List? ?? []);
        final clientsList = (data['clients'] as List? ?? []);
        final sitesList = (data['sites'] as List? ?? []);
        final exportedAt = data['exportedAt']?.toString() ?? 'غير محدد';
        final version = data['version']?.toString() ?? '1.0.0';

        return BackupInspectionResult(
          isValid: true,
          reportCount: reportsList.length,
          templateCount: templatesList.length,
          clientCount: clientsList.length,
          siteCount: sitesList.length,
          photosCount: 0,
          exportedAt: exportedAt,
          version: version,
          rawJson: content,
          rawZipBytes: null,
          isArchive: false,
        );
      }
    } catch (e) {
      return BackupInspectionResult(
        isValid: false,
        errorMessage: 'خطأ أثناء معالجة الملف: ${e.toString()}',
      );
    }
  }

  /// 6. تنفيذ الاستعادة سواء كانت حزمة أرشيف شاملة أو ملف JSON قياسي
  static Future<bool> executeRestore(
    BackupInspectionResult inspection, {
    required bool mergeMode,
  }) async {
    try {
      final storage = StorageService();
      if (inspection.isArchive && inspection.rawZipBytes != null) {
        return await storage.importFullArchiveZip(inspection.rawZipBytes!, mergeMode: mergeMode);
      } else {
        return await storage.importFullBackup(inspection.rawJson, mergeMode: mergeMode);
      }
    } catch (e) {
      return false;
    }
  }

  /// 7. تسجيل وقت آخر عملية نسخ احتياطي
  static Future<void> _recordBackupTime(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackup, dt.toIso8601String());
  }

  /// 8. جلب وقت آخر نسخة احتياطية بصيغة مقروءة
  static Future<String?> getLastBackupFormatted() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_keyLastBackup);
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }
}
