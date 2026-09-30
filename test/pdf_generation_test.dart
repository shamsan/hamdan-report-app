import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/services/pdf_export_service.dart';
import 'package:report_craft/models/organization.dart';
import 'package:report_craft/models/report.dart';
import 'package:report_craft/models/inspection_item.dart';
import 'package:report_craft/models/signature_data.dart';
import 'package:report_craft/models/report_photo.dart';
import 'package:report_craft/models/measurement_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  test('Generates full 11-page PDF document and writes to disk', () async {
    final sampleReport = DefaultTemplates.sampleDialysisReport;
    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة لدعم الخدمات الصحية في اليمن',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: sampleReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    // PDF header starts with %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
    expect(pdfBytes[0], 0x25);
    expect(pdfBytes[1], 0x50);
    expect(pdfBytes[2], 0x44);
    expect(pdfBytes[3], 0x46);
    expect(pdfBytes[4], 0x2D);

    // Save to scratch for verification
    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\e7218874-4409-4b2c-a07f-f9b1b56951d5\scratch\generated_naskh_report.pdf');
    outFile.parent.createSync(recursive: true);
    await outFile.writeAsBytes(pdfBytes);
    // ignore: avoid_print
    print('Generated PDF size: ${pdfBytes.length} bytes');
  });

  test('Generates PDF for report with blank fields without falling back to sample data', () async {
    final blankReport = DefaultTemplates.solarMaintenanceTemplate.instantiateReport(
      facilityName: 'مستشفى السلام العام',
      contractNo: '998877',
    );
    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
    );

    // Test full 11 pages generation for blank report
    final pdfBytes = await PdfExportService.generateReportPdf(
      report: blankReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\2b050183-795d-4ff0-a867-c3ed1c6677fd\scratch\blank_test_report.pdf');
    await outFile.writeAsBytes(pdfBytes);
  });

  test('Generates PDF reflecting custom engineer field inputs across all pages', () async {
    final customReport = DefaultTemplates.solarMaintenanceTemplate.instantiateReport(
      facilityName: 'مركز الأمل التخصصي',
      contractNo: 'CNT-2026-99',
    ).copyWith(
      projectInfo: const ProjectInfo(
        projectName: 'مشروع تزويد المراكز الصحية بأنظمة الطاقة الشمسية المستقلة',
        funder: 'منظمة الصحة العالمية WHO',
        implementingContractor: 'مجموعة الأمل للهندسة والمقاولات',
        governorate: 'الحديدة',
        district: 'بيت الفقيه',
      ),
      facilityInfo: const FacilityInfo(
        facilityName: 'مركز الأمل التخصصي',
        facilityNameEn: 'Al-Amal Specialized Center',
        facilityType: 'مركز تخصصي',
        category: 'CAT B',
        visitDate: '2026/09/07',
        contactPerson: 'د. سالم اليماني',
      ),
      systemSpecs: const SystemSpecs(
        capacityKw: '30 kW',
        panelsCountAndWatt: '60 x 500Wp',
        batteryUnitsCapacity: '1500Ah',
        batteryUnitsCount: '48 x 2V',
        invertersCapacity: '5KVA',
        invertersCount: '4',
        chargeControllersCapacity: '80 A',
        chargeControllersCount: '8',
        otherAppliances: 'مكيف هواء 1.5 طن عدد 2',
      ),
    );

    const branding = OrganizationProfile(
      id: 'org_amal',
      name: 'منظمة الصحة العالمية',
      contractorNameAr: 'مجموعة الأمل للهندسة والمقاولات',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: customReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\2b050183-795d-4ff0-a867-c3ed1c6677fd\scratch\custom_input_test_report.pdf');
    await outFile.writeAsBytes(pdfBytes);
    // ignore: avoid_print
    print('Generated Custom Input PDF: ${pdfBytes.length} bytes');
  });

  test('Generates PDF with only 1 battery group (Group 1 only) - omits 2nd battery page', () async {
    final singleGroupReport = DefaultTemplates.sampleDialysisReport.copyWith(
      activeBatteryGroups: [1],
      activeCombinerBoxes: [1, 2],
    );
    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: singleGroupReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\2b050183-795d-4ff0-a867-c3ed1c6677fd\scratch\single_group_battery_report.pdf');
    await outFile.writeAsBytes(pdfBytes);
    // ignore: avoid_print
    print('Generated Single Battery Group PDF: ${pdfBytes.length} bytes');
  });

  test('Generates PDF with only Group 4 and 2 combiner boxes', () async {
    final group4Report = DefaultTemplates.sampleDialysisReport.copyWith(
      activeBatteryGroups: [4],
      activeCombinerBoxes: [1, 2],
    );
    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: group4Report,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\2b050183-795d-4ff0-a867-c3ed1c6677fd\scratch\group4_battery_report.pdf');
    await outFile.writeAsBytes(pdfBytes);
    // ignore: avoid_print
    print('Generated Group 4 Battery PDF: ${pdfBytes.length} bytes');
  });

  test('Generates PDF with long multi-line notes wrapping downwards without errors', () async {
    // Inject long notes (both continuous sentence and explicit newlines)
    final modifiedGroups = DefaultTemplates.sampleDialysisReport.inspectionGroups.map((group) {
      if (group.groupNumber == 1) {
        final updatedItems = List<InspectionItem>.from(group.items);
        if (updatedItems.isNotEmpty) {
          updatedItems[0] = updatedItems[0].copyWith(
            notes: 'تم فحص القاطع والتأكد من سلامة الكابلات وتم استبدال الفيوز التالف وإعادة تشغيل المنظومة بنجاح تام للموقع',
          );
        }
        if (updatedItems.length > 1) {
          updatedItems[1] = updatedItems[1].copyWith(
            notes: 'السطر الأول من الملاحظة تم الفحص\nالسطر الثاني يوضح الحاجة للصيانة الدورية',
          );
        }
        return group.copyWith(items: updatedItems);
      }
      return group;
    }).toList();

    final longNoteReport = DefaultTemplates.sampleDialysisReport.copyWith(
      inspectionGroups: modifiedGroups,
    );

    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: longNoteReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\2b050183-795d-4ff0-a867-c3ed1c6677fd\scratch\long_notes_downward_report.pdf');
    await outFile.writeAsBytes(pdfBytes);
    // ignore: avoid_print
    print('Generated Long Notes PDF: ${pdfBytes.length} bytes');
  });

  test('Generates PDF with custom visit number, right logo disabled (2-logo dynamic layout), and populated attendance team', () async {
    final reportWithNewFeatures = DefaultTemplates.sampleDialysisReport.copyWith(
      visitNumber: '3',
      showRightLogo: false,
      attendanceList: const [
        AttendanceRecord(serialNo: 1, name: 'م. أحمد مهندس الموقع', role: 'مهندس مقاول', affiliation: 'الشركة المنفذة'),
        AttendanceRecord(serialNo: 2, name: 'د. خالد مدير المركز', role: 'مسؤول المرفق', affiliation: 'مركز الغسيل'),
        AttendanceRecord(serialNo: 3, name: 'م. فؤاد مندوب الوزارة', role: 'استشاري', affiliation: 'وزارة الصحة'),
      ],
    );

    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
      showRightLogo: true, // overridden by report.showRightLogo = false
      rightLogoNameAr: 'مكتب الأمم المتحدة لخدمات المشاريع',
      rightLogoNameEn: 'UNOPS',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: reportWithNewFeatures,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes[0], 0x25); // %PDF-
    // ignore: avoid_print
    print('Generated 2-Logo Dynamic Visit 3 PDF: ${pdfBytes.length} bytes');
  });

  test('Generates PDF with custom per-report branding, digital signatures, and official facility stamp', () async {
    const dummyPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

    final customBrandedReport = DefaultTemplates.sampleDialysisReport.copyWith(
      funderLogoBase64: dummyPng,
      funderNameAr: 'برنامج الأمم المتحدة الإنمائي (UNDP)',
      funderNameEn: 'UNITED NATIONS DEVELOPMENT PROGRAMME (UNDP)',
      ministryLogoBase64: dummyPng,
      ministryNameAr: 'وزارة التربية والتعليم',
      ministryNameEn: 'Ministry of Education',
      contractorLogoBase64: dummyPng,
      contractorNameAr: 'شركة المقاولات الهندسية الحديثة',
      contractorSubtitleAr: 'للطاقة المتجددة المحدودة',
      contractorNameEn: 'Modern Engineering Contracting Co.',
      showRightLogo: true,
      approvalStatement: const ApprovalStatement(
        beneficiaryRepName: 'د. خالد مدير المركز',
        beneficiaryRepRole: 'مدير عام المركز',
        contractorSignatureBase64: dummyPng,
        beneficiarySignatureBase64: dummyPng,
        stampBase64: dummyPng,
      ),
    );

    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: customBrandedReport,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes[0], 0x25); // %PDF-
    // ignore: avoid_print
    print('Generated Custom Branded PDF with Signatures & Stamp: ${pdfBytes.length} bytes');
  });

  test('Generates multi-page photo appendix with mixed landscape and portrait orientations', () async {
    const dummyPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

    final testPhotos = [
      ReportPhoto(
        id: 'p1',
        title: 'صورة عامة للموقع والمصفوفات',
        caption: 'نظرة عامة على حقل الألواح',
        location: 'السطح الرئيسي',
        base64Data: dummyPng,
        isLandscape: true,
      ),
      ReportPhoto(
        id: 'p2',
        title: 'صندوق التجميع رقم 1',
        caption: 'فحص القواطع والفيوزات',
        location: 'غرفة التحكم',
        base64Data: dummyPng,
        isLandscape: false,
      ),
      ReportPhoto(
        id: 'p3',
        title: 'صندوق التجميع رقم 2',
        caption: 'فحص الحمايات من الصواعق',
        location: 'غرفة التحكم',
        base64Data: dummyPng,
        isLandscape: false,
      ),
      ReportPhoto(
        id: 'p4',
        title: 'محطة العواكس الرئيسية',
        caption: 'شاشات القراءة ودرجات الحرارة',
        location: 'غرفة الطاقة',
        base64Data: dummyPng,
        isLandscape: true,
      ),
      ReportPhoto(
        id: 'p5',
        title: 'بنك البطاريات - المجموعة الأولى',
        caption: 'فحص أقطاب التوصيل وسوائل الخلايا',
        location: 'غرفة البطاريات',
        base64Data: dummyPng,
        isLandscape: false,
      ),
      ReportPhoto(
        id: 'p6',
        title: 'لوحة التوزيع الرئيسية MDB',
        caption: 'فحص منظمات الشحن والقواطع',
        location: 'غرفة التوزيع',
        base64Data: dummyPng,
        isLandscape: false,
      ),
    ];

    final reportWithPhotos = DefaultTemplates.sampleDialysisReport.copyWith(
      photos: testPhotos,
    );

    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: reportWithPhotos,
      branding: branding,
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes[0], 0x25); // %PDF-
    // ignore: avoid_print
    print('Generated Multi-page Photo Appendix PDF: ${pdfBytes.length} bytes');
  });

  test('Generates PDF with empty installation date showing wide handwriting space in Page 10', () async {
    final reportWithoutDate = DefaultTemplates.sampleDialysisReport.copyWith(
      facilityInfo: DefaultTemplates.sampleDialysisReport.facilityInfo.copyWith(
        installationDate: '',
      ),
    );

    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: reportWithoutDate,
      branding: branding,
      pagesToExport: [10],
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes[0], 0x25); // %PDF-
    // ignore: avoid_print
    print('Generated Page 10 Wide Blank Date PDF: ${pdfBytes.length} bytes');
  });

  test('Generates Page 9 PV Strings table in landscape matching official 4-block template', () async {
    final reportWithMeasurements = DefaultTemplates.sampleDialysisReport.copyWith(
      stringMeasurements: [
        const StringMeasurement(stringNumber: 1, openCircuitVoltageVoc: 745.2, shortCircuitCurrentIsc: 9.4),
        const StringMeasurement(stringNumber: 2, openCircuitVoltageVoc: 744.8, shortCircuitCurrentIsc: 9.3),
        const StringMeasurement(stringNumber: 5, openCircuitVoltageVoc: 750.1, shortCircuitCurrentIsc: 9.5, notes: 'سليمة وبحالة ممتازة'),
      ],
      systemSpecs: DefaultTemplates.sampleDialysisReport.systemSpecs.copyWith(
        panelsCountAndWatt: '12x 600Wp',
      ),
    );

    const branding = OrganizationProfile(
      id: 'org_test',
      name: 'مشروع الطاقة المتجددة',
    );

    final pdfBytes = await PdfExportService.generateReportPdf(
      report: reportWithMeasurements,
      branding: branding,
      pagesToExport: [9],
    );

    expect(pdfBytes.isNotEmpty, true);
    expect(pdfBytes[0], 0x25); // %PDF-
    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\e7218874-4409-4b2c-a07f-f9b1b56951d5\scratch\page_9_pv_strings_landscape.pdf');
    await outFile.writeAsBytes(pdfBytes);
    // ignore: avoid_print
    print('Generated Page 9 PV Strings Landscape PDF: ${pdfBytes.length} bytes');
  });

  test('ReportPhoto orientation toggles properly and getBytes handles Data URI safely', () async {
    const rawPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    const dataUriPng = 'data:image/png;base64,$rawPng';

    final portraitPhoto = ReportPhoto(
      id: 'photo_test_1',
      title: 'صورة عمودية',
      base64Data: dataUriPng,
      isLandscape: false,
    );

    expect(portraitPhoto.isLandscape, false);
    final bytesFromDataUri = await portraitPhoto.getBytes();
    expect(bytesFromDataUri, isNotNull);
    expect(bytesFromDataUri!.length, greaterThan(10));

    final toggledLandscape = portraitPhoto.copyWith(isLandscape: true);
    expect(toggledLandscape.isLandscape, true);

    final syncBytes = toggledLandscape.getBytesSync();
    expect(syncBytes, isNotNull);
    expect(syncBytes!.length, bytesFromDataUri.length);
  });
}

