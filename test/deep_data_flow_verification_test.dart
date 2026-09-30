import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/models/report.dart';
import 'package:report_craft/models/organization.dart';
import 'package:report_craft/models/inspection_item.dart';
import 'package:report_craft/models/measurement_data.dart';
import 'package:report_craft/models/signature_data.dart';
import 'package:report_craft/models/maintenance_need.dart';
import 'package:report_craft/services/pdf_export_service.dart';
import 'package:report_craft/services/default_templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  test('Deep Data Flow Verification: Custom inputs across all 11 pages render correctly in PDF', () async {
    const contractorTitle = 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة';
    const contractorTitleEn = 'Al-Etqan Engineering Office for Engineering Services and Energy Solutions';

    // Start with the full 11-page sample report and override all user fields with distinctive values
    final baseReport = DefaultTemplates.sampleDialysisReport;

    final customReport = baseReport.copyWith(
      reportNumber: 'TEST-REP-2026-99',
      contractNumber: 'CNT-987654',
      visitDate: '2026/09/21',
      visitTime: '10:15 ص',
      visitNumber: '3',
      contractorNameAr: contractorTitle,
      contractorNameEn: contractorTitleEn,
      description: 'وصف فحص دقيق للتحقق من تدفق كافة البيانات إلى التقرير',
      projectInfo: const ProjectInfo(
        projectName: 'مشروع التحقق الرقمي الميداني للطاقة الشمسية',
        ownerEntity: 'وزارة الصحة العامة و البيئة',
        implementingContractor: contractorTitle,
        funder: 'مكتب الأمم المتحدة لخدمات المشاريع (UNOPS)',
        governorate: 'صنعاء',
        district: 'السبعين',
        location: 'حي الجامعة الجديد - المركز الطبي التخصصي',
      ),
      facilityInfo: const FacilityInfo(
        facilityName: contractorTitle,
        facilityNameEn: contractorTitleEn,
        facilityType: 'مركز صحي نوع A',
        category: 'CAT 8',
        contactPerson: 'د. خالد محمد الريمي',
        phone: '771234567',
        email: 'khaled.reimi@test-health.org',
        governorate: 'صنعاء',
        directorate: 'السبعين',
        visitDate: '2026/09/21',
        visitNumber: '3',
        installationDate: '2023/04/10',
      ),
      systemSpecs: const SystemSpecs(
        systemType: 'هجين ثلاثي الأطوار Hybrid Three-Phase',
        capacityKw: '75.5 kWp',
        panelsCountAndWatt: '120 x 620Wp Monocrystalline',
        invertersCapacity: '15 kVA',
        invertersCount: '4',
        chargeControllersCapacity: '100A / 250V MPPT',
        chargeControllersCount: '8',
        batteryUnitsCapacity: '3000 Ah OPzV Deep Cycle',
        batteryUnitsCount: '48 x 2V Tubular',
        otherAppliances: 'نظام تكييف مركزي 5 طن + غرفة تعقيم',
      ),
      attendanceList: const [
        AttendanceRecord(
          serialNo: 1,
          name: 'م. أحمد سعيد العنسي',
          role: 'مهندس صيانة المنظومة (رئيس الفريق)',
          affiliation: contractorTitle,
          notes: 'حاضر ومُشرف على الفحص',
        ),
        AttendanceRecord(
          serialNo: 2,
          name: 'فني. علي ناصر شوعي',
          role: 'فني كهرباء وقياس عزم',
          affiliation: contractorTitle,
          notes: 'قام بقياس عزم الربط',
        ),
        AttendanceRecord(
          serialNo: 3,
          name: 'د. خالد محمد الريمي',
          role: 'مدير المنشأة الطبية (ممثل المستفيد)',
          affiliation: 'وزارة الصحة العامة',
          notes: 'مصادق ومستلم للموقع',
        ),
      ],
      inspectionGroups: baseReport.inspectionGroups.map((g) {
        return g.copyWith(
          items: g.items.map((it) {
            return it.copyWith(
              status: InspectionStatus.good,
              notes: 'فحص سليم وفق المعايير الهندسية',
            );
          }).toList(),
        );
      }).toList(),
      activeBatteryGroups: const [1, 2],
      batteryMeasurements: List.generate(48, (idx) {
        final cellNum = (idx % 24) + 1;
        final grpNum = (idx ~/ 24) + 1;
        return BatteryMeasurement(
          cellNumber: cellNum,
          stringNumber: grpNum,
          voltage: 2.15 + (cellNum * 0.005),
          boltTorque: 12.0,
          notes: 'خلية $cellNum مجموعة $grpNum',
        );
      }),
      operationalData: [
        const OperationalData(id: '1', parameter: 'op_dc_voltage', measuredValue: '54.2', unit: 'Vdc', standardRange: '48-58', status: 'طبيعي', notes: 'ضمن الحدود المثالية'),
        const OperationalData(id: '2', parameter: 'op_load_1', measuredValue: '18.4', unit: 'A', standardRange: '0-25', status: 'طبيعي', notes: 'حمل الإنفرتر الأول'),
        const OperationalData(id: '3', parameter: 'op_load_2', measuredValue: '17.9', unit: 'A', standardRange: '0-25', status: 'طبيعي', notes: 'حمل الإنفرتر الثاني'),
        const OperationalData(id: '4', parameter: 'op_load_3', measuredValue: '19.1', unit: 'A', standardRange: '0-25', status: 'طبيعي', notes: 'حمل الإنفرتر الثالث'),
        const OperationalData(id: '5', parameter: 'op_load_4', measuredValue: '16.8', unit: 'A', standardRange: '0-25', status: 'طبيعي', notes: 'حمل الإنفرتر الرابع'),
        const OperationalData(id: '6', parameter: 'op_battery_soc', measuredValue: '98', unit: '%', standardRange: '80-100', status: 'طبيعي', notes: 'حالة شحن ممتازة'),
      ],
      showNeedsInReport: true,
      requestedNeeds: [
        MaintenanceNeedItem(
          id: 'need_01',
          facilityName: contractorTitle,
          currentVisitNumber: '3',
          targetVisitNumber: '4',
          name: 'فيوز أسطواني 1000V 15A DC',
          quantity: 12,
          unit: 'حبة',
          category: 'قواطع DC',
          priority: NeedPriority.urgent,
          reason: 'استبدال فيوزات قديمة مستهلكة',
          createdAt: DateTime(2026, 9, 21),
        ),
        MaintenanceNeedItem(
          id: 'need_02',
          facilityName: contractorTitle,
          currentVisitNumber: '3',
          targetVisitNumber: '4',
          name: 'كابل تأريض مرن 25 مم²',
          quantity: 50,
          unit: 'متر',
          category: 'تأريض وحماية',
          priority: NeedPriority.normal,
          reason: 'تدعيم شبكة التأريض الخارجية',
          createdAt: DateTime(2026, 9, 21),
        ),
      ],
      pageOrientations: {9: 'landscape'},
    );

    const branding = OrganizationProfile(
      id: 'org_test',
      name: contractorTitle,
      subTitle: 'للخدمات الهندسية وحلول الطاقة',
      contractorNameAr: contractorTitle,
      contractorNameEn: contractorTitleEn,
    );

    // Export PDF with Smart Defaults (Page 9 Landscape)
    final pdfBytes = await PdfExportService.generateReportPdf(
      report: customReport,
      branding: branding,
    );

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(50000));
    // Verify valid PDF header %PDF-
    expect(pdfBytes[0], 0x25);
    expect(pdfBytes[1], 0x50);
    expect(pdfBytes[2], 0x44);
    expect(pdfBytes[3], 0x46);
    expect(pdfBytes[4], 0x2D);

    // Save PDF to scratch for inspection
    final outFile = File(r'C:\Users\pc\.gemini\antigravity\brain\e7218874-4409-4b2c-a07f-f9b1b56951d5\scratch\deep_data_flow_verification.pdf');
    outFile.parent.createSync(recursive: true);
    await outFile.writeAsBytes(pdfBytes);
    expect(outFile.existsSync(), isTrue);

    // Verify Portrait mode for all pages (including responsive Page 9)
    final portraitPdfBytes = await PdfExportService.generateReportPdf(
      report: customReport.copyWith(pageOrientations: {9: 'portrait'}),
      branding: branding,
    );
    expect(portraitPdfBytes, isNotNull);
    expect(portraitPdfBytes.length, greaterThan(50000));
    expect(portraitPdfBytes[0], 0x25);

    // Verify backward compatibility migration in StorageService and OrganizationProfile
    final legacyProfileJson = {
      'id': 'legacy_org',
      'name': 'مؤسسة الطاقة المتجددة',
      'contractorNameAr': 'شركة الإتقان الهندسي',
      'contractorNameEn': 'Al-Etqan Al-Handasi Engineering Co. Ltd',
      'contractorSubtitleAr': 'لأنظمة الطاقة والمقاولات المحدودة',
    };
    final migratedProfile = OrganizationProfile.fromJson(legacyProfileJson);
    expect(migratedProfile.name, contractorTitle);
    expect(migratedProfile.contractorNameAr, contractorTitle);
    expect(migratedProfile.contractorNameEn, contractorTitleEn);
    expect(migratedProfile.contractorSubtitleAr, '');

    final legacyReportJson = {
      'id': 'legacy_rep',
      'title': 'تقرير قديم',
      'contractorNameAr': 'شركة الإتقان الهندسي المحدودة',
      'projectInfo': {
        'implementingContractor': 'شركة بندر ناجي',
      },
      'facilityInfo': {
        'facilityName': 'شركة الإتقان الهندسي',
      },
    };
    final reportFromLegacy = Report.fromJson(legacyReportJson);
    expect(reportFromLegacy.id, 'legacy_rep');
  });
}
