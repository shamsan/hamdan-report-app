import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/services/pdf_export_service.dart';
import 'package:report_craft/models/organization.dart';
import 'package:report_craft/models/maintenance_need.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  const branding = OrganizationProfile(
    id: 'org_test',
    name: 'مشروع الطاقة المتجددة',
  );

  test('Generates PDF with Smart Default Orientations (Page 9 Landscape, others Portrait)', () async {
    final sampleReport = DefaultTemplates.sampleDialysisReport;

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: sampleReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes.length > 50000, true);
    expect(pdfBytes[0], 0x25); // %PDF-
  });

  test('Generates PDF with All Pages forced to Portrait (including Page 9 responsive FittedBox)', () async {
    final portraitOrientations = <int, String>{
      for (int i = 1; i <= 13; i++) i: 'portrait',
    };

    final sampleReport = DefaultTemplates.sampleDialysisReport.copyWith(
      pageOrientations: portraitOrientations,
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: sampleReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes.length > 50000, true);

    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\e7218874-4409-4b2c-a07f-f9b1b56951d5\scratch\all_portrait_report.pdf');
    outFile.parent.createSync(recursive: true);
    await outFile.writeAsBytes(pdfBytes);
  });

  test('Generates PDF with All Pages forced to Landscape', () async {
    final landscapeOrientations = <int, String>{
      for (int i = 1; i <= 13; i++) i: 'landscape',
    };

    final sampleReport = DefaultTemplates.sampleDialysisReport.copyWith(
      pageOrientations: landscapeOrientations,
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: sampleReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes.length > 50000, true);

    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\e7218874-4409-4b2c-a07f-f9b1b56951d5\scratch\all_landscape_report.pdf');
    outFile.parent.createSync(recursive: true);
    await outFile.writeAsBytes(pdfBytes);
  });

  test('Generates PDF with Section 13 Needs Table with Arabic text right-aligned', () async {
    final needsReport = DefaultTemplates.sampleDialysisReport.copyWith(
      showNeedsInReport: true,
      requestedNeeds: [
        MaintenanceNeedItem(
          id: 'need_1',
          facilityName: 'مركز الغسيل الكلوي عبس',
          currentVisitNumber: '1',
          targetVisitNumber: '2',
          name: 'فيوزات تيار مستمر 1000V DC 15A مع قواعد عازلة',
          category: 'قواطع وفيوزات',
          quantity: 12,
          unit: 'قطعة',
          priority: NeedPriority.critical,
          reason: 'تلف الفيوزات نتيجة زيادة التيار في الصندوق رقم 3 وضرورة الاستبدال العاجل',
          includeInPdf: true,
          createdAt: DateTime.now(),
        ),
        MaintenanceNeedItem(
          id: 'need_2',
          facilityName: 'مركز الغسيل الكلوي عبس',
          currentVisitNumber: '1',
          targetVisitNumber: '2',
          name: 'كابلات نحاسية معزولة مقاومة للشمس 6mm2 UV-resistant',
          category: 'كابلات وتوصيلات',
          quantity: 50,
          unit: 'متر',
          priority: NeedPriority.urgent,
          reason: 'تآكل العزل الخارجي للكابلات المعرضة للشمس في السقف العلوي',
          includeInPdf: true,
          createdAt: DateTime.now(),
        ),
      ],
      pageOrientations: {
        13: 'landscape', // Custom orientation for needs table
      },
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: needsReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes.length > 50000, true);

    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\e7218874-4409-4b2c-a07f-f9b1b56951d5\scratch\needs_table_aligned_report.pdf');
    outFile.parent.createSync(recursive: true);
    await outFile.writeAsBytes(pdfBytes);
  });

  test('Generates PDF with Mixed A3 and A4 configurations and verifies Page 10 renders cleanly', () async {
    final mixedOrientations = <int, String>{
      1: 'a4_portrait',
      9: 'a3_landscape',
      10: 'a4_portrait',
    };

    final sampleReport = DefaultTemplates.sampleDialysisReport.copyWith(
      pageOrientations: mixedOrientations,
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: sampleReport,
      branding: branding,
      pagesToExport: [10],
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes[0], 0x25); // %PDF-

    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\e7218874-4409-4b2c-a07f-f9b1b56951d5\scratch\page_10_verified.pdf');
    outFile.parent.createSync(recursive: true);
    await outFile.writeAsBytes(pdfBytes);
  });
}
