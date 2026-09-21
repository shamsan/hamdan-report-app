import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report.dart';
import '../models/report_template.dart';
import '../models/organization.dart';
import 'storage_service.dart';

class BackupInspectionResult {
  final bool isValid;
  final int reportCount;
  final int templateCount;
  final String exportedAt;
  final String version;
  final String rawJson;
  final String errorMessage;

  const BackupInspectionResult({
    required this.isValid,
    this.reportCount = 0,
    this.templateCount = 0,
    this.exportedAt = '',
    this.version = '',
    this.rawJson = '',
    this.errorMessage = '',
  });
}

class BackupService {
  static const String _keyLastBackup = 'reportcraft_last_backup_time';

  /// 1. Export backup JSON and save to device local documents storage
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

  /// 2. Export and invoke Android native share sheet (WhatsApp, Drive, Email, etc.)
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

  /// 3. Pick a backup file and inspect its metadata before applying
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
      String content = '';

      if (pickedFile.bytes != null) {
        content = utf8.decode(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        final file = File(pickedFile.path!);
        content = await file.readAsString();
      } else {
        return const BackupInspectionResult(
          isValid: false,
          errorMessage: 'تعذر قراءة بيانات الملف المختار',
        );
      }

      final Map<String, dynamic> data = jsonDecode(content);
      if (!data.containsKey('reports') && !data.containsKey('templates')) {
        return const BackupInspectionResult(
          isValid: false,
          errorMessage: 'الملف المختار ليس ملف نسخة احتياطية صالح لنظام ReportCraft',
        );
      }

      final reportsList = (data['reports'] as List? ?? []);
      final templatesList = (data['templates'] as List? ?? []);
      final exportedAt = data['exportedAt']?.toString() ?? 'غير محدد';
      final version = data['version']?.toString() ?? '1.0.0';

      return BackupInspectionResult(
        isValid: true,
        reportCount: reportsList.length,
        templateCount: templatesList.length,
        exportedAt: exportedAt,
        version: version,
        rawJson: content,
      );
    } catch (e) {
      return BackupInspectionResult(
        isValid: false,
        errorMessage: 'خطأ في معالجة الملف: ${e.toString()}',
      );
    }
  }

  /// 4. Execute restore: Smart Merge (append/update) or Full Overwrite
  static Future<bool> executeRestore(
    String jsonContent, {
    required bool mergeMode,
  }) async {
    try {
      final storage = StorageService();
      final Map<String, dynamic> data = jsonDecode(jsonContent);

      if (mergeMode) {
        // Smart Merge: combine existing reports with incoming reports
        if (data.containsKey('reports')) {
          final currentReports = await storage.loadReports();
          final List incomingList = data['reports'];
          final incomingReports = incomingList.map((e) => Report.fromJson(e)).toList();

          final mergedMap = <String, Report>{};
          for (final r in currentReports) {
            mergedMap[r.id] = r;
          }
          for (final r in incomingReports) {
            mergedMap[r.id] = r; // updates existing or inserts new
          }

          await storage.saveReports(mergedMap.values.toList());
        }

        if (data.containsKey('templates')) {
          final currentTemplates = await storage.loadTemplates();
          final List incomingList = data['templates'];
          final incomingTemplates = incomingList.map((e) => ReportTemplate.fromJson(e)).toList();

          final mergedMap = <String, ReportTemplate>{};
          for (final t in currentTemplates) {
            mergedMap[t.id] = t;
          }
          for (final t in incomingTemplates) {
            mergedMap[t.id] = t;
          }
          await storage.saveTemplates(mergedMap.values.toList());
        }
      } else {
        // Full Overwrite
        if (data.containsKey('reports')) {
          final List incomingList = data['reports'];
          final reports = incomingList.map((e) => Report.fromJson(e)).toList();
          await storage.saveReports(reports);
        }
        if (data.containsKey('templates')) {
          final List incomingList = data['templates'];
          final templates = incomingList.map((e) => ReportTemplate.fromJson(e)).toList();
          await storage.saveTemplates(templates);
        }
        if (data.containsKey('branding')) {
          final branding = OrganizationProfile.fromJson(data['branding']);
          await storage.saveBranding(branding);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 5. SharedPreferences helper for recording backup timestamp
  static Future<void> _recordBackupTime(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackup, dt.toIso8601String());
  }

  /// 6. Get last backup timestamp formatted
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
