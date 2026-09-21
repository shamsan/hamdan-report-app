import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/organization.dart';
import '../models/report_template.dart';
import '../models/report.dart';
import '../models/client.dart';
import '../models/site.dart';
import 'default_templates.dart';

/// خدمة التخزين المحلي — تعتمد على ملفات JSON منفصلة في مجلد التطبيق
/// كل تقرير = ملف JSON مستقل → لا قيود حجم + أداء أفضل
class StorageService {
  static const String _keyReports    = 'reportcraft_reports_v1';   // SharedPrefs legacy
  static const String _keyTemplates  = 'reportcraft_templates_v1'; // SharedPrefs legacy
  static const String _keyBranding   = 'reportcraft_branding_v1';  // SharedPrefs (صغير)
  static const String _keyMigrated   = 'reportcraft_migrated_v2';  // علامة الهجرة

  // ─── Singleton ───────────────────────────────────────────────────────────────
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  // للاختبارات فقط
  StorageService.forTesting();

  SharedPreferences? _prefs;
  Directory? _reportsDir;
  Directory? _templatesDir;
  Directory? _photosDir;
  Directory? _clientsDir;
  Directory? _sitesDir;
  bool _initialized = false;

  // ─── تهيئة ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;              // منع الاستدعاء المتكرر
    _prefs ??= await SharedPreferences.getInstance();
    await _ensureDirs();
    await _migrateFromSharedPrefsIfNeeded();
    _initialized = true;
  }

  Future<void> _ensureDirs() async {
    if (_reportsDir != null && _templatesDir != null && _photosDir != null && _clientsDir != null && _sitesDir != null) return; // مُهيَّأة مسبقاً
    final base = await getApplicationDocumentsDirectory();
    _reportsDir   = Directory('${base.path}/reports');
    _templatesDir = Directory('${base.path}/templates');
    _photosDir    = Directory('${base.path}/photos');
    _clientsDir   = Directory('${base.path}/clients');
    _sitesDir     = Directory('${base.path}/sites');
    await _reportsDir!.create(recursive: true);
    await _templatesDir!.create(recursive: true);
    await _photosDir!.create(recursive: true);
    await _clientsDir!.create(recursive: true);
    await _sitesDir!.create(recursive: true);
  }

  /// هجرة بيانات SharedPreferences القديمة إلى نظام الملفات (يُنفَّذ مرة واحدة فقط)
  /// ملاحظة: يُستدعى هذا فقط من داخل init() — لا تستدع init() داخله مجدداً
  Future<void> _migrateFromSharedPrefsIfNeeded() async {
    // لا نستدعي init() هنا — نحن بالفعل داخل init()
    final alreadyMigrated = _prefs?.getBool(_keyMigrated) ?? false;
    if (alreadyMigrated) return;

    // هجرة التقارير
    final reportsJson = _prefs?.getString(_keyReports);
    if (reportsJson != null && reportsJson.isNotEmpty) {
      try {
        final List decoded = jsonDecode(reportsJson);
        for (final item in decoded) {
          final report = Report.fromJson(item as Map<String, dynamic>);
          await _writeReportFile(report);
        }
      } catch (_) {
        // فشل الهجرة — الملفات الافتراضية ستُنشأ عند أول loadReports
      }
    }

    // هجرة القوالب
    final templatesJson = _prefs?.getString(_keyTemplates);
    if (templatesJson != null && templatesJson.isNotEmpty) {
      try {
        final List decoded = jsonDecode(templatesJson);
        for (final item in decoded) {
          final template = ReportTemplate.fromJson(item as Map<String, dynamic>);
          await _writeTemplateFile(template);
        }
      } catch (_) {}
    }

    // تسجيل اكتمال الهجرة
    await _prefs?.setBool(_keyMigrated, true);

    // تنظيف SharedPreferences القديم (اختياري — لتوفير المساحة)
    await _prefs?.remove(_keyReports);
    await _prefs?.remove(_keyTemplates);
  }

  // ─── مسارات الملفات ──────────────────────────────────────────────────────────
  File _reportFile(String id)   => File('${_reportsDir!.path}/$id.json');
  File _templateFile(String id) => File('${_templatesDir!.path}/$id.json');
  File _clientFile(String id)   => File('${_clientsDir!.path}/$id.json');
  File _siteFile(String id)     => File('${_sitesDir!.path}/$id.json');

  /// حفظ ذري (Atomic Write) لملفات العملاء
  Future<void> _writeClientFile(Client client) async {
    await _ensureDirs();
    final target = _clientFile(client.id);
    final temp = File('${target.path}.tmp');
    final content = const JsonEncoder.withIndent('  ').convert(client.toJson());
    await temp.writeAsString(content, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  /// حفظ ذري (Atomic Write) لملفات المواقع
  Future<void> _writeSiteFile(Site site) async {
    await _ensureDirs();
    final target = _siteFile(site.id);
    final temp = File('${target.path}.tmp');
    final content = const JsonEncoder.withIndent('  ').convert(site.toJson());
    await temp.writeAsString(content, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  /// حفظ ذري (Atomic Write) لمنع تلف ملفات التقارير عند انطفاء الهاتف المفاجئ
  Future<void> _writeReportFile(Report report) async {
    await _ensureDirs();
    final target = _reportFile(report.id);
    final temp = File('${target.path}.tmp');
    final content = const JsonEncoder.withIndent('  ').convert(report.toJson());
    await temp.writeAsString(content, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  /// حفظ ذري (Atomic Write) لملفات القوالب
  Future<void> _writeTemplateFile(ReportTemplate template) async {
    await _ensureDirs();
    final target = _templateFile(template.id);
    final temp = File('${target.path}.tmp');
    final content = const JsonEncoder.withIndent('  ').convert(template.toJson());
    await temp.writeAsString(content, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  /// حفظ صورة فيزيائياً على القرص في مجلد الصور وإرجاع مسارها الكامل
  Future<String> savePhotoFile({
    required String reportId,
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    await _ensureDirs();
    final filename = '${reportId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final file = File('${_photosDir!.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // ─── Reports CRUD ────────────────────────────────────────────────────────────
  Future<List<Report>> loadReports() async {
    await init();
    final files = _reportsDir!
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    if (files.isEmpty) {
      return [];
    }

    final reports = <Report>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        var rep = Report.fromJson(jsonDecode(content) as Map<String, dynamic>);
        bool needsUpdate = false;
        if (rep.contractorNameAr != null &&
            rep.contractorNameAr != 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة' &&
            (rep.contractorNameAr!.contains('بندر ناجي') ||
             rep.contractorNameAr!.contains('الإتقان') ||
             rep.contractorNameAr!.contains('الاتقان') ||
             rep.contractorNameAr!.contains('الأتقان'))) {
          rep = rep.copyWith(
            contractorNameAr: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
            contractorSubtitleAr: '',
            contractorNameEn: 'Al-Etqan Engineering Office for Engineering Services and Energy Solutions',
          );
          needsUpdate = true;
        }
        if (rep.projectInfo.implementingContractor != 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة' &&
            (rep.projectInfo.implementingContractor.contains('بندر ناجي') ||
             rep.projectInfo.implementingContractor.contains('الإتقان') ||
             rep.projectInfo.implementingContractor.contains('الاتقان') ||
             rep.projectInfo.implementingContractor.contains('الأتقان'))) {
          rep = rep.copyWith(
            projectInfo: rep.projectInfo.copyWith(
              implementingContractor: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
            ),
          );
          needsUpdate = true;
        }
        if (rep.facilityInfo.facilityName != 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة' &&
            (rep.facilityInfo.facilityName.contains('الإتقان') ||
             rep.facilityInfo.facilityName.contains('الاتقان') ||
             rep.facilityInfo.facilityName.contains('الأتقان'))) {
          rep = rep.copyWith(
            facilityInfo: rep.facilityInfo.copyWith(
              facilityName: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
              facilityNameEn: 'Al-Etqan Engineering Office for Engineering Services and Energy Solutions',
            ),
          );
          needsUpdate = true;
        }
        if (needsUpdate) {
          await _writeReportFile(rep);
        }
        reports.add(rep);
      } catch (_) {
        // ملف تالف — يُتجاهل
      }
    }

    // ترتيب: الأحدث تحديثاً أولاً
    reports.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return reports;
  }

  Future<void> saveSingleReport(Report report) async {
    await _writeReportFile(report);
  }

  Future<void> saveReports(List<Report> reports) async {
    await _ensureDirs();
    for (final r in reports) {
      await _writeReportFile(r);
    }
  }

  Future<void> deleteReport(String id) async {
    await _ensureDirs();
    final f = _reportFile(id);
    if (await f.exists()) await f.delete();
  }

  // ─── Templates CRUD ──────────────────────────────────────────────────────────
  Future<List<ReportTemplate>> loadTemplates() async {
    await init();
    final files = _templatesDir!
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    if (files.isEmpty) {
      final def = DefaultTemplates.solarMaintenanceTemplate;
      await _writeTemplateFile(def);
      return [def];
    }

    final templates = <ReportTemplate>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        templates.add(ReportTemplate.fromJson(jsonDecode(content) as Map<String, dynamic>));
      } catch (_) {}
    }

    // ضمان وجود القالب الافتراضي دائماً
    if (!templates.any((t) => t.id == 'tmpl_solar_11p')) {
      final def = DefaultTemplates.solarMaintenanceTemplate;
      await _writeTemplateFile(def);
      templates.insert(0, def);
    }

    return templates;
  }

  Future<void> saveSingleTemplate(ReportTemplate template) async {
    await _writeTemplateFile(template);
  }

  Future<void> saveTemplates(List<ReportTemplate> templates) async {
    for (final t in templates) {
      await _writeTemplateFile(t);
    }
  }

  Future<void> deleteTemplate(String id) async {
    await _ensureDirs();
    final f = _templateFile(id);
    if (await f.exists()) await f.delete();
  }

  // ─── Clients CRUD ────────────────────────────────────────────────────────────
  Future<List<Client>> loadClients() async {
    await init();
    final files = _clientsDir!
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    if (files.isEmpty) {
      return [];
    }

    final clients = <Client>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        clients.add(Client.fromJson(jsonDecode(content) as Map<String, dynamic>));
      } catch (_) {}
    }

    clients.sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return clients;
  }

  Future<void> saveSingleClient(Client client) async {
    await _writeClientFile(client);
  }

  Future<void> saveClients(List<Client> clients) async {
    for (final c in clients) {
      await _writeClientFile(c);
    }
  }

  Future<void> deleteClient(String id) async {
    await _ensureDirs();
    final f = _clientFile(id);
    if (await f.exists()) await f.delete();
  }

  // ─── Sites CRUD ──────────────────────────────────────────────────────────────
  Future<List<Site>> loadSites() async {
    await init();
    final files = _sitesDir!
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    if (files.isEmpty) {
      return [];
    }

    final sites = <Site>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        sites.add(Site.fromJson(jsonDecode(content) as Map<String, dynamic>));
      } catch (_) {}
    }

    sites.sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return sites;
  }

  Future<void> saveSingleSite(Site site) async {
    await _writeSiteFile(site);
  }

  Future<void> saveSites(List<Site> sites) async {
    for (final s in sites) {
      await _writeSiteFile(s);
    }
  }

  Future<void> deleteSite(String id) async {
    await _ensureDirs();
    final f = _siteFile(id);
    if (await f.exists()) await f.delete();
  }

  // ─── Branding Profile (صغير → يبقى في SharedPreferences) ────────────────────
  Future<OrganizationProfile> loadBranding() async {
    await init();
    final jsonString = _prefs?.getString(_keyBranding);
    if (jsonString == null || jsonString.isEmpty) {
      const defaultProfile = OrganizationProfile(
        id: 'org_default',
        name: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
        subTitle: 'للخدمات الهندسية وحلول الطاقة',
        contractorNameAr: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
        contractorSubtitleAr: '',
        contractorNameEn: 'Al-Etqan Engineering Office for Engineering Services and Energy Solutions',
      );
      await saveBranding(defaultProfile);
      return defaultProfile;
    }
    try {
      final profile = OrganizationProfile.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
      bool changed = false;
      var updated = profile;
      if (updated.name != 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة' &&
          (updated.name.contains('الإتقان') ||
           updated.name.contains('الاتقان') ||
           updated.name.contains('الأتقان') ||
           updated.name == 'مؤسسة الطاقة المتجددة' ||
           updated.name == 'مشروع الطاقة المتجددة لدعم الخدمات الصحية' ||
           updated.name == 'مكتب الأمم المتحدة لخدمات المشاريع ووزارة الصحة')) {
        updated = updated.copyWith(
          name: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
          subTitle: 'للخدمات الهندسية وحلول الطاقة',
        );
        changed = true;
      }
      if (updated.contractorNameAr != 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة' &&
          (updated.contractorNameAr.contains('بندر ناجي') ||
           updated.contractorNameAr.contains('الإتقان') ||
           updated.contractorNameAr.contains('الاتقان') ||
           updated.contractorNameAr.contains('الأتقان') ||
           updated.contractorNameAr.trim().isEmpty)) {
        updated = updated.copyWith(
          contractorNameAr: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
          contractorSubtitleAr: '',
          contractorNameEn: 'Al-Etqan Engineering Office for Engineering Services and Energy Solutions',
          clearContractorLogo: true,
        );
        changed = true;
      }
      if (changed) {
        await saveBranding(updated);
      }
      return updated;
    } catch (_) {
      const defaultProfile = OrganizationProfile(
        id: 'org_default',
        name: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
        subTitle: 'للخدمات الهندسية وحلول الطاقة',
        contractorNameAr: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
        contractorSubtitleAr: '',
        contractorNameEn: 'Al-Etqan Engineering Office for Engineering Services and Energy Solutions',
      );
      await saveBranding(defaultProfile);
      return defaultProfile;
    }
  }

  Future<void> saveBranding(OrganizationProfile profile) async {
    await init();
    await _prefs?.setString(_keyBranding, jsonEncode(profile.toJson()));
  }

  // ─── Full Backup & Restore ───────────────────────────────────────────────────
  Future<String> exportFullBackup() async {
    final reports   = await loadReports();
    final templates = await loadTemplates();
    final branding  = await loadBranding();
    final clients   = await loadClients();
    final sites     = await loadSites();

    final backup = {
      'version':    '2.1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'reports':    reports.map((r) => r.toJson()).toList(),
      'templates':  templates.map((t) => t.toJson()).toList(),
      'branding':   branding.toJson(),
      'clients':    clients.map((c) => c.toJson()).toList(),
      'sites':      sites.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<bool> importFullBackup(String jsonContent, {bool mergeMode = true}) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonContent) as Map<String, dynamic>;

      if (data.containsKey('clients')) {
        final List cList = data['clients'] as List;
        final clients = cList.map((e) => Client.fromJson(e as Map<String, dynamic>)).toList();
        for (final c in clients) {
          await saveSingleClient(c);
        }
      }

      if (data.containsKey('sites')) {
        final List sList = data['sites'] as List;
        final sites = sList.map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
        for (final s in sites) {
          await saveSingleSite(s);
        }
      }

      if (data.containsKey('reports')) {
        final List rList = data['reports'] as List;
        final incoming = rList.map((e) => Report.fromJson(e as Map<String, dynamic>)).toList();

        if (mergeMode) {
          // دمج ذكي: تحديث الموجود وإضافة الجديد
          final existing = await loadReports();
          final existingIds = {for (final r in existing) r.id};
          for (final r in incoming) {
            if (!existingIds.contains(r.id)) {
              await saveSingleReport(r);
            } else {
              // تحديث فقط إذا كانت النسخة المستوردة أحدث
              final ex = existing.firstWhere((e) => e.id == r.id);
              if (r.updatedAt.isAfter(ex.updatedAt)) {
                await saveSingleReport(r);
              }
            }
          }
        } else {
          // استبدال كامل: حذف الكل وإعادة الكتابة
          await _clearAllReports();
          for (final r in incoming) {
            await saveSingleReport(r);
          }
        }
      }

      if (data.containsKey('templates')) {
        final List tList = data['templates'] as List;
        final templates = tList.map((e) => ReportTemplate.fromJson(e as Map<String, dynamic>)).toList();
        for (final t in templates) {
          await saveSingleTemplate(t);
        }
      }

      if (data.containsKey('branding')) {
        final branding = OrganizationProfile.fromJson(data['branding'] as Map<String, dynamic>);
        await saveBranding(branding);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearAllReports() async {
    await _ensureDirs();
    final files = _reportsDir!.listSync().whereType<File>();
    for (final f in files) {
      await f.delete();
    }
  }
}
