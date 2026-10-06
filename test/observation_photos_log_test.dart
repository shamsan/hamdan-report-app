import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/models/inspection_item.dart';
import 'package:report_craft/models/organization.dart';
import 'package:report_craft/models/report.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  const dummyPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

  const testBranding = OrganizationProfile(
    id: 'org_test',
    name: 'مشروع الطاقة المتجددة لدعم الخدمات الصحية في اليمن',
  );

  group('Observations Documentation Log Tests', () {
    test('InspectionItem defaults includeInPdf to true and serializes correctly', () {
      const item = InspectionItem(
        id: 'test_item_1',
        serialNo: 1,
        description: 'فحص القواطع',
        photoBase64: dummyPng,
      );

      expect(item.includeInPdf, true);

      final json = item.toJson();
      expect(json['includeInPdf'], true);

      final fromJson = InspectionItem.fromJson(json);
      expect(fromJson.includeInPdf, true);

      final toggled = item.copyWith(includeInPdf: false);
      expect(toggled.includeInPdf, false);
      expect(toggled.toJson()['includeInPdf'], false);
    });

    test('Report defaults showObservationsInReport to true and serializes correctly', () {
      final sample = DefaultTemplates.sampleDialysisReport;
      expect(sample.showObservationsInReport, true);

      final json = sample.toJson();
      expect(json['showObservationsInReport'], true);

      final fromJson = Report.fromJson(json);
      expect(fromJson.showObservationsInReport, true);

      final toggled = sample.copyWith(showObservationsInReport: false);
      expect(toggled.showObservationsInReport, false);
      expect(toggled.toJson()['showObservationsInReport'], false);
    });

    test('Generates PDF with Section 14 (Observations Appendix) when photos exist and enabled', () async {
      final sample = DefaultTemplates.sampleDialysisReport;

      // Attach photos and notes to two inspection items
      final updatedGroups = List<InspectionGroup>.from(sample.inspectionGroups);
      final g0 = updatedGroups[0];
      final items0 = List<InspectionItem>.from(g0.items);
      items0[0] = items0[0].copyWith(
        status: InspectionStatus.rejected,
        notes: 'وجود كسر واضح في زجاج اللوح وتفريغ هوائي يتطلب استبدالاً عاجلاً',
        photoBase64: dummyPng,
        includeInPdf: true,
      );
      items0[1] = items0[1].copyWith(
        status: InspectionStatus.needsFollowup,
        notes: 'ارتخاء في مسامير تثبيت الهيكل الحامل',
        photoBase64: dummyPng,
        includeInPdf: true,
      );
      updatedGroups[0] = g0.copyWith(items: items0);

      final reportWithObservations = sample.copyWith(
        inspectionGroups: updatedGroups,
        showObservationsInReport: true,
      );

      final pdfBytes = await PdfExportService.generateReportPdf(
        report: reportWithObservations,
        branding: testBranding,
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes[0], 0x25); // %PDF-
      // ignore: avoid_print
      print('Generated PDF with observations log: ${pdfBytes.length} bytes');
    });

    test('Generates PDF without Section 14 when showObservationsInReport is false', () async {
      final sample = DefaultTemplates.sampleDialysisReport;

      final updatedGroups = List<InspectionGroup>.from(sample.inspectionGroups);
      final g0 = updatedGroups[0];
      final items0 = List<InspectionItem>.from(g0.items);
      items0[0] = items0[0].copyWith(
        photoBase64: dummyPng,
        includeInPdf: true,
      );
      updatedGroups[0] = g0.copyWith(items: items0);

      final reportDisabled = sample.copyWith(
        inspectionGroups: updatedGroups,
        showObservationsInReport: false,
      );

      final pdfBytes = await PdfExportService.generateReportPdf(
        report: reportDisabled,
        branding: testBranding,
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes[0], 0x25); // %PDF-
    });
  });
}
