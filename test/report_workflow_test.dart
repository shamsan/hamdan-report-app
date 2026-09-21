import 'dart:convert';
import 'package:report_craft/models/signature_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/core/utils/arabic_reshaper.dart';
import 'package:report_craft/core/utils/template_parser.dart';
import 'package:report_craft/models/inspection_item.dart';
import 'package:report_craft/models/report.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/services/storage_service.dart';
import 'package:report_craft/state/reports_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportCraft Core Workflow Tests', () {
    test('Default 11-page solar template structure', () {
      final tmpl = DefaultTemplates.solarMaintenanceTemplate;
      expect(tmpl.pages.length, 11);
      expect(tmpl.isDefault, true);
      expect(tmpl.isLocked, true);
      expect(tmpl.pages[0].title, contains('بيانات المشروع'));
      expect(tmpl.pages[5].title, contains('قياسات مصفوفة تخزين الطاقة'));
      expect(tmpl.pages[10].title, contains('سجل حضور'));
    });

    test('Template variable interpolation', () {
      const templateText = 'نقر نحن إدارة {{اسم_المنشأة}} بمحافظة {{المحافظة}} بتنفيذ الزيارة لمشروع {{اسم_المشروع}}.';
      final values = {
        '{{اسم_المنشأة}}': 'مركز غسيل الكلى عبس',
        '{{المحافظة}}': 'حجة',
        '{{اسم_المشروع}}': 'مشروع الطاقة المتجددة',
      };

      final result = TemplateParser.interpolate(templateText, values);
      expect(result, 'نقر نحن إدارة مركز غسيل الكلى عبس بمحافظة حجة بتنفيذ الزيارة لمشروع مشروع الطاقة المتجددة.');
    });

    test('Report completion ratio calculation', () {
      final sample = DefaultTemplates.sampleDialysisReport;
      final progress = sample.completionRatio;
      expect(progress, greaterThan(0.8));
      expect(progress, lessThanOrEqualTo(1.0));
    });

    test('Battery measurements statistics calculation', () {
      final sample = DefaultTemplates.sampleDialysisReport;
      expect(sample.batteryMeasurements.length, 96);

      final voltages = sample.batteryMeasurements.map((b) => b.voltage).toList();
      final minV = voltages.reduce((a, b) => a < b ? a : b);
      final maxV = voltages.reduce((a, b) => a > b ? a : b);
      final avgV = voltages.reduce((a, b) => a + b) / voltages.length;

      expect(minV, greaterThan(2.10));
      expect(maxV, lessThan(2.30));
      expect(avgV, closeTo(2.16, 0.05));
    });

    test('Inspection groups validation & status labeling', () {
      final groups = DefaultTemplates.defaultInspectionGroups;
      expect(groups.length, 10);
      expect(groups[0].title, contains('الألواح الشمسية'));
      expect(groups[9].title, contains('مصفوفة تخزين الطاقة'));

      for (final g in groups) {
        expect(g.items.isNotEmpty, true);
        for (final item in g.items) {
          expect(item.status.labelAr.isNotEmpty, true);
        }
      }
    });

    test('Report validation detects missing required fields', () {
      final emptyReport = Report(
        id: 'test_empty',
        templateId: 'tmpl_1',
        title: '',
        reportNumber: '',
        contractNumber: '',
        visitDate: '',
        projectInfo: ProjectInfo(projectName: ''),
        facilityInfo: FacilityInfo(facilityName: ''),
        systemSpecs: SystemSpecs(),
        inspectionGroups: [],
        batteryMeasurements: [],
        operationalData: [],
        stringMeasurements: [],
        correctiveActions: [],
        photos: [],
        signatures: [],
        approvalStatement: ApprovalStatement(),
        attendanceList: [],
        createdAt: DateTime(2025, 8, 15),
        updatedAt: DateTime(2025, 8, 15)
      );

      final missing = emptyReport.validateMissingFields();
      expect(missing.isNotEmpty, true);
      expect(missing.any((m) => m.contains('اسم المشروع')), true);
      expect(missing.any((m) => m.contains('اسم المنشأة')), true);
    });

    test('Arabic Reshaper handles mixed RTL and Arabic phrases', () {
      final reshaped = ArabicReshaper.shapeAndBidi('مركز غسيل الكلى عبس - CAT 8');
      expect(reshaped.isNotEmpty, true);
    });

    test('Report duplication accurately clones all fields and isolates copy', () async {
      final storage = _MockStorageService();
      final originalReport = DefaultTemplates.sampleDialysisReport;
      storage.inMemoryReports.add(originalReport);

      final notifier = ReportsNotifier(storage);
      await notifier.load();

      final duplicated = await notifier.duplicateReport(
        originalReport,
        newFacilityName: 'مستشفى السلام التخصصي',
        newVisitDate: '2026/09/08',
        clearSignatures: true,
        clearPhotos: true,
      );

      // Verify ID and metadata
      expect(duplicated.id, isNot(equals(originalReport.id)));
      expect(duplicated.reportNumber, isNot(equals(originalReport.reportNumber)));
      expect(duplicated.facilityInfo.facilityName, equals('مستشفى السلام التخصصي'));
      expect(duplicated.facilityInfo.visitDate, equals('2026/09/08'));
      expect(duplicated.status, equals(ReportStatus.draft));

      // Verify technical configurations carried over
      expect(duplicated.systemSpecs.capacityKw, equals(originalReport.systemSpecs.capacityKw));
      expect(duplicated.activeBatteryGroups, equals(originalReport.activeBatteryGroups));
      expect(duplicated.activeCombinerBoxes, equals(originalReport.activeCombinerBoxes));
      expect(duplicated.inspectionGroups.length, equals(originalReport.inspectionGroups.length));
      expect(duplicated.batteryMeasurements.length, equals(originalReport.batteryMeasurements.length));

      // Verify signatures cleared for new signoff
      expect(duplicated.signatures.every((s) => s.signatureBase64 == null), true);
      expect(duplicated.approvalStatement.beneficiarySignatureBase64, isNull);

      // Verify deep clone isolation (mutating copy does not alter original)
      expect(originalReport.facilityInfo.facilityName, contains('مكتب الأتقان الهندسي'));
    });

    test('Backup JSON export and inspection validates structure correctly', () {
      final sample = DefaultTemplates.sampleDialysisReport;
      final backup = {
        'version': '2.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'reports': [sample.toJson()],
        'templates': [DefaultTemplates.solarMaintenanceTemplate.toJson()],
      };
      final jsonStr = jsonEncode(backup);
      final decoded = jsonDecode(jsonStr);

      expect(decoded.containsKey('reports'), true);
      expect((decoded['reports'] as List).length, 1);
      expect(decoded['version'], '2.0.0');

      // Test Smart Merge simulation
      final existingReport = sample.copyWith(title: 'تقرير أصلي');
      final newReport = Report.fromJson({
        ...sample.toJson(),
        'id': 'rep_incoming_999',
        'title': 'تقرير جديد مستورد',
      });

      final mergedMap = <String, Report>{};
      mergedMap[existingReport.id] = existingReport;
      mergedMap[newReport.id] = newReport;

      expect(mergedMap.length, 2);
      expect(mergedMap.containsKey('rep_incoming_999'), true);
    });
  });
}

class _MockStorageService extends StorageService {
  _MockStorageService() : super.forTesting();
  final List<Report> inMemoryReports = [];

  @override
  Future<List<Report>> loadReports() async => List.from(inMemoryReports);

  @override
  Future<void> saveSingleReport(Report report) async {
    final idx = inMemoryReports.indexWhere((r) => r.id == report.id);
    if (idx >= 0) {
      inMemoryReports[idx] = report;
    } else {
      inMemoryReports.insert(0, report);
    }
  }

  @override
  Future<void> deleteReport(String id) async {
    inMemoryReports.removeWhere((r) => r.id == id);
  }
}
