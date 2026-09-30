import '../models/signature_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/report.dart';
import '../models/report_template.dart';
import '../models/client.dart';
import '../models/site.dart';
import '../models/maintenance_need.dart';
import '../services/storage_service.dart';
import '../services/default_templates.dart';
import 'clients_provider.dart';
import 'sites_provider.dart';
import '../core/licensing/engine/license_guard.dart';
import '../core/licensing/security/secure_quota_store.dart';
import 'licensing_provider.dart';

class ReportsNotifier extends StateNotifier<List<Report>> {
  final StorageService _storage;

  ReportsNotifier(this._storage) : super([]) {
    load();
  }

  Future<void> load() async {
    final list = await _storage.loadReports();
    // الترتيب: الأحدث تحديثاً أولاً
    final sorted = [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (mounted) state = sorted;
  }

  // ─── البحث والفلترة (محلياً — لا تغير state) ────────────────────────────────
  List<Report> getFiltered({String query = '', ReportStatus? status, ReportSortOrder sortOrder = ReportSortOrder.updatedAtDesc}) {
    var filtered = state.where((r) {
      final q = query.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          r.title.toLowerCase().contains(q) ||
          r.facilityInfo.facilityName.toLowerCase().contains(q) ||
          r.reportNumber.toLowerCase().contains(q) ||
          r.contractNumber.toLowerCase().contains(q);
      final matchesStatus = status == null ||
          (status == ReportStatus.completed ? r.isCompleted : (status == ReportStatus.draft ? !r.isCompleted : r.status == status));
      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) => switch (sortOrder) {
      ReportSortOrder.updatedAtDesc => b.updatedAt.compareTo(a.updatedAt),
      ReportSortOrder.updatedAtAsc  => a.updatedAt.compareTo(b.updatedAt),
      ReportSortOrder.nameAsc       => a.facilityInfo.facilityName.compareTo(b.facilityInfo.facilityName),
      ReportSortOrder.nameDesc      => b.facilityInfo.facilityName.compareTo(a.facilityInfo.facilityName),
    });

    return filtered;
  }

  // ─── إنشاء التقارير ──────────────────────────────────────────────────────────
  Future<Report> createReportFromTemplate(ReportTemplate template) async {
    // 🛡️ فحص صلاحية الترخيص (القيد المزدوج: 60 يوماً أو 15 تقريراً)
    final license = await LicenseGuard.evaluateLicense(state.length);
    if (!license.canCreateReport) {
      throw LicenseException(
        license.message ?? 'لا يمكن إنشاء تقارير جديدة. يرجى تفعيل أو تجديد الترخيص.',
      );
    }

    const uuid = Uuid();
    final now = DateTime.now();
    final dateStr = _formatDate(now);

    final newReport = Report(
      id: 'rep_${uuid.v4().substring(0, 8)}',
      templateId: template.id,
      title: 'تقرير زيارة - منشأة جديدة',
      reportNumber: _generateReportNumber(now),
      contractNumber: '',
      visitDate: dateStr,
      visitTime: '',
      description: 'تقرير صيانة دورية لمنظومة الطاقة الشمسية',
      projectInfo: const ProjectInfo(),
      facilityInfo: const FacilityInfo(),
      systemSpecs: const SystemSpecs(),
      inspectionGroups:    DefaultTemplates.blankInspectionGroups,
      batteryMeasurements: DefaultTemplates.blankBatteryMeasurements,
      operationalData:     DefaultTemplates.blankOperationalData,
      stringMeasurements:  DefaultTemplates.blankStringMeasurements,
      correctiveActions: const [],
      photos: const [],
      signatures: const [
        ReportSignature(
          id: 'sig_eng',
          role: 'مهندس الصيانة المسؤول',
          signerName: '',
          jobTitle: '',
        ),
        ReportSignature(
          id: 'sig_fac',
          role: 'ممثل المرفق الخدمي',
          signerName: '',
          jobTitle: '',
        ),
      ],
      approvalStatement: const ApprovalStatement(
        projectTitle: '',
        facilityName: '',
      ),
      attendanceList:    const [],
      status:    ReportStatus.draft,
      createdAt: now,
      updatedAt: now,
    );

    await _storage.saveSingleReport(newReport);
    await SecureQuotaStore.recordNewReportCreation(state.length);
    await load();
    return newReport;
  }

  Future<Report> createCustomReport({
    String? templateId,
    String? title,
    String? contractNumber,
    String? visitDate,
    String? visitTime,
    String? visitNumber,
    String? description,
    String? clientId,
    String? siteId,
    Site? site,
    Client? client,
    required ProjectInfo projectInfo,
    required FacilityInfo facilityInfo,
    required SystemSpecs systemSpecs,
    List<int>? activeBatteryGroups,
    List<int>? activeCombinerBoxes,
    Report? cloneSourceReport,
  }) async {
    // 🛡️ فحص صلاحية الترخيص (القيد المزدوج: 60 يوماً أو 15 تقريراً)
    final license = await LicenseGuard.evaluateLicense(state.length);
    if (!license.canCreateReport) {
      throw LicenseException(
        license.message ?? 'لا يمكن إنشاء تقارير جديدة. يرجى تفعيل أو تجديد الترخيص.',
      );
    }

    const uuid = Uuid();
    final now = DateTime.now();
    final dateStr = (visitDate != null && visitDate.isNotEmpty)
        ? visitDate
        : _formatDate(now);

    final effectiveClientId = clientId ?? site?.clientId ?? client?.id ?? cloneSourceReport?.clientId ?? '';
    final effectiveSiteId = siteId ?? site?.id ?? cloneSourceReport?.siteId ?? '';

    // حساب رقم الزيارة التالي تلقائياً إذا لم يُحدد أو كان الافتراضي
    String effectiveVisitNumber = visitNumber ?? (facilityInfo.visitNumber.isNotEmpty ? facilityInfo.visitNumber : '1');
    if (visitNumber == null || visitNumber.isEmpty || visitNumber == '1') {
      final relevantReports = state.where((r) => 
        (effectiveSiteId.isNotEmpty && r.siteId == effectiveSiteId) ||
        (facilityInfo.facilityName.isNotEmpty && r.facilityInfo.facilityName == facilityInfo.facilityName)
      ).toList();
      if (relevantReports.isNotEmpty) {
        final nums = relevantReports.map((r) => int.tryParse(r.visitNumber) ?? 1).toList()..sort();
        effectiveVisitNumber = (nums.last + 1).toString();
      }
    }

    final effectiveTitle = (title != null && title.isNotEmpty)
        ? title
        : (facilityInfo.facilityName.isNotEmpty
            ? 'تقرير زيارة ($effectiveVisitNumber) - ${facilityInfo.facilityName}'
            : 'تقرير صيانة دورية لمنظومة الطاقة الشمسية');

    // استخراج المواد والاحتياجات المعلقة من الزيارة السابقة إن وجدت
    List<MaintenanceNeedItem> pendingNeeds = [];
    final siteReports = state.where((r) => 
      (effectiveSiteId.isNotEmpty && r.siteId == effectiveSiteId) ||
      (facilityInfo.facilityName.isNotEmpty && r.facilityInfo.facilityName == facilityInfo.facilityName)
    ).toList();
    if (siteReports.isNotEmpty) {
      siteReports.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final lastReport = siteReports.first;
      pendingNeeds = lastReport.requestedNeeds
          .where((n) => n.status == NeedStatus.requested || n.status == NeedStatus.supplied)
          .toList();
    } else if (cloneSourceReport != null) {
      pendingNeeds = cloneSourceReport.requestedNeeds
          .where((n) => n.status == NeedStatus.requested || n.status == NeedStatus.supplied)
          .toList();
    }

    final effectiveShowRightLogo = site?.showFunderLogo ?? cloneSourceReport?.showRightLogo ?? (site?.funderLogoBase64 != null);
    final effectiveFunderLogo = site?.funderLogoBase64 ?? cloneSourceReport?.funderLogoBase64;
    final effectiveFunderNameAr = (site != null && site.funderNameAr.isNotEmpty) ? site.funderNameAr : cloneSourceReport?.funderNameAr;
    final effectiveFunderNameEn = (site != null && site.funderNameEn.isNotEmpty) ? site.funderNameEn : cloneSourceReport?.funderNameEn;

    final effectiveContractorLogo = site?.contractorLogoBase64 ?? cloneSourceReport?.contractorLogoBase64;
    final effectiveContractorNameAr = (site != null && site.implementingContractor.isNotEmpty)
        ? site.implementingContractor
        : (cloneSourceReport?.contractorNameAr ?? projectInfo.implementingContractor);
    final effectiveContractorNameEn = cloneSourceReport?.contractorNameEn;
    final effectiveContractorSubtitleAr = cloneSourceReport?.contractorSubtitleAr;

    final effectiveMinistryLogo = client?.logoBase64 ?? cloneSourceReport?.ministryLogoBase64;
    final effectiveMinistryNameAr = client?.nameAr ?? cloneSourceReport?.ministryNameAr;
    final effectiveMinistryNameEn = client?.nameEn ?? cloneSourceReport?.ministryNameEn;

    final effectiveArrayPanelCounts = (site != null && site.arrayPanelCounts.isNotEmpty)
        ? Map<int, int>.from(site.arrayPanelCounts)
        : (cloneSourceReport != null ? Map<int, int>.from(cloneSourceReport.arrayPanelCounts) : const <int, int>{});

    final effectiveFacilityInfo = facilityInfo.copyWith(
      visitDate: dateStr,
      visitNumber: effectiveVisitNumber,
      installationDate: (site != null && site.installationDate.isNotEmpty)
          ? site.installationDate
          : facilityInfo.installationDate,
      email: (site != null && site.email.isNotEmpty) ? site.email : facilityInfo.email,
    );

    final newReport = Report(
      id: 'rep_${uuid.v4().substring(0, 8)}',
      templateId: templateId ?? 'tmpl_solar_11p',
      title: effectiveTitle,
      reportNumber: _generateReportNumber(now),
      contractNumber: (contractNumber != null && contractNumber.isNotEmpty)
          ? contractNumber
          : (site?.contractNumber ?? cloneSourceReport?.contractNumber ?? ''),
      visitDate: dateStr,
      visitTime: visitTime ?? '09:30 ص',
      visitNumber: effectiveVisitNumber,
      showRightLogo: effectiveShowRightLogo,
      funderLogoBase64: effectiveFunderLogo,
      funderNameAr: effectiveFunderNameAr,
      funderNameEn: effectiveFunderNameEn,
      contractorLogoBase64: effectiveContractorLogo,
      contractorNameAr: effectiveContractorNameAr,
      contractorNameEn: effectiveContractorNameEn,
      contractorSubtitleAr: effectiveContractorSubtitleAr,
      ministryLogoBase64: effectiveMinistryLogo,
      ministryNameAr: effectiveMinistryNameAr,
      ministryNameEn: effectiveMinistryNameEn,
      description: description ?? 'تقرير صيانة دورية شاملة لمنظومة الطاقة الشمسية',
      projectInfo: projectInfo,
      facilityInfo: effectiveFacilityInfo,
      systemSpecs: systemSpecs,
      arrayPanelCounts: effectiveArrayPanelCounts,
      inspectionGroups:    cloneSourceReport?.inspectionGroups    ?? DefaultTemplates.blankInspectionGroups,
      batteryMeasurements: cloneSourceReport?.batteryMeasurements ?? DefaultTemplates.blankBatteryMeasurements,
      operationalData:     cloneSourceReport?.operationalData     ?? DefaultTemplates.blankOperationalData,
      stringMeasurements:  cloneSourceReport?.stringMeasurements  ?? DefaultTemplates.blankStringMeasurements,
      correctiveActions:   cloneSourceReport?.correctiveActions   ?? const [],
      photos: const [],
      requestedNeeds: pendingNeeds,
      showNeedsInReport: true,
      signatures: cloneSourceReport?.signatures ?? [
        const ReportSignature(
          id: 'sig_eng',
          role: 'مهندس الصيانة المسؤول',
          signerName: '',
          jobTitle: 'مهندس صيانة معتمد',
        ),
        ReportSignature(
          id: 'sig_fac',
          role: 'ممثل المرفق الخدمي',
          signerName: facilityInfo.contactPerson,
          jobTitle: 'مدير المنشأة',
        ),
      ],
      approvalStatement: cloneSourceReport?.approvalStatement ?? ApprovalStatement(
        projectTitle:          projectInfo.projectName,
        facilityName:          facilityInfo.facilityName,
        beneficiaryRepName:    facilityInfo.contactPerson,
        approvalDate:          dateStr,
      ),
      attendanceList: cloneSourceReport?.attendanceList ?? const [],
      activeBatteryGroups: activeBatteryGroups ?? cloneSourceReport?.activeBatteryGroups ?? const [1, 2, 3, 4],
      activeCombinerBoxes: activeCombinerBoxes ?? cloneSourceReport?.activeCombinerBoxes ?? const [1, 2, 3, 4],
      clientId: effectiveClientId,
      siteId: effectiveSiteId,
      status:    ReportStatus.draft,
      createdAt: now,
      updatedAt: now,
    );

    await _storage.saveSingleReport(newReport);
    await SecureQuotaStore.recordNewReportCreation(state.length);
    await load();
    return newReport;
  }

  /// إنشاء تقرير وزيارة ميدانية مباشرة لموقع معين من دليل المواقع والعملاء
  Future<Report> createReportForSite({
    required Site site,
    required Client client,
    String? visitDate,
    String? visitTime,
    String? customVisitNumber,
  }) async {
    // 🛡️ فحص صلاحية الترخيص (القيد المزدوج: 60 يوماً أو 15 تقريراً)
    final license = await LicenseGuard.evaluateLicense(state.length);
    if (!license.canCreateReport) {
      throw LicenseException(
        license.message ?? 'لا يمكن إنشاء تقارير جديدة. يرجى تفعيل أو تجديد الترخيص.',
      );
    }

    const uuid = Uuid();
    final now = DateTime.now();
    final dateStr = visitDate ?? _formatDate(now);

    // حساب رقم الزيارة التالي استناداً إلى تقارير الموقع السابقة
    final siteReports = state.where((r) => r.siteId == site.id || r.facilityInfo.facilityName == site.nameAr).toList();
    int nextNum = 1;
    if (siteReports.isNotEmpty) {
      final nums = siteReports.map((r) => int.tryParse(r.visitNumber) ?? 1).toList();
      nums.sort();
      nextNum = nums.last + 1;
    }
    final effectiveVisitNumber = customVisitNumber ?? nextNum.toString();

    // استخراج المواد المعلقة من الزيارة السابقة إن وجدت
    List<MaintenanceNeedItem> pendingNeeds = [];
    if (siteReports.isNotEmpty) {
      siteReports.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final lastReport = siteReports.first;
      pendingNeeds = lastReport.requestedNeeds
          .where((n) => n.status == NeedStatus.requested || n.status == NeedStatus.supplied)
          .toList();
    }

    final newReport = Report(
      id: 'rep_${uuid.v4().substring(0, 8)}',
      templateId: 'tmpl_solar_11p',
      clientId: client.id,
      siteId: site.id,
      title: 'تقرير زيارة ($effectiveVisitNumber) - ${site.displayName}',
      reportNumber: _generateReportNumber(now),
      contractNumber: site.contractNumber,
      visitDate: dateStr,
      visitTime: visitTime ?? '09:30 ص',
      visitNumber: effectiveVisitNumber,
      showRightLogo: site.showFunderLogo,
      funderLogoBase64: site.funderLogoBase64,
      funderNameAr: site.funderNameAr,
      funderNameEn: site.funderNameEn,
      contractorLogoBase64: site.contractorLogoBase64,
      contractorNameAr: site.implementingContractor,
      ministryLogoBase64: client.logoBase64,
      ministryNameAr: client.nameAr,
      ministryNameEn: client.nameEn,
      description: 'تقرير صيانة دورية شاملة لمنظومة الطاقة الشمسية',
      projectInfo: ProjectInfo(
        projectName: site.projectName.isNotEmpty
            ? site.projectName
            : 'مشروع تشغيل وصيانة منظومات الطاقة الشمسية',
        ownerEntity: client.displayName,
        funder: site.funderNameAr,
        implementingContractor: site.implementingContractor,
        governorate: site.governorate,
        district: site.directorate,
        location: site.locationAddress,
      ),
      facilityInfo: FacilityInfo(
        facilityName: site.nameAr,
        facilityNameEn: site.nameEn,
        facilityType: site.facilityType,
        category: site.category,
        contactPerson: site.contactPerson,
        phone: site.phone,
        email: site.email,
        governorate: site.governorate,
        directorate: site.directorate,
        visitDate: dateStr,
        visitNumber: effectiveVisitNumber,
        installationDate: site.installationDate,
      ),
      systemSpecs: site.systemSpecs,
      arrayPanelCounts: site.arrayPanelCounts,
      inspectionGroups: DefaultTemplates.blankInspectionGroups,
      batteryMeasurements: DefaultTemplates.blankBatteryMeasurements,
      operationalData: DefaultTemplates.blankOperationalData,
      stringMeasurements: DefaultTemplates.blankStringMeasurements,
      correctiveActions: const [],
      photos: const [],
      requestedNeeds: pendingNeeds,
      showNeedsInReport: true,
      signatures: [
        const ReportSignature(
          id: 'sig_eng',
          role: 'مهندس الصيانة المسؤول',
          signerName: '',
          jobTitle: 'مهندس صيانة معتمد',
        ),
        ReportSignature(
          id: 'sig_fac',
          role: 'ممثل المرفق الخدمي',
          signerName: site.contactPerson,
          jobTitle: 'مدير المنشأة',
        ),
      ],
      approvalStatement: ApprovalStatement(
        projectTitle: site.projectName,
        facilityName: site.nameAr,
        beneficiaryRepName: site.contactPerson,
        approvalDate: dateStr,
      ),
      attendanceList: const [],
      status: ReportStatus.draft,
      createdAt: now,
      updatedAt: now,
    );

    await _storage.saveSingleReport(newReport);
    await SecureQuotaStore.recordNewReportCreation(state.length);
    await load();
    return newReport;
  }

  // ─── تحديث / حذف ─────────────────────────────────────────────────────────────
  Future<void> updateReport(Report report) async {
    final updated = report.copyWith(updatedAt: DateTime.now());
    await _storage.saveSingleReport(updated);

    // تحديث الـ state محلياً دون إعادة قراءة كل الملفات
    final index = state.indexWhere((r) => r.id == report.id);
    if (index >= 0) {
      final updatedList = List<Report>.from(state);
      updatedList[index] = updated;
      // إعادة الترتيب: الأحدث أولاً
      updatedList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (mounted) state = updatedList;
    } else {
      if (mounted) state = [updated, ...state];
    }
  }

  Future<void> addReport(Report report) async {
    await updateReport(report);
  }

  Future<Report> duplicateReport(
    Report report, {
    String? newFacilityName,
    String? newVisitDate,
    String? newVisitNumber,
    bool clearSignatures = true,
    bool clearPhotos = true,
  }) async {
    // 🛡️ فحص صلاحية الترخيص (القيد المزدوج: 60 يوماً أو 15 تقريراً)
    final license = await LicenseGuard.evaluateLicense(state.length);
    if (!license.canCreateReport) {
      throw LicenseException(
        license.message ?? 'لا يمكن إنشاء تقارير جديدة. يرجى تفعيل أو تجديد الترخيص.',
      );
    }

    const uuid = Uuid();
    final now = DateTime.now();
    final dateStr = (newVisitDate != null && newVisitDate.isNotEmpty)
        ? newVisitDate
        : _formatDate(now);

    // حساب رقم الزيارة التالي للموقع إن وُجد
    int nextNum = (int.tryParse(report.visitNumber) ?? 1) + 1;
    if (report.siteId.isNotEmpty) {
      final siteReports = state.where((r) => r.siteId == report.siteId).toList();
      if (siteReports.isNotEmpty) {
        final nums = siteReports.map((r) => int.tryParse(r.visitNumber) ?? 1).toList()..sort();
        nextNum = nums.last + 1;
      }
    }
    final visitNumStr = (newVisitNumber != null && newVisitNumber.isNotEmpty)
        ? newVisitNumber
        : nextNum.toString();

    final effectiveFacility = newFacilityName != null && newFacilityName.isNotEmpty
        ? report.facilityInfo.copyWith(facilityName: newFacilityName, visitDate: dateStr, visitNumber: visitNumStr)
        : report.facilityInfo.copyWith(visitDate: dateStr, visitNumber: visitNumStr);

    final effectiveTitle = newFacilityName != null && newFacilityName.isNotEmpty
        ? 'تقرير صيانة - $newFacilityName'
        : 'تقرير زيارة ($visitNumStr) - ${effectiveFacility.facilityName.isNotEmpty ? effectiveFacility.facilityName : report.title}';

    final clonedGroups     = report.inspectionGroups.map((g) => g.copyWith(items: g.items.map((i) => i.copyWith()).toList())).toList();
    final clonedBattery    = report.batteryMeasurements.map((b) => b.copyWith()).toList();
    final clonedOperational = report.operationalData.map((o) => o.copyWith()).toList();
    final clonedStrings    = report.stringMeasurements.map((s) => s.copyWith()).toList();

    final clonedSignatures = report.signatures.map((s) => ReportSignature(
      id: s.id,
      role: s.role,
      signerName: s.signerName,
      jobTitle: s.jobTitle,
      signatureBase64: clearSignatures ? null : s.signatureBase64,
      signedDate: clearSignatures ? '' : s.signedDate,
    )).toList();

    // استخراج واستمرار الاحتياجات المعلقة
    final pendingNeeds = report.requestedNeeds
        .where((n) => n.status == NeedStatus.requested || n.status == NeedStatus.supplied)
        .toList();

    final newReport = Report(
      id: 'rep_${uuid.v4().substring(0, 8)}',
      templateId:     report.templateId,
      title:          effectiveTitle,
      reportNumber:   _generateReportNumber(now),
      contractNumber: report.contractNumber,
      visitDate:      dateStr,
      visitTime:      report.visitTime,
      visitNumber:    visitNumStr,
      showRightLogo:  report.showRightLogo,
      funderLogoBase64: report.funderLogoBase64,
      funderNameAr: report.funderNameAr,
      funderNameEn: report.funderNameEn,
      contractorLogoBase64: report.contractorLogoBase64,
      contractorNameAr: report.contractorNameAr,
      contractorNameEn: report.contractorNameEn,
      contractorSubtitleAr: report.contractorSubtitleAr,
      ministryLogoBase64: report.ministryLogoBase64,
      ministryNameAr: report.ministryNameAr,
      ministryNameEn: report.ministryNameEn,
      description:    report.description,
      projectInfo:    report.projectInfo.copyWith(),
      facilityInfo:   effectiveFacility,
      systemSpecs:    report.systemSpecs.copyWith(),
      inspectionGroups:    clonedGroups,
      batteryMeasurements: clonedBattery,
      operationalData:     clonedOperational,
      stringMeasurements:  clonedStrings,
      correctiveActions:   report.correctiveActions.map((c) => c.copyWith()).toList(),
      photos: clearPhotos ? const [] : List.from(report.photos),
      signatures: clonedSignatures,
      approvalStatement: report.approvalStatement.copyWith(
        approvalDate: dateStr,
        facilityName: effectiveFacility.facilityName,
        beneficiarySignatureBase64: clearSignatures ? null : report.approvalStatement.beneficiarySignatureBase64,
        contractorSignatureBase64:  clearSignatures ? null : report.approvalStatement.contractorSignatureBase64,
        stampBase64: clearSignatures ? null : report.approvalStatement.stampBase64,
      ),
      attendanceList:      report.attendanceList.map((a) => a.copyWith()).toList(),
      requestedNeeds:      pendingNeeds,
      showNeedsInReport:   report.showNeedsInReport,
      activeBatteryGroups: List<int>.from(report.activeBatteryGroups),
      activeCombinerBoxes: List<int>.from(report.activeCombinerBoxes),
      arrayPanelCounts:    Map<int, int>.from(report.arrayPanelCounts),
      pageOrientations:    Map<int, String>.from(report.pageOrientations),
      clientId:            report.clientId,
      siteId:              report.siteId,
      status:    ReportStatus.draft,
      createdAt: now,
      updatedAt: now,
    );

    await _storage.saveSingleReport(newReport);
    await SecureQuotaStore.recordNewReportCreation(state.length);
    await load();
    return newReport;
  }

  Future<void> deleteReport(String id) async {
    await _storage.deleteReport(id);
    // تحديث state محلياً بدون قراءة الملفات
    if (mounted) state = state.where((r) => r.id != id).toList();
  }

  // ─── مساعدات خاصة ────────────────────────────────────────────────────────────
  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

  /// رقم تقرير فريد يعتمد على timestamp بدلاً من state.length لتجنب التكرار
  String _generateReportNumber(DateTime now) {
    final suffix = now.millisecondsSinceEpoch.toString().substring(7);
    return 'REP-${now.year}-$suffix';
  }
}

enum ReportSortOrder {
  updatedAtDesc,
  updatedAtAsc,
  nameAsc,
  nameDesc,
}

final reportsProvider = StateNotifierProvider<ReportsNotifier, List<Report>>((ref) {
  return ReportsNotifier(ref.watch(storageServiceProvider));
});

/// معرّف التقرير النشط حالياً في المحرر
final activeReportIdProvider = StateProvider<String?>((ref) => null);

/// التقرير النشط — يعيد null إذا لم يُعثر عليه (بدلاً من reports.first)
final activeReportProvider = Provider<Report?>((ref) {
  final id = ref.watch(activeReportIdProvider);
  if (id == null) return null;
  final reports = ref.watch(reportsProvider);
  try {
    return reports.firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
});

// ========================
// Derived Relationship Providers — الترابط المنطقي
// ========================

/// تقارير عميل معين — مرتبة من الأحدث للأقدم
final reportsForClientProvider = Provider.family<List<Report>, String>((ref, clientId) {
  if (clientId.isEmpty) return [];
  final reports = ref.watch(reportsProvider);
  return reports
      .where((r) => r.clientId == clientId)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

/// زيارات موقع معين — مرتبة حسب رقم الزيارة (الأحدث أولاً)
final visitsForSiteProvider = Provider.family<List<Report>, String>((ref, siteId) {
  if (siteId.isEmpty) return [];
  final reports = ref.watch(reportsProvider);
  return reports
      .where((r) => r.siteId == siteId)
      .toList()
    ..sort((a, b) {
      final numA = int.tryParse(a.visitNumber) ?? 0;
      final numB = int.tryParse(b.visitNumber) ?? 0;
      return numB.compareTo(numA);
    });
});

/// رقم الزيارة التالية لموقع معين
final nextVisitNumberProvider = Provider.family<int, String>((ref, siteId) {
  if (siteId.isEmpty) return 1;
  final visits = ref.watch(visitsForSiteProvider(siteId));
  if (visits.isEmpty) return 1;
  final maxNum = visits.map((r) => int.tryParse(r.visitNumber) ?? 0).reduce((a, b) => a > b ? a : b);
  return maxNum + 1;
});

/// إحصائيات العميل
class ClientStats {
  final int sitesCount;
  final int reportsCount;
  final int completedReports;
  final int draftReports;
  final String? lastVisitDate;

  const ClientStats({
    this.sitesCount = 0,
    this.reportsCount = 0,
    this.completedReports = 0,
    this.draftReports = 0,
    this.lastVisitDate,
  });
}

final clientStatsProvider = Provider.family<ClientStats, String>((ref, clientId) {
  if (clientId.isEmpty) return const ClientStats();
  final sites = ref.watch(sitesForClientProvider(clientId));
  final reports = ref.watch(reportsForClientProvider(clientId));
  final completed = reports.where((r) => r.isCompleted).length;
  return ClientStats(
    sitesCount: sites.length,
    reportsCount: reports.length,
    completedReports: completed,
    draftReports: reports.length - completed,
    lastVisitDate: reports.isNotEmpty ? reports.first.visitDate : null,
  );
});

/// المواقع مجمعة حسب المحافظة
final sitesGroupedByGovernorateProvider = Provider<Map<String, List<Site>>>((ref) {
  final sites = ref.watch(sitesProvider);
  final grouped = <String, List<Site>>{};
  for (final site in sites) {
    final key = site.governorate.isNotEmpty ? site.governorate : 'غير محدد';
    grouped.putIfAbsent(key, () => []).add(site);
  }
  return grouped;
});

/// عدد المسودات غير المكتملة
final draftReportsProvider = Provider<List<Report>>((ref) {
  final reports = ref.watch(reportsProvider);
  return reports
      .where((r) => !r.isCompleted)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
});

/// تقرير بمعرفه
final reportByIdProvider = Provider.family<Report?, String>((ref, reportId) {
  final reports = ref.watch(reportsProvider);
  try {
    return reports.firstWhere((r) => r.id == reportId);
  } catch (_) {
    return null;
  }
});
