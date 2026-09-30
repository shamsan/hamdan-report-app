import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/constants/yemen_locations.dart';
import '../../models/report.dart';
import '../../models/inspection_item.dart';
import '../../models/measurement_data.dart';
import '../../models/signature_data.dart';
import '../../state/branding_provider.dart';
import '../../state/reports_provider.dart';
import '../preview/pdf_preview_screen.dart';
import '../common/page_layout_settings_sheet.dart';
import 'widgets/inspection_table_widget.dart';
import 'widgets/battery_matrix_widget.dart';
import 'widgets/photo_section_widget.dart';
import 'widgets/signature_pad_dialog.dart';
import 'widgets/needs_section_widget.dart';
import 'widgets/inverter_data_entry_widget.dart';
import 'widgets/pv_combiner_boxes_widget.dart';
import '../session/maintenance_session_screen.dart';
import '../../core/widgets/yemeni_phone_field.dart';
import '../../models/site.dart';
import '../../state/sites_provider.dart';

class ReportEditorScreen extends ConsumerStatefulWidget {
  final String reportId;

  const ReportEditorScreen({super.key, required this.reportId});

  @override
  ConsumerState<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends ConsumerState<ReportEditorScreen> {
  late Report _report;
  bool _isLoaded = false;
  int _activePhase = 0;
  int _opSectionTab = 0; // 0: الإنفرترات, 1: منظمات الشحن, 2: البارامترات العامة والمراقبة
  Timer? _saveDebounce;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _isNavigatingToPreview = false;
  late final AppLifecycleListener _lifecycleListener;
  int _roleRevision = 0;
  bool _isMasterSpecsUnlocked = false;
  bool _allInspectionGroupsExpanded = false;
  int _groupsExpansionRevision = 0;

  Future<void> _syncSpecsToMasterSite() async {
    if (_report.siteId.isEmpty) return;
    final sites = ref.read(sitesProvider);
    final site = sites.where((s) => s.id == _report.siteId).firstOrNull;
    if (site == null) {
      UiHelpers.showErrorSnackBar(context, 'تعذر العثور على سجل الموقع الأصلي في قاعدة البيانات');
      return;
    }

    final updatedSite = site.copyWith(
      systemSpecs: _report.systemSpecs,
      projectName: _report.projectInfo.projectName.isNotEmpty ? _report.projectInfo.projectName : site.projectName,
      contractNumber: _report.contractNumber.isNotEmpty ? _report.contractNumber : site.contractNumber,
      implementingContractor: _report.projectInfo.implementingContractor.isNotEmpty ? _report.projectInfo.implementingContractor : site.implementingContractor,
      funderNameAr: _report.projectInfo.funder.isNotEmpty ? _report.projectInfo.funder : site.funderNameAr,
    );

    await ref.read(sitesProvider.notifier).updateSite(updatedSite);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    UiHelpers.showSuccessSnackBar(context, 'تم تحديث سجل الموقع الأصلي بنجاح بالمواصفات الجديدة ✓');
    setState(() {
      _isMasterSpecsUnlocked = false;
    });
  }

  void _flushPendingSave() {
    if (_hasUnsavedChanges) {
      _saveDebounce?.cancel();
      ref.read(reportsProvider.notifier).updateReport(_report);
      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _isSaving = false;
        });
      }
    }
  }

  String _getOpValue(String id, {String fallback = ''}) {
    final match = _report.operationalData.firstWhere(
      (o) => o.id == id,
      orElse: () => OperationalData(id: id, parameter: '', unit: '', measuredValue: fallback, standardRange: ''),
    );
    return match.measuredValue;
  }

  void _setOpValue(String id, String val, {String parameter = '', String unit = '', String range = ''}) {
    final list = List<OperationalData>.from(_report.operationalData);
    final idx = list.indexWhere((o) => o.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(measuredValue: val);
    } else {
      list.add(OperationalData(
        id: id,
        parameter: parameter,
        unit: unit,
        measuredValue: val,
        standardRange: range,
        status: 'طبيعي',
      ));
    }
    _onReportUpdated(_report.copyWith(operationalData: list));
  }

  void _batchSetOpValues(Map<String, String> entries, {String unit = '', String range = ''}) {
    final list = List<OperationalData>.from(_report.operationalData);
    for (final e in entries.entries) {
      final idx = list.indexWhere((o) => o.id == e.key);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(measuredValue: e.value);
      } else {
        list.add(OperationalData(
          id: e.key,
          parameter: '',
          unit: unit,
          measuredValue: e.value,
          standardRange: range,
          status: 'طبيعي',
        ));
      }
    }
    _onReportUpdated(_report.copyWith(operationalData: list));
  }

  late final TextEditingController _funderNameArController;
  late final TextEditingController _funderNameEnController;
  late final TextEditingController _ministryNameArController;
  late final TextEditingController _ministryNameEnController;
  late final TextEditingController _contractorNameArController;
  late final TextEditingController _contractorSubtitleArController;
  late final TextEditingController _contractorNameEnController;

  @override
  void initState() {
    super.initState();
    _loadReport();
    final branding = ref.read(brandingProvider);
    _funderNameArController = TextEditingController(text: _report.funderNameAr ?? branding.rightLogoNameAr);
    _funderNameEnController = TextEditingController(text: _report.funderNameEn ?? branding.rightLogoNameEn);
    _ministryNameArController = TextEditingController(text: _report.ministryNameAr ?? branding.ministryNameAr);
    _ministryNameEnController = TextEditingController(text: _report.ministryNameEn ?? branding.ministryNameEn);
    _contractorNameArController = TextEditingController(text: _report.contractorNameAr ?? branding.contractorNameAr);
    _contractorSubtitleArController = TextEditingController(text: _report.contractorSubtitleAr ?? branding.contractorSubtitleAr);
    _contractorNameEnController = TextEditingController(text: _report.contractorNameEn ?? branding.contractorNameEn);

    // معيار دورة حياة التطبيق: الحفظ الفوري عند تصغير التطبيق أو وضع السكون أو ورود مكالمة
    _lifecycleListener = AppLifecycleListener(
      onPause: _flushPendingSave,
      onInactive: _flushPendingSave,
      onDetach: _flushPendingSave,
      onHide: _flushPendingSave,
    );
  }

  @override
  void dispose() {
    _flushPendingSave();
    _lifecycleListener.dispose();
    _saveDebounce?.cancel();
    _funderNameArController.dispose();
    _funderNameEnController.dispose();
    _ministryNameArController.dispose();
    _ministryNameEnController.dispose();
    _contractorNameArController.dispose();
    _contractorSubtitleArController.dispose();
    _contractorNameEnController.dispose();
    super.dispose();
  }

  void _loadReport() {
    final reports = ref.read(reportsProvider);
    final match = reports.where((r) => r.id == widget.reportId);
    if (match.isEmpty) {
      if (reports.isNotEmpty) {
        _report = reports.first;
      }
      _isLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر العثور على التقرير المطلوب')),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }
    final loaded = match.first;
    // Clean up any legacy default blank placeholder attendance records (empty name and no signature)
    final cleanedAttendance = loaded.attendanceList.where((a) =>
      a.name.trim().isNotEmpty || (a.signatureBase64 != null && a.signatureBase64!.trim().isNotEmpty)
    ).toList();
    if (cleanedAttendance.length != loaded.attendanceList.length) {
      final reindexed = <AttendanceRecord>[];
      for (int i = 0; i < cleanedAttendance.length; i++) {
        reindexed.add(cleanedAttendance[i].copyWith(serialNo: i + 1));
      }
      _report = loaded.copyWith(attendanceList: reindexed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(reportsProvider.notifier).updateReport(_report);
      });
    } else {
      _report = loaded;
    }
    _isLoaded = true;
  }

  void _onReportUpdated(Report updated) {
    setState(() {
      _report = updated;
      _isSaving = true;
      _hasUnsavedChanges = true;
    });
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () async {
      await ref.read(reportsProvider.notifier).updateReport(updated);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasUnsavedChanges = false;
        });
      }
    });
  }

  Future<void> _pickReportLogo(String slot) async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
        final b64 = base64Encode(res.files.first.bytes!);
        if (slot == 'funder') {
          _onReportUpdated(_report.copyWith(funderLogoBase64: b64));
        } else if (slot == 'ministry') {
          _onReportUpdated(_report.copyWith(ministryLogoBase64: b64));
        } else if (slot == 'contractor') {
          _onReportUpdated(_report.copyWith(contractorLogoBase64: b64));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث شعار التقرير بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اختيار الشعار: $e')),
        );
      }
    }
  }

  void _clearReportLogo(String slot) {
    if (slot == 'funder') {
      _onReportUpdated(_report.copyWith(clearFunderLogo: true));
    } else if (slot == 'ministry') {
      _onReportUpdated(_report.copyWith(clearMinistryLogo: true));
    } else if (slot == 'contractor') {
      _onReportUpdated(_report.copyWith(clearContractorLogo: true));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم استعادة الشعار الافتراضي')),
    );
  }

  Future<void> _pickStamp() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
        final b64 = base64Encode(res.files.first.bytes!);
        _onReportUpdated(_report.copyWith(
          approvalStatement: _report.approvalStatement.copyWith(stampBase64: b64),
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحميل الختم الرسمي للمنشأة بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل صورة الختم: $e')),
        );
      }
    }
  }

  void _clearStamp() {
    _onReportUpdated(_report.copyWith(
      approvalStatement: _report.approvalStatement.copyWith(stampBase64: ''),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف الختم الرسمي')),
    );
  }

  Future<void> _openMaintenanceSession() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceSessionScreen(reportId: _report.id),
      ),
    );
    _loadReport();
    if (mounted) setState(() {});
  }

  Future<void> _openPdfPreview() async {
    if (_isNavigatingToPreview) return;
    _isNavigatingToPreview = true;
    _flushPendingSave();
    HapticFeedback.lightImpact();

    try {
      final updated = await Navigator.push<Report>(
        context,
        MaterialPageRoute(builder: (_) => PdfPreviewScreen(report: _report)),
      );
      if (updated != null && mounted) {
        setState(() {
          _report = updated;
        });
        ref.read(reportsProvider.notifier).updateReport(updated);
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigatingToPreview = false);
      }
    }
  }

  Future<bool?> _showUnsavedChangesDialog() async {
    HapticFeedback.mediumImpact();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.solarGold, size: 24),
            SizedBox(width: 8),
            Text('تغييرات غير محفوظة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'لديك تعديلات قيد الإدخال لم تُحفظ بعد على التقرير. كيف تود المتابعة؟',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('متابعة التحرير', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.statusRejected),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تجاهل التغييرات'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('حفظ وخروج', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              _flushPendingSave();
              Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showPageSetupSheet() async {
    final result = await PageLayoutSettingsSheet.show(
      context,
      initialOrientations: _report.pageOrientations,
      activeCombinerBoxesCount: _report.activeCombinerBoxes.length,
    );
    if (result != null && mounted) {
      _onReportUpdated(_report.copyWith(pageOrientations: result.pageOrientations));
    }
  }

  Widget _buildPageSetupControl(int pageNumber, String pageTitle) {
    final rawPref = (_report.pageOrientations[pageNumber] ?? (pageNumber == 9 ? 'a4_landscape' : 'a4_portrait')).toLowerCase();
    final isLandscape = rawPref.contains('landscape') || rawPref.contains('horizontal');
    final isA3 = rawPref.contains('a3');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(
            isLandscape ? Icons.crop_landscape_rounded : Icons.crop_portrait_rounded,
            size: 18,
            color: AppTheme.primaryNavy,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '$pageTitle: ${isA3 ? "A3" : "A4"} - ${isLandscape ? "أفقي" : "عمودي"}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                maxLines: 1,
              ),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              foregroundColor: AppTheme.brandCyan,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.tune_rounded, size: 15),
            label: const Text('تغيير التنسيق', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            onPressed: _showPageSetupSheet,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = _report.completionRatio;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _showUnsavedChangesDialog();
        if (shouldLeave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _report.facilityInfo.facilityName.isNotEmpty
                    ? _report.facilityInfo.facilityName
                    : _report.title,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'عقد: ${_report.contractNumber} • تقرير: ${_report.reportNumber}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on_rounded, color: AppTheme.solarGold),
              tooltip: 'جلسة الفحص الميداني',
              onPressed: _openMaintenanceSession,
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white),
              tooltip: 'إعدادات مقاسات وتنسيق الصفحات (A4 / A3)',
              onPressed: _showPageSetupSheet,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              tooltip: 'معاينة وتصدير PDF',
              onPressed: _openPdfPreview,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tooltip: 'خيارات إضافية',
              onSelected: (val) {
                if (val == 'duplicate') _showDuplicateDialog();
                if (val == 'session') _openMaintenanceSession();
                if (val == 'preview') _openPdfPreview();
                if (val == 'pages') _showPageSetupSheet();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18, color: AppTheme.brandCyan),
                      SizedBox(width: 8),
                      Text('نسخ وتعديل كتقرير جديد', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'session',
                  child: Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 18, color: AppTheme.solarGold),
                      SizedBox(width: 8),
                      Text('جلسة الفحص التفاعلية', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'preview',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppTheme.primaryNavy),
                      SizedBox(width: 8),
                      Text('معاينة وتصدير PDF', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'pages',
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryNavy),
                      SizedBox(width: 8),
                      Text('تنسيق ومقاسات الصفحات', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // Top Executive Progress & Save Status Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: AdaptiveContentContainer(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _isSaving
                            ? AppTheme.statusFollowup.withValues(alpha: 0.12)
                            : AppTheme.statusGood.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSaving) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: AppTheme.statusFollowup,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'جارٍ الحفظ...',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.statusFollowup,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            const Icon(Icons.check_circle, size: 12, color: AppTheme.statusGood),
                            const SizedBox(width: 4),
                            const Text(
                              'محفوظ',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.statusGood,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'الإنجاز: ${(progress * 100).toInt()}%',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 55,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brandCyan),
                                minHeight: 5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5-Phase Sequential Workflow Navigation Tabs
            Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AdaptiveContentContainer(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPhaseTab(0, Icons.apartment, '1. بيانات الموقع والمنظومة', incompleteCount: _report.phase1IncompleteCount),
                      const SizedBox(width: 8),
                      _buildPhaseTab(1, Icons.checklist_rtl, '2. الفحص الميداني (10 نماذج)', incompleteCount: _report.phase2IncompleteCount),
                      const SizedBox(width: 8),
                      _buildPhaseTab(2, Icons.battery_charging_full, '3. قياسات البطاريات والأداء', incompleteCount: _report.phase3IncompleteCount),
                      const SizedBox(width: 8),
                      _buildPhaseTab(3, Icons.inventory_2_rounded, '4. الاحتياجات والمواد (${_report.requestedNeeds.length})', incompleteCount: _report.requestedNeeds.length),
                      const SizedBox(width: 8),
                      _buildPhaseTab(4, Icons.verified_user, '5. الحضور والاعتماد والتواقيع', incompleteCount: _report.phase5IncompleteCount),
                    ],
                  ),
                ),
              ),
            ),

            // Active Phase Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AdaptiveContentContainer(
                  child: Column(
                    children: [
                      if (_activePhase == 0) _buildPhase1Content(),
                      if (_activePhase == 1) _buildPhase2Content(),
                      if (_activePhase == 2) _buildPhase3Content(),
                      if (_activePhase == 3) _buildPhase4NeedsContent(),
                      if (_activePhase == 4) _buildPhase5SignaturesContent(),

                      const SizedBox(height: 24),
                      // Phase Navigation Footer
                      Row(
                        children: [
                          if (_activePhase > 0) ...[
                            Expanded(
                              flex: 1,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: Text(
                                  'المرحلة $_activePhase',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _activePhase--);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (_activePhase < 4)
                            Expanded(
                              flex: _activePhase > 0 ? 2 : 1,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.arrow_forward, size: 16),
                                label: Text(
                                  'المرحلة ${_activePhase + 2}: ${_getPhaseShortTitle(_activePhase + 1)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _activePhase++);
                                },
                              ),
                            )
                          else
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.solarGold,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                                label: const Text(
                                  'معاينة التقرير المعتمد (PDF)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () async {
                                  final updated = await Navigator.push<Report>(
                                    context,
                                    MaterialPageRoute(builder: (_) => PdfPreviewScreen(report: _report)),
                                  );
                                  if (updated != null && mounted) {
                                    setState(() {
                                      _report = updated;
                                    });
                                    ref.read(reportsProvider.notifier).updateReport(updated);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppTheme.borderSubtle)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                      side: const BorderSide(color: AppTheme.primaryNavy, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 17, color: AppTheme.solarGold),
                    label: const Text(
                      'جلسة الفحص',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    onPressed: _openMaintenanceSession,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.solarGold,
                      foregroundColor: AppTheme.textDark,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 17, color: AppTheme.primaryNavy),
                    label: const Text(
                      'معاينة وتصدير PDF',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                    ),
                    onPressed: _openPdfPreview,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  String _getPhaseShortTitle(int phase) {
    switch (phase) {
      case 0:
        return 'بيانات الموقع';
      case 1:
        return 'الفحص الميداني';
      case 2:
        return 'البطاريات والتشغيل';
      case 3:
        return 'الاحتياجات والمواد';
      case 4:
        return 'الاعتماد والتواقيع';
      default:
        return '';
    }
  }

  Widget _buildPhaseTab(int index, IconData icon, String title, {int incompleteCount = 0}) {
    final isSelected = _activePhase == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activePhase = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNavy : AppTheme.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryNavy),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(width: 8),
            if (incompleteCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber.shade300 : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.amber.shade100 : const Color(0xFFF59E0B),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$incompleteCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFF78350F) : const Color(0xFFB45309),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green.shade400 : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check,
                      size: 11,
                      color: isSelected ? Colors.white : const Color(0xFF15803D),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'مكتمل',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Phase 1: Project, Facility & Solar Specs ---
  Widget _buildPhase1Content() {
    final sites = ref.watch(sitesProvider);
    final linkedSite = _report.siteId.isNotEmpty
        ? sites.where((s) => s.id == _report.siteId).firstOrNull
        : null;
    final isLinkedToSite = linkedSite != null || _report.siteId.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLinkedToSite) ...[
          _buildVerifiedMasterSpecsCard(linkedSite),
          const SizedBox(height: 12),
          _buildSectionCard(
            icon: Icons.assignment_turned_in_rounded,
            title: 'بيانات الزيارة الميدانية الحالية',
            subtitle: 'تاريخ ووقت الزيارة الميدانية، رقم الزيارة، والشخص المستلم في المرفق',
            child: _buildFieldVisitDetailsForm(),
          ),
          if (_isMasterSpecsUnlocked) ...[
            const SizedBox(height: 12),
            _buildSectionCard(
              icon: Icons.edit_note_rounded,
              title: 'تعديل بيانات المشروع والعقد (استثنائي)',
              subtitle: 'تعديل اسم المشروع، رقم العقد 1010720، المنفذ، والمقاول لهذا التقرير',
              child: _buildProjectInfoForm(),
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              icon: Icons.tune_rounded,
              title: 'تعديل المواصفات الفنية للمنظومة (استثنائي)',
              subtitle: 'القدرة: ${_report.systemSpecs.capacityKw} • الألواح: ${_report.systemSpecs.panelsCountAndWatt}',
              child: _buildSystemSpecsForm(),
            ),
          ],
        ] else ...[
          _buildSectionCard(
            icon: Icons.apartment,
            title: '1. بيانات التقرير والمشروع والعقد',
            subtitle: 'اسم المشروع، رقم العقد 1010720، المنفذ، والمقاول',
            child: _buildProjectInfoForm(),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            icon: Icons.local_hospital,
            title: '2. بيانات المنشأة الخدمية والزيارة',
            subtitle: '${_report.facilityInfo.facilityName} • ${_report.facilityInfo.category}',
            child: _buildFacilityInfoForm(),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            icon: Icons.solar_power,
            title: '3. المواصفات الفنية لمنظومة الطاقة الشمسية المنفذة',
            subtitle: 'القدرة: ${_report.systemSpecs.capacityKw} • الألواح: ${_report.systemSpecs.panelsCountAndWatt}',
            child: _buildSystemSpecsForm(),
          ),
        ],
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.branding_watermark_rounded,
          title: 'تخصيص شعارات وترويسة هذا التقرير (الممول • الوزارة • المقاول)',
          subtitle: 'تخصيص شعارات وأسماء الجهات الرسمية المستقلة الخاصة بهذا التقرير فقط',
          child: _buildReportBrandingSection(),
        ),
      ],
    );
  }

  Widget _buildVerifiedMasterSpecsCard(Site? site) {
    final specs = _report.systemSpecs;
    final siteName = site?.displayName ?? (_report.facilityInfo.facilityName.isNotEmpty ? _report.facilityInfo.facilityName : 'الموقع المحدد');
    final p = _report.projectInfo;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isMasterSpecsUnlocked ? AppTheme.statusFollowup.withValues(alpha: 0.6) : AppTheme.borderSubtle,
          width: _isMasterSpecsUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isMasterSpecsUnlocked
                      ? AppTheme.statusFollowup.withValues(alpha: 0.12)
                      : AppTheme.statusGood.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isMasterSpecsUnlocked ? Icons.lock_open_rounded : Icons.verified_user_rounded,
                  color: _isMasterSpecsUnlocked ? AppTheme.statusFollowup : AppTheme.statusGood,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'سجل الموقع والمواصفات الفنية',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _isMasterSpecsUnlocked
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isMasterSpecsUnlocked
                                  ? AppTheme.statusFollowup.withValues(alpha: 0.5)
                                  : AppTheme.statusGood.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isMasterSpecsUnlocked ? Icons.edit_note_rounded : Icons.shield_rounded,
                                size: 12,
                                color: _isMasterSpecsUnlocked ? AppTheme.statusFollowup : AppTheme.statusGood,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isMasterSpecsUnlocked ? 'تعديل استثنائي مفتوح' : 'موثق من الموقع',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isMasterSpecsUnlocked ? AppTheme.statusFollowup : AppTheme.statusGood,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'مرتبط بـ: $siteName (${_report.facilityInfo.category.isNotEmpty ? _report.facilityInfo.category : (site?.category ?? "CAT 8")})',
                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Specs summary chips grid
          // Specs summary chips grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecGridItem(
                        icon: Icons.bolt_rounded,
                        iconColor: AppTheme.solarGold,
                        label: 'قدرة المنظومة الكلية',
                        value: specs.capacityKw.isNotEmpty ? specs.capacityKw : '57.6 kW',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSpecGridItem(
                        icon: Icons.solar_power_rounded,
                        iconColor: AppTheme.brandCyan,
                        label: 'الألواح والقدرة',
                        value: specs.panelsCountAndWatt.isNotEmpty ? specs.panelsCountAndWatt : '96 × 600Wp',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecGridItem(
                        icon: Icons.battery_charging_full_rounded,
                        iconColor: const Color(0xFF10B981),
                        label: 'بنك البطاريات',
                        value: specs.batteryUnitsCapacity.isNotEmpty
                            ? '${specs.batteryUnitsCapacity} (${specs.batteryUnitsCount.isNotEmpty ? specs.batteryUnitsCount : ""})'
                            : '2500 Ah (96 × 2V)',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSpecGridItem(
                        icon: Icons.swap_horiz_rounded,
                        iconColor: AppTheme.primaryNavy,
                        label: 'العواكس والمحولات',
                        value: specs.invertersCount.isNotEmpty
                            ? '${specs.invertersCount} × ${specs.invertersCapacity}'
                            : '6 × 10 KVA',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecGridItem(
                        icon: Icons.tune_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        label: 'منظمات الشحن',
                        value: specs.chargeControllersCount.isNotEmpty
                            ? '${specs.chargeControllersCount} × ${specs.chargeControllersCapacity}'
                            : '13 × 100 A',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSpecGridItem(
                        icon: Icons.tag_rounded,
                        iconColor: AppTheme.textSecondary,
                        label: 'رقم العقد الرسمي',
                        value: _report.contractNumber.isNotEmpty
                            ? _report.contractNumber
                            : (site?.contractNumber.isNotEmpty == true ? site!.contractNumber : '1010720'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecGridItem(
                        icon: Icons.location_on_outlined,
                        iconColor: Colors.deepOrange,
                        label: 'الموقع الجغرافي',
                        value: '${_report.effectiveGovernorate} - ${_report.effectiveDistrict}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSpecGridItem(
                        icon: Icons.account_balance_outlined,
                        iconColor: AppTheme.primaryNavy,
                        label: 'الممول والمنفذ',
                        value: '${p.funder.isNotEmpty ? p.funder : "UNOPS"} • ${p.implementingContractor.isNotEmpty ? p.implementingContractor : "المقاول"}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions Row (Lock / Unlock / Sync)
          if (!_isMasterSpecsUnlocked) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'المواصفات مقفلة ومحمية لمنع التعديل العفوي أثناء الزيارة.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isMasterSpecsUnlocked = true);
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 15, color: AppTheme.statusFollowup),
                  label: const Text('تعديل استثنائي للمواصفات', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.statusFollowup)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.statusFollowup),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 6),
                      Text(
                        'وضع التعديل الاستثنائي مفعل',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكنك الآن تعديل بيانات المشروع والمنظومة في النماذج المفتوحة بالأسفل. إذا كانت هذه التغييرات فيزيائية دائمة للموقع (كاستبدال عاكس أو إضافة ألواح)، يرجى الضغط على زر "مزامنة التعديلات مع سجل الموقع الأصلي".',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _syncSpecsToMasterSite,
                          icon: const Icon(Icons.sync_rounded, size: 16),
                          label: const Text('مزامنة مع سجل الموقع الأصلي', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isMasterSpecsUnlocked = false);
                        },
                        icon: const Icon(Icons.lock_outline_rounded, size: 15),
                        label: const Text('إعادة القفل', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textDark,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecGridItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldVisitDetailsForm() {
    final f = _report.facilityInfo;
    final now = DateTime.now();
    final todayStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    final currentVisitInt = int.tryParse(_report.visitNumber.isNotEmpty ? _report.visitNumber : f.visitNumber) ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── بطاقة موعد وتوقيت الزيارة الميدانية ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_available_rounded, size: 18, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'توقيت وجدولة الزيارة الميدانية',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                        Text(
                          'تاريخ التنفيذ، فترة الفحص، وتتابع رقم الزيارة',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Picker with quick 'اليوم' button
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await UiHelpers.showArabicDatePicker(
                          context,
                          currentValue: f.visitDate,
                        );
                        if (picked != null) {
                          _onReportUpdated(_report.copyWith(
                            visitDate: picked,
                            facilityInfo: f.copyWith(visitDate: picked),
                          ));
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 17, color: AppTheme.primaryNavy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('تاريخ الزيارة الميدانية *', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    f.visitDate.isNotEmpty ? f.visitDate : 'اختر التاريخ...',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: f.visitDate.isNotEmpty ? AppTheme.textDark : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      _onReportUpdated(_report.copyWith(
                        visitDate: todayStr,
                        facilityInfo: f.copyWith(visitDate: todayStr),
                      ));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                      side: const BorderSide(color: AppTheme.primaryNavy, width: 1.1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.today_rounded, size: 15),
                    label: const Text('اليوم', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Visit Time Field with Quick Preset Chips
              TextFormField(
                key: ValueKey('visit_time_${_report.visitTime}'),
                initialValue: _report.visitTime,
                decoration: InputDecoration(
                  labelText: 'وقت وفترة الزيارة الميدانية',
                  hintText: 'مثال: 09:30 ص أو 09:00 ص - 01:00 م',
                  prefixIcon: const Icon(Icons.access_time_rounded, size: 18, color: AppTheme.brandCyan),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(visitTime: v)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Text('أوقات مقترحة: ', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  ...['09:00 ص', '11:00 ص', '01:00 م', '09:00 ص - 02:00 م'].map((timePreset) => InkWell(
                    onTap: () {
                      _onReportUpdated(_report.copyWith(visitTime: timePreset));
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.brandCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        timePreset,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                      ),
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 12),

              // Visit Number Stepper + Installation Date
              Row(
                children: [
                  // Visit Number Stepper
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'رقم الزيارة',
                            style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppTheme.primaryNavy),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: currentVisitInt > 1
                                      ? () {
                                          final newNum = (currentVisitInt - 1).toString();
                                          _onReportUpdated(_report.copyWith(
                                            visitNumber: newNum,
                                            facilityInfo: f.copyWith(visitNumber: newNum),
                                          ));
                                        }
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    'زيارة #$currentVisitInt',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryNavy),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    final newNum = (currentVisitInt + 1).toString();
                                    _onReportUpdated(_report.copyWith(
                                      visitNumber: newNum,
                                      facilityInfo: f.copyWith(visitNumber: newNum),
                                    ));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Installation Date Picker
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await UiHelpers.showArabicDatePicker(
                          context,
                          currentValue: f.installationDate,
                        );
                        if (picked != null) {
                          _onReportUpdated(_report.copyWith(
                            facilityInfo: f.copyWith(installationDate: picked),
                          ));
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.solar_power_outlined, size: 16, color: AppTheme.solarGold),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('تاريخ تركيب المنظومة', style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    f.installationDate.isNotEmpty ? f.installationDate : 'اختياري (ص 10)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: f.installationDate.isNotEmpty ? AppTheme.textDark : AppTheme.textMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (f.installationDate.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  _onReportUpdated(_report.copyWith(
                                    facilityInfo: f.copyWith(installationDate: ''),
                                  ));
                                },
                                child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ─── بطاقة ممثل المنشأة الحاضر للاعتماد والتوقيع ─────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.solarGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_pin_circle_rounded, size: 18, color: AppTheme.solarGold),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ممثل المنشأة / المستلم الميداني',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                        Text(
                          'الشخص الحاضر في الموقع للاعتماد والتوقيع الرسمي (صفحة 10)',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // اسم ممثل المنشأة
              TextFormField(
                initialValue: f.contactPerson,
                decoration: InputDecoration(
                  labelText: 'اسم ممثل المرفق الحاضر في الموقع *',
                  hintText: 'مثال: د. طارق محمد الحيدري (مدير المركز)',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppTheme.primaryNavy),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                ),
                onChanged: (v) {
                  final curRep = _report.approvalStatement.beneficiaryRepName;
                  final shouldSync = curRep.isEmpty || curRep == f.contactPerson;
                  _onReportUpdated(_report.copyWith(
                    facilityInfo: f.copyWith(contactPerson: v),
                    approvalStatement: shouldSync
                        ? _report.approvalStatement.copyWith(beneficiaryRepName: v)
                        : _report.approvalStatement,
                  ));
                },
              ),
              const SizedBox(height: 10),

              // رقم هاتف المسؤول المباشر مع دعم جهات الاتصال وبدون إعادة بناء المتحكم
              YemeniPhoneField(
                initialValue: f.phone,
                label: 'رقم هاتف المسؤول المباشر للتواصل',
                hint: '777 123 456',
                onChanged: (v) => _onReportUpdated(_report.copyWith(facilityInfo: f.copyWith(phone: v))),
                onContactPicked: (contact) {
                  if (contact.name != null && f.contactPerson.isEmpty) {
                    final curRep = _report.approvalStatement.beneficiaryRepName;
                    final shouldSync = curRep.isEmpty || curRep == f.contactPerson;
                    _onReportUpdated(_report.copyWith(
                      facilityInfo: f.copyWith(
                        contactPerson: contact.name!,
                        phone: contact.phone.isNotEmpty ? contact.phone : f.phone,
                      ),
                      approvalStatement: shouldSync
                          ? _report.approvalStatement.copyWith(beneficiaryRepName: contact.name!)
                          : _report.approvalStatement,
                    ));
                  } else {
                    _onReportUpdated(_report.copyWith(
                      facilityInfo: f.copyWith(
                        phone: contact.phone.isNotEmpty ? contact.phone : f.phone,
                      ),
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportBrandingSection() {
    return Consumer(
      builder: (context, ref, _) {
        final branding = ref.watch(brandingProvider);
        final showRight = _report.showRightLogo ?? branding.showRightLogo;

        // Effective Logos
        final funderLogo = _report.funderLogoBase64 ?? branding.unopsLogoBase64;
        final ministryLogo = _report.ministryLogoBase64 ?? branding.facilityLogoBase64;
        final contractorLogo = _report.contractorLogoBase64 ?? branding.contractorLogoBase64;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notice box
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.brandCyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.brandCyan, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تخصيص الترويسة والشعارات أدناه خاص بهذا التقرير فقط، مما يتيح لك إنشاء تقارير لممولين ومقاولين ووزارات متعددة ومختلفة بكل مرونة.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            // 1. Right Logo (Funder / الممول)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.public, color: AppTheme.brandCyan, size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '1. الشعار الأيمن وبيانات الممول',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: showRight,
                        activeThumbColor: AppTheme.brandCyan,
                        onChanged: (val) {
                          _onReportUpdated(_report.copyWith(showRightLogo: val));
                        },
                      ),
                    ],
                  ),
                  Text(
                    showRight
                        ? 'الشعار مفعل: تظهر الترويسة بثلاثة شعارات (الممول يميناً • الوزارة وسطاً • المقاول يساراً)'
                        : 'تم إلغاء الشعار: تظهر الترويسة بشعارين فقط (الوزارة يميناً • المقاول يساراً)',
                    style: TextStyle(
                      fontSize: 11,
                      color: showRight ? AppTheme.textMuted : AppTheme.statusRejected,
                      fontWeight: showRight ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  if (showRight) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: funderLogo != null && funderLogo.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(base64Decode(funderLogo), fit: BoxFit.contain),
                                )
                              : Image.asset('assets/logos/logo_unops.png', fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.brandCyan,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.upload_file, size: 14),
                                label: const Text('تغيير الشعار', style: TextStyle(fontSize: 11)),
                                onPressed: () => _pickReportLogo('funder'),
                              ),
                              if (_report.funderLogoBase64 != null)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('استعادة الافتراضي', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _clearReportLogo('funder'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Funder Suggestion Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        {
                          'label': 'UNOPS (الأمم المتحدة)',
                          'ar': 'مكتب الأمم المتحدة لخدمات المشاريع - UNOPS',
                          'en': 'United Nations Office for Project Services - UNOPS',
                        },
                        {
                          'label': 'البنك الدولي (World Bank)',
                          'ar': 'البنك الدولي - World Bank',
                          'en': 'World Bank Group',
                        },
                        {
                          'label': 'UNDP (الإنمائي)',
                          'ar': 'برنامج الأمم المتحدة الإنمائي - UNDP',
                          'en': 'United Nations Development Programme - UNDP',
                        },
                        {
                          'label': 'منظمة الصحة العالمية',
                          'ar': 'منظمة الصحة العالمية - WHO',
                          'en': 'World Health Organization - WHO',
                        },
                        {
                          'label': 'اليونيسف (UNICEF)',
                          'ar': 'منظمة الأمم المتحدة للطفولة - UNICEF',
                          'en': 'United Nations Children\'s Fund - UNICEF',
                        },
                      ].map((funder) {
                        final isSelected = _funderNameArController.text == funder['ar'];
                        return ActionChip(
                          avatar: Icon(
                            isSelected ? Icons.check : Icons.account_balance,
                            size: 13,
                            color: isSelected ? AppTheme.statusGood : AppTheme.primaryNavy,
                          ),
                          label: Text(
                            funder['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primaryNavy : AppTheme.textDark,
                            ),
                          ),
                          backgroundColor: isSelected ? AppTheme.statusGood.withValues(alpha: 0.12) : Colors.white,
                          side: BorderSide(
                            color: isSelected ? AppTheme.statusGood.withValues(alpha: 0.5) : AppTheme.borderSubtle,
                          ),
                          onPressed: () {
                            setState(() {
                              _funderNameArController.text = funder['ar']!;
                              _funderNameEnController.text = funder['en']!;
                            });
                            _onReportUpdated(_report.copyWith(
                              funderNameAr: funder['ar']!,
                              funderNameEn: funder['en']!,
                            ));
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _funderNameEnController,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'اسم الجهة الممولة (إنجليزي) - يظهر أولاً بالأسود',
                        hintText: 'e.g. United Nations Office for Project Services',
                        helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                      ),
                      onChanged: (v) => _onReportUpdated(_report.copyWith(funderNameEn: v)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _funderNameArController,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'اسم الجهة الممولة (عربي) - يظهر ثانياً بالأزرق',
                        hintText: 'مثال: مكتب الأمم المتحدة لخدمات المشاريع',
                        helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                      ),
                      onChanged: (v) => _onReportUpdated(_report.copyWith(funderNameAr: v)),
                    ),
                  ],
                ],
              ),
            ),

            // 2. Middle Logo (Ministry / الوزارة أو الجهة المالكة)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance, color: AppTheme.primaryNavy, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          showRight ? '2. الشعار الأوسط وبيانات الوزارة / الجهة المالكة' : '2. الشعار الأيمن وبيانات الوزارة (تم نقله لليمين تلقائياً)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: ministryLogo != null && ministryLogo.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(base64Decode(ministryLogo), fit: BoxFit.contain),
                              )
                            : Image.asset('assets/logos/logo_facility.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryNavy,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.upload_file, size: 14),
                              label: const Text('تغيير الشعار', style: TextStyle(fontSize: 11)),
                              onPressed: () => _pickReportLogo('ministry'),
                            ),
                            if (_report.ministryLogoBase64 != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('استعادة الافتراضي', style: TextStyle(fontSize: 11)),
                                onPressed: () => _clearReportLogo('ministry'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Quick Ministry Suggestion Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      {
                        'label': 'وزارة الصحة العامة والسكان',
                        'ar': 'وزارة الصحة العامة و البيئة',
                        'en': 'Ministry of Public Health and Population',
                      },
                      {
                        'label': 'وزارة التربية والتعليم',
                        'ar': 'وزارة التربية والتعليم والتعليم الفني',
                        'en': 'Ministry of Education',
                      },
                      {
                        'label': 'وزارة الكهرباء والطاقة',
                        'ar': 'وزارة الكهرباء والطاقة المتجددة',
                        'en': 'Ministry of Electricity and Energy',
                      },
                      {
                        'label': 'وزارة المياه والبيئة',
                        'ar': 'وزارة المياه والبيئة',
                        'en': 'Ministry of Water and Environment',
                      },
                      {
                        'label': 'وزارة التعليم العالي',
                        'ar': 'وزارة التعليم العالي والبحث العلمي',
                        'en': 'Ministry of Higher Education and Scientific Research',
                      },
                    ].map((min) {
                      final isSelected = _ministryNameArController.text == min['ar'];
                      return ActionChip(
                        avatar: Icon(
                          isSelected ? Icons.check : Icons.domain,
                          size: 13,
                          color: isSelected ? AppTheme.statusGood : AppTheme.primaryNavy,
                        ),
                        label: Text(
                          min['label']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primaryNavy : AppTheme.textDark,
                          ),
                        ),
                        backgroundColor: isSelected ? AppTheme.statusGood.withValues(alpha: 0.12) : Colors.white,
                        side: BorderSide(
                          color: isSelected ? AppTheme.statusGood.withValues(alpha: 0.5) : AppTheme.borderSubtle,
                        ),
                        onPressed: () {
                          setState(() {
                            _ministryNameArController.text = min['ar']!;
                            _ministryNameEnController.text = min['en']!;
                          });
                          _onReportUpdated(_report.copyWith(
                            ministryNameAr: min['ar']!,
                            ministryNameEn: min['en']!,
                          ));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ministryNameEnController,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'اسم الوزارة / الجهة المالكة (إنجليزي) - يظهر أولاً بالأسود',
                      hintText: 'e.g. Ministry of Public Health and Population',
                      helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                    ),
                    onChanged: (v) => _onReportUpdated(_report.copyWith(ministryNameEn: v)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ministryNameArController,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'اسم الوزارة / الجهة المالكة (عربي) - يظهر ثانياً بالأزرق',
                      hintText: 'مثال: وزارة الصحة العامة والسكان',
                      helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                    ),
                    onChanged: (v) => _onReportUpdated(_report.copyWith(ministryNameAr: v)),
                  ),
                ],
              ),
            ),

            // 3. Left Logo (Contractor / المقاول المنفذ)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.business_center, color: AppTheme.solarGold, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '3. الشعار الأيسر وبيانات المقاول المنفذ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: contractorLogo != null && contractorLogo.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(base64Decode(contractorLogo), fit: BoxFit.contain),
                              )
                            : Image.asset('assets/logos/logo_contractor.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.solarGold,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.upload_file, size: 14),
                              label: const Text('تغيير الشعار', style: TextStyle(fontSize: 11)),
                              onPressed: () => _pickReportLogo('contractor'),
                            ),
                            if (_report.contractorLogoBase64 != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('استعادة الافتراضي', style: TextStyle(fontSize: 11)),
                                onPressed: () => _clearReportLogo('contractor'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contractorNameEnController,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'اسم المقاول المنفذ (إنجليزي) - يظهر أولاً بالأسود',
                      hintText: 'e.g. Al-Etqan Engineering Office',
                      helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                    ),
                    onChanged: (v) => _onReportUpdated(_report.copyWith(contractorNameEn: v)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contractorNameArController,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'اسم المقاول المنفذ (عربي) - يظهر ثانياً بالأزرق',
                      hintText: 'مثال: مكتب الأتقان الهندسي',
                      helperText: 'يدعم 1 أو 2 أو 3 أسطر (اضغط Enter للتقسيم اليدوي)',
                    ),
                    onChanged: (v) => _onReportUpdated(_report.copyWith(
                      contractorNameAr: v,
                      projectInfo: _report.projectInfo.copyWith(implementingContractor: v),
                    )),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _contractorSubtitleArController,
                    decoration: const InputDecoration(
                      labelText: 'الصفة / التتمة (عربي مثل: للخدمات الهندسية وحلول الطاقة)',
                      hintText: 'للخدمات الهندسية وحلول الطاقة',
                    ),
                    onChanged: (v) => _onReportUpdated(_report.copyWith(contractorSubtitleAr: v)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInteractiveSessionBanner() {
    int totalItems = 0;
    int inspectedItems = 0;
    for (final g in _report.inspectionGroups) {
      totalItems += g.items.length;
      inspectedItems += g.items.where((i) => i.status != InspectionStatus.uninspected).length;
    }
    final pct = totalItems > 0 ? (inspectedItems / totalItems * 100).toInt() : 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2942), Color(0xFF1E3A8A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2942).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.solarGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جلسة الفحص والصيانة التفاعلية',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'سير عمل ذكي خطوة بخطوة لمراجعة وتقييم كافة بنود الفحص الـ 123',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'تم إنجاز فحص $inspectedItems من أصل $totalItems بنداً',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.solarGold, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalItems > 0 ? (inspectedItems / totalItems) : 0,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                inspectedItems == totalItems ? AppTheme.statusGood : AppTheme.solarGold,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.solarGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: Icon(inspectedItems == 0 ? Icons.play_arrow_rounded : Icons.flash_on_rounded, size: 20),
              label: Text(
                inspectedItems == 0 ? 'بدء جلسة الفحص التفاعلية الآن 🚀' : 'متابعة جلسة الفحص الميداني ($inspectedItems/$totalItems) ⚡',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MaintenanceSessionScreen(reportId: _report.id),
                  ),
                );
                _loadReport();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Phase 2: Inspection Groups (Models 1 to 10) ---
  Widget _buildPhase2Content() {
    return Column(
      children: [
        _buildInteractiveSessionBanner(),

        // Fast toolbar for 10 models with expand/collapse control
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.table_chart_outlined, size: 18, color: AppTheme.primaryNavy),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'جداول الفحص الميداني (10 نماذج):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: Icon(_allInspectionGroupsExpanded ? Icons.unfold_less : Icons.unfold_more, size: 16),
                label: Text(_allInspectionGroupsExpanded ? 'طي الكل' : 'توسيع الكل', style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  setState(() {
                    _allInspectionGroupsExpanded = !_allInspectionGroupsExpanded;
                    _groupsExpansionRevision++;
                  });
                },
              ),
            ],
          ),
        ),

        ..._report.inspectionGroups.asMap().entries.map((entry) {
          final idx = entry.key;
          final group = entry.value;
          final isComplete = group.completionRatio == 1.0;
          final hasStarted = group.completionRatio > 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSectionCard(
              tileKey: ValueKey('insp_group_${group.groupNumber}_rev$_groupsExpansionRevision'),
              initiallyExpanded: _allInspectionGroupsExpanded,
              icon: Icons.checklist_rounded,
              title: '${idx + 1}. ${group.title}',
              subtitle: 'إنجاز البنود: ${(group.completionRatio * 100).toInt()}% (${group.items.length} بنود)',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFFDCFCE7)
                      : (hasStarted ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isComplete
                        ? const Color(0xFF86EFAC)
                        : (hasStarted ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1)),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isComplete
                      ? 'مكتمل ✓'
                      : (hasStarted ? '${(group.completionRatio * 100).toInt()}%' : 'لم يبدأ'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isComplete
                        ? const Color(0xFF15803D)
                        : (hasStarted ? const Color(0xFF1D4ED8) : AppTheme.textMuted),
                  ),
                ),
              ),
              child: InspectionTableWidget(
                group: group,
                onChanged: (updatedGroup) {
                  final newGroups = List<InspectionGroup>.from(_report.inspectionGroups);
                  newGroups[idx] = updatedGroup;
                  _onReportUpdated(_report.copyWith(inspectionGroups: newGroups));
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- Phase 3: Battery Matrix & Operational Measurements ---
  Widget _buildPhase3Content() {
    return Column(
      children: [
        _buildSectionCard(
          icon: Icons.battery_charging_full,
          title: '10. مصفوفة قياسات خلايا البطاريات (${_report.activeBatteryGroups.length} مجموعات نشطة)',
          subtitle: _report.activeBatteryGroups.length <= 2
              ? 'صفحة واحدة في التقرير - المجموعات: ${_report.activeBatteryGroups.map((g) => "المجموعة $g").join("، ")}'
              : 'صفحتان في التقرير - تغطية 4 مجموعات (96 خلية 2V)',
          child: BatteryMatrixWidget(
            measurements: _report.batteryMeasurements,
            activeGroups: _report.activeBatteryGroups,
            onActiveGroupsChanged: (newGroups) {
              _onReportUpdated(_report.copyWith(activeBatteryGroups: newGroups));
            },
            onChanged: (updatedList) {
              _onReportUpdated(_report.copyWith(batteryMeasurements: updatedList));
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.speed,
          title: '11. بيانات تشغيل المنظومة والإنفرترات (${_report.activeCombinerBoxes.length} منظمات/صناديق)',
          subtitle: 'الحمل على الإنفرتر، فرق الجهد، وشاشات المراقبة',
          child: _buildOperationalDataForm(),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.cable,
          title: '12. قياسات أداء الألواح وصناديق التجميع (${_report.activeCombinerBoxes.length} صناديق نشطة)',
          subtitle: 'تحديد الصناديق المضمنة وقياسات Voc و Isc لكل سلسلة',
          child: _buildStringMeasurementsForm(),
        ),
      ],
    );
  }

  // --- Phase 4: Needs & Requisitions for Next Visit ---
  Widget _buildPhase4NeedsContent() {
    return NeedsSectionWidget(
      report: _report,
      onReportUpdated: _onReportUpdated,
    );
  }

  // --- Phase 5: Signatures, Approval & Photos ---
  Widget _buildPhase5SignaturesContent() {
    return Column(
      children: [
        _buildSectionCard(
          icon: Icons.add_a_photo,
          title: 'معرض الصور التوثيقية الميدانية',
          subtitle: 'الصور الفوتوغرافية لأعمال الصيانة والمنظومة',
          child: PhotoSectionWidget(
            reportId: _report.id,
            photos: _report.photos,
            onChanged: (newPhotos) {
              _onReportUpdated(_report.copyWith(photos: newPhotos));
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.groups_rounded,
          title: 'سجل حضور فريق الصيانة والتنفيذ (صفحة 11)',
          subtitle: 'توثيق أسماء وتخصصات مهندسي وفنيي الصيانة وممثلي المرفق والتوقيع',
          child: _buildAttendanceTeamSection(),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          icon: Icons.assignment_turned_in,
          title: 'إفادة الحضور والتوقيعات الرقمية المعتمدة',
          subtitle: 'المصادقة الرسمية لإدارة المرفق ومهندس الصيانة المسؤول',
          child: _buildSignaturesAndApprovalSection(),
        ),
        const SizedBox(height: 8),
        _buildApprovalActionCard(),
      ],
    );
  }

  Widget _buildApprovalActionCard() {
    final hasEngSig = _report.signatures.any((s) => s.signatureBase64 != null && s.signatureBase64!.isNotEmpty);
    final hasFacSig = _report.approvalStatement.beneficiarySignatureBase64 != null &&
        _report.approvalStatement.beneficiarySignatureBase64!.isNotEmpty;
    final isAlreadyCompleted = _report.status == ReportStatus.completed || _report.status == ReportStatus.exported;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAlreadyCompleted
            ? AppTheme.statusGood.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlreadyCompleted ? AppTheme.statusGood : AppTheme.borderSubtle,
          width: isAlreadyCompleted ? 1.5 : 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAlreadyCompleted
                      ? AppTheme.statusGood.withValues(alpha: 0.15)
                      : AppTheme.primaryNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAlreadyCompleted ? Icons.verified_rounded : Icons.approval_rounded,
                  color: isAlreadyCompleted ? AppTheme.statusGood : AppTheme.primaryNavy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAlreadyCompleted
                          ? 'التقرير معتمد رسمياً كنسخة مكتملة'
                          : 'الاعتماد النهائي للتقرير الفني',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      isAlreadyCompleted
                          ? 'جاهز للتصدير والتسليم لكافة الجهات المشرفة'
                          : 'يقوم بنقل التقرير من حالة المسودة إلى تقرير معتمد مكتمل',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isAlreadyCompleted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.statusGood.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.statusGood, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم اعتماد هذا التقرير وتوثيق كافة التواقيع. لم يعد مسودة قيد التحرير.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.statusGood, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('إلغاء الاعتماد وإعادة الفتح للتعديل', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  final draftReport = _report.copyWith(
                    status: ReportStatus.draft,
                    updatedAt: DateTime.now(),
                  );
                  _onReportUpdated(draftReport);
                  ref.read(reportsProvider.notifier).updateReport(draftReport);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت إعادة فتح التقرير كمسودة لإتاحة التعديل.'),
                      backgroundColor: AppTheme.primaryNavy,
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            if (!hasEngSig || !hasFacSig) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ملاحظة: يفضل استيفاء توقيع مهندس الصيانة وممثل المرفق قبل الاعتماد الرسمي النهائي.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.statusGood,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 1,
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text(
                'اعتماد التقرير رسمياً كنسخة مكتملة ✅',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                final approvedReport = _report.copyWith(
                  status: ReportStatus.completed,
                  updatedAt: DateTime.now(),
                );
                _onReportUpdated(approvedReport);
                ref.read(reportsProvider.notifier).updateReport(approvedReport);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم اعتماد التقرير رسمياً كنسخة مكتملة بنجاح! ✨'),
                    backgroundColor: AppTheme.statusGood,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    bool initiallyExpanded = true,
    Widget? trailing,
    Key? tileKey,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: tileKey,
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryNavy, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppTheme.textDark),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          trailing: trailing,
          childrenPadding: const EdgeInsets.all(16),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildProjectInfoForm() {
    final p = _report.projectInfo;
    return Column(
      children: [
        TextFormField(
          initialValue: p.projectName,
          decoration: const InputDecoration(labelText: 'اسم المشروع الكامل'),
          onChanged: (v) => _onReportUpdated(_report.copyWith(projectInfo: p.copyWith(projectName: v))),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _report.contractNumber,
                decoration: const InputDecoration(labelText: 'رقم العقد'),
                onChanged: (v) => _onReportUpdated(_report.copyWith(contractNumber: v)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: _report.reportNumber,
                decoration: const InputDecoration(labelText: 'رقم التقرير'),
                onChanged: (v) => _onReportUpdated(_report.copyWith(reportNumber: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: p.funder,
                decoration: const InputDecoration(labelText: 'الجهة المنفذة / المشرفة'),
                onChanged: (v) => _onReportUpdated(_report.copyWith(projectInfo: p.copyWith(funder: v))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: p.implementingContractor,
                decoration: const InputDecoration(labelText: 'المقاول المنفذ'),
                onChanged: (v) {
                  _contractorNameArController.text = v;
                  _onReportUpdated(_report.copyWith(
                    contractorNameAr: v,
                    projectInfo: p.copyWith(implementingContractor: v),
                  ));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Consumer(
          builder: (context, ref, _) {
            final branding = ref.watch(brandingProvider);
            final currentShowRight = _report.showRightLogo ?? branding.showRightLogo;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: AppTheme.brandCyan,
                  title: const Text('إظهار الشعار الأيمن في ترويسة التقرير (UNOPS / الممول)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    currentShowRight
                        ? 'الترويسة: (المقاول يساراً • الوزارة وسطاً • الممول يميناً)'
                        : 'الترويسة: (المقاول يساراً • الوزارة يميناً تلقائياً بدل الشعار الملغي)',
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                  ),
                  value: currentShowRight,
                  onChanged: (val) {
                    _onReportUpdated(_report.copyWith(showRightLogo: val));
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFacilityInfoForm() {
    final f = _report.facilityInfo;
    final currentGov = _report.effectiveGovernorate.isNotEmpty ? _report.effectiveGovernorate : 'حجة';
    final availableGovs = YemenLocations.governorates;
    final govList = availableGovs.contains(currentGov) ? availableGovs : [currentGov, ...availableGovs];

    final districts = YemenLocations.getDistrictsFor(currentGov);
    final currentDist = _report.effectiveDistrict.isNotEmpty
        ? _report.effectiveDistrict
        : (districts.isNotEmpty ? districts.first : '');
    final distList = (districts.contains(currentDist) || currentDist.isEmpty)
        ? districts
        : [currentDist, ...districts];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: f.facilityName,
                decoration: const InputDecoration(labelText: 'اسم المنشأة الخدمية (عربي)'),
                onChanged: (v) => _onReportUpdated(_report.copyWith(facilityInfo: f.copyWith(facilityName: v))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: f.facilityNameEnglish,
                decoration: const InputDecoration(labelText: 'Facility Name (English)'),
                onChanged: (v) => _onReportUpdated(_report.copyWith(facilityInfo: f.copyWith(facilityNameEnglish: v))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المحافظة',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    key: ValueKey('gov_$currentGov'),
                    initialValue: govList.contains(currentGov) ? currentGov : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'اختر المحافظة',
                      prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                    ),
                    items: govList.map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    )).toList(),
                    onChanged: (newGov) {
                      if (newGov == null) return;
                      final newDistricts = YemenLocations.getDistrictsFor(newGov);
                      final defaultDist = newDistricts.isNotEmpty ? newDistricts.first : '';
                      _onReportUpdated(_report.copyWith(
                        facilityInfo: f.copyWith(
                          governorate: newGov,
                          directorate: defaultDist,
                        ),
                        projectInfo: _report.projectInfo.copyWith(
                          governorate: newGov,
                          district: defaultDist,
                        ),
                      ));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المديرية',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 5),
                  DropdownButtonFormField<String>(
                    key: ValueKey('dist_${currentGov}_$currentDist'),
                    initialValue: distList.contains(currentDist) ? currentDist : (distList.isNotEmpty ? distList.first : null),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'اختر المديرية',
                      prefixIcon: Icon(Icons.map_outlined, size: 20),
                    ),
                    items: distList.map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    )).toList(),
                    onChanged: (newDist) {
                      if (newDist == null) return;
                      _onReportUpdated(_report.copyWith(
                        facilityInfo: f.copyWith(directorate: newDist),
                        projectInfo: _report.projectInfo.copyWith(district: newDist),
                      ));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: f.category,
                decoration: const InputDecoration(labelText: 'الفئة (Category)'),
                onChanged: (v) => _onReportUpdated(_report.copyWith(facilityInfo: f.copyWith(category: v))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await UiHelpers.showArabicDatePicker(
                    context,
                    currentValue: f.visitDate,
                  );
                  if (picked != null) {
                    _onReportUpdated(_report.copyWith(
                      visitDate: picked,
                      facilityInfo: f.copyWith(visitDate: picked),
                    ));
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الزيارة (YYYY/MM/DD)',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.primaryNavy),
                  ),
                  child: Text(
                    f.visitDate.isNotEmpty ? f.visitDate : 'اختر التاريخ...',
                    style: TextStyle(
                      fontSize: 13,
                      color: f.visitDate.isNotEmpty ? AppTheme.textDark : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _report.visitNumber.isNotEmpty ? _report.visitNumber : f.visitNumber,
                decoration: const InputDecoration(
                  labelText: 'رقم الزيارة *',
                  hintText: 'مثال: 1 أو الزيارة الأولى',
                  prefixIcon: Icon(Icons.numbers_outlined, size: 18),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(
                  visitNumber: v,
                  facilityInfo: f.copyWith(visitNumber: v),
                )),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: _report.visitTime,
                decoration: const InputDecoration(
                  labelText: 'وقت الزيارة',
                  hintText: 'مثال: 09:30 ص',
                  prefixIcon: Icon(Icons.access_time_outlined, size: 18),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(visitTime: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final picked = await UiHelpers.showArabicDatePicker(
              context,
              currentValue: f.installationDate,
            );
            if (picked != null) {
              _onReportUpdated(_report.copyWith(
                facilityInfo: f.copyWith(installationDate: picked),
              ));
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'تاريخ تركيب منظومة الطاقة الشمسية (صفحة 10)',
              hintText: 'يترك فارغاً إذا لم يحدد في إفادة الحضور',
              prefixIcon: const Icon(Icons.solar_power_outlined, size: 18, color: AppTheme.primaryNavy),
              suffixIcon: f.installationDate.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                      tooltip: 'مسح التاريخ (تركه فارغاً)',
                      onPressed: () {
                        _onReportUpdated(_report.copyWith(
                          facilityInfo: f.copyWith(installationDate: ''),
                        ));
                      },
                    )
                  : const Icon(Icons.calendar_month_outlined, size: 18, color: AppTheme.brandCyan),
            ),
            child: Text(
              f.installationDate.isNotEmpty ? f.installationDate : 'فارغ (لم يتم التحديد - يظهر فراغ في التقرير)',
              style: TextStyle(
                fontSize: 13,
                color: f.installationDate.isNotEmpty ? AppTheme.textDark : AppTheme.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // بيانات مسؤول المنشأة وبيانات الاتصال المباشر (Full Width Dedicated Card)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.contact_phone_rounded, size: 18, color: AppTheme.primaryNavy),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مسؤول المنشأة وبيانات التواصل المباشر',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: f.contactPerson,
                decoration: const InputDecoration(
                  labelText: 'مسؤول المنشأة / ممثل المستفيد بالموقع',
                  hintText: 'مثال: د. عبد الله أحمد - مدير المركز',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(facilityInfo: f.copyWith(contactPerson: v))),
              ),
              const SizedBox(height: 12),
              YemeniPhoneField(
                initialValue: f.phone,
                label: 'رقم هاتف مسؤول المنشأة للتواصل',
                hint: '777 123 456',
                onChanged: (v) => _onReportUpdated(_report.copyWith(facilityInfo: f.copyWith(phone: v))),
                onContactPicked: (contact) {
                  if (contact.name != null && f.contactPerson.isEmpty) {
                    _onReportUpdated(_report.copyWith(
                      facilityInfo: f.copyWith(
                        phone: contact.phone,
                        contactPerson: contact.name!,
                      ),
                    ));
                  } else {
                    _onReportUpdated(_report.copyWith(facilityInfo: f.copyWith(phone: contact.phone)));
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemSpecsForm() {
    final s = _report.systemSpecs;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: s.capacityKw,
                decoration: InputDecoration(
                  labelText: 'القدرة الكلية للمنظومة',
                  hintText: '15.0',
                  suffixText: 'kW',
                  prefixIcon: const Icon(Icons.bolt_rounded, size: 18, color: AppTheme.primaryNavy),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(systemSpecs: s.copyWith(capacityKw: v))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: s.panelsCountAndWatt,
                decoration: InputDecoration(
                  labelText: 'عدد الألواح × القدرة',
                  hintText: '32 لوح × 550W',
                  prefixIcon: const Icon(Icons.solar_power_outlined, size: 18, color: AppTheme.brandCyan),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(systemSpecs: s.copyWith(panelsCountAndWatt: v))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: s.batteryBankCapacityAh,
                decoration: InputDecoration(
                  labelText: 'سعة بنك البطاريات',
                  hintText: '2000',
                  suffixText: 'Ah',
                  prefixIcon: const Icon(Icons.battery_charging_full_rounded, size: 18, color: AppTheme.solarGold),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(systemSpecs: s.copyWith(batteryBankCapacityAh: v))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: s.batteryUnitsCountAndVoltage,
                decoration: InputDecoration(
                  labelText: 'عدد خلايا/وحدات البطاريات',
                  hintText: '24 بطارية × 2V',
                  prefixIcon: const Icon(Icons.layers_outlined, size: 18, color: AppTheme.primaryNavy),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(systemSpecs: s.copyWith(batteryUnitsCountAndVoltage: v))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: s.inverterCapacity,
                decoration: InputDecoration(
                  labelText: 'قدرة العاكس (Inverter)',
                  hintText: '10',
                  suffixText: 'kVA',
                  prefixIcon: const Icon(Icons.electric_meter_outlined, size: 18, color: AppTheme.brandCyan),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(systemSpecs: s.copyWith(inverterCapacity: v))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: s.invertersCount,
                decoration: InputDecoration(
                  labelText: 'عدد العواكس',
                  hintText: '2',
                  suffixText: 'عواكس',
                  prefixIcon: const Icon(Icons.format_list_numbered_rounded, size: 18, color: AppTheme.primaryNavy),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _onReportUpdated(_report.copyWith(systemSpecs: s.copyWith(invertersCount: v))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: s.chargeControllerCapacity,
                decoration: InputDecoration(
                  labelText: 'قدرة منظم الشحن (CC)',
                  hintText: '80',
                  suffixText: 'A',
                  prefixIcon: const Icon(Icons.tune_rounded, size: 18, color: AppTheme.solarGold),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) => _onReportUpdated(_report.copyWith(systemSpecs: s.copyWith(chargeControllerCapacity: v))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                initialValue: s.chargeControllersCount,
                decoration: InputDecoration(
                  labelText: 'عدد منظمات الشحن',
                  hintText: '4',
                  suffixText: 'منظمات',
                  prefixIcon: const Icon(Icons.format_list_numbered_rounded, size: 18, color: AppTheme.primaryNavy),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _onReportUpdated(_report.copyWith(systemSpecs: s.copyWith(chargeControllersCount: v))),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOperationalDataForm() {
    // Parse inverters count from system specs
    final invMatch = RegExp(r'\d+').firstMatch(_report.systemSpecs.invertersCount);
    final invCount = invMatch != null ? (int.tryParse(invMatch.group(0)!) ?? 1) : 1;
    final effectiveInvCount = invCount > 0 ? (invCount > 13 ? 13 : invCount) : 1;

    // Parse charge controllers count from system specs
    final ccMatch = RegExp(r'\d+').firstMatch(_report.systemSpecs.chargeControllersCount);
    final ccCount = ccMatch != null ? (int.tryParse(ccMatch.group(0)!) ?? 0) : 0;
    final effectiveCcCount = ccCount > 0 ? (ccCount > 13 ? 13 : ccCount) : (effectiveInvCount > 1 ? effectiveInvCount * 2 : 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageSetupControl(8, 'صفحة 8 (بيانات التشغيل)'),
        const SizedBox(height: 8),

        // Navigation Tabs / Segmented switcher for operational data
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _opSectionTab = 0),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _opSectionTab == 0 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _opSectionTab == 0
                          ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 15, color: _opSectionTab == 0 ? const Color(0xFF16A34A) : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'الإنفرترات ($effectiveInvCount)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: _opSectionTab == 0 ? FontWeight.bold : FontWeight.normal,
                              color: _opSectionTab == 0 ? AppTheme.textDark : Colors.grey[700],
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _opSectionTab = 1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _opSectionTab == 1 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _opSectionTab == 1
                          ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wb_sunny_rounded, size: 15, color: _opSectionTab == 1 ? const Color(0xFFD97706) : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'منظمات الشحن ($effectiveCcCount)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: _opSectionTab == 1 ? FontWeight.bold : FontWeight.normal,
                              color: _opSectionTab == 1 ? AppTheme.textDark : Colors.grey[700],
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _opSectionTab = 2),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _opSectionTab == 2 ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _opSectionTab == 2
                          ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tune_rounded, size: 15, color: _opSectionTab == 2 ? const Color(0xFF2563EB) : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'المراقبة والحرارة',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: _opSectionTab == 2 ? FontWeight.bold : FontWeight.normal,
                              color: _opSectionTab == 2 ? AppTheme.textDark : Colors.grey[700],
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // TAB 0: INVERTERS
        if (_opSectionTab == 0) ...[
          InverterDataEntryWidget(
            report: _report,
            onReportUpdated: _onReportUpdated,
          ),
        ],

        // TAB 1: CHARGE CONTROLLERS
        if (_opSectionTab == 1) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'أدخل قياسات كل منظم شحن بشكل مستقل (تيار المصفوفة، جهد المصفوفة، وحالة المراقبة):',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                  ),
                ),
                if (effectiveCcCount > 1)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFFCD34D)),
                    ),
                    icon: const Icon(Icons.copy_all, size: 14, color: Color(0xFFD97706)),
                    label: const Text('نسخ #1 للكل', style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final i1 = _getOpValue('op_cc_i_1', fallback: _getOpValue('op_cc_i'));
                      final v1 = _getOpValue('op_cc_v_1', fallback: _getOpValue('op_cc_v'));
                      final updates = <String, String>{};
                      for (int u = 2; u <= effectiveCcCount; u++) {
                        if (i1.isNotEmpty) updates['op_cc_i_$u'] = i1;
                        if (v1.isNotEmpty) updates['op_cc_v_$u'] = v1;
                      }
                      if (updates.isNotEmpty) {
                        _batchSetOpValues(updates);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم نسخ التيار والجهد من منظم الشحن #1 إلى باقي المنظمات ($effectiveCcCount)')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
          ...List.generate(effectiveCcCount, (i) {
            final u = i + 1;
            final iVal = _getOpValue('op_cc_i_$u', fallback: u == 1 ? _getOpValue('op_cc_i') : '');
            final vVal = _getOpValue('op_cc_v_$u', fallback: u == 1 ? _getOpValue('op_cc_v') : '');
            final monVal = _getOpValue('op_cc_mon_$u', fallback: 'true');
            final isMon = monVal != 'false' && monVal != '0' && monVal != 'لا';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('منظم الشحن #$u', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          _setOpValue('op_cc_mon_$u', isMon ? 'false' : 'true', parameter: 'شاشة المراقبة منظم #$u');
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: isMon,
                              activeColor: const Color(0xFFD97706),
                              onChanged: (val) {
                                _setOpValue('op_cc_mon_$u', val == true ? 'true' : 'false', parameter: 'شاشة المراقبة منظم #$u');
                              },
                            ),
                            const Text('متصل بشاشة المراقبة', style: TextStyle(fontSize: 11.5, color: AppTheme.textDark)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: iVal,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'تيار المصفوفة (Adc)',
                            hintText: '60 - 100',
                            suffixText: 'Adc',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            _setOpValue('op_cc_i_$u', v, parameter: 'التيار المنتج بمصفوفة الألواح #$u', unit: 'Adc');
                            if (u == 1) _setOpValue('op_cc_i', v, parameter: 'التيار المنتج بمصفوفة الألواح لمنظم الشحن', unit: 'Adc');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: vVal,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'جهد المصفوفة (Vdc)',
                            hintText: '150 - 250',
                            suffixText: 'Vdc',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            _setOpValue('op_cc_v_$u', v, parameter: 'فرق جهد مصفوفة الألواح #$u', unit: 'Vdc');
                            if (u == 1) _setOpValue('op_cc_v', v, parameter: 'فرق جهد مصفوفة الألواح لمنظم الشحن', unit: 'Vdc');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],

        // TAB 2: GENERAL TELEMETRY & MONITORING
        if (_opSectionTab == 2) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monitor_heart_outlined, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'شاشة المراقبة والبارامترات العامة للموقع:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _getOpValue('op_freq'),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'تردد التيار (Frequency)',
                          hintText: '49.8 - 50.2',
                          suffixText: 'Hz',
                          isDense: true,
                        ),
                        onChanged: (v) => _setOpValue('op_freq', v, parameter: 'تردد التيار المتردد (Frequency)', unit: 'Hz'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: _getOpValue('op_temp'),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'حرارة غرفة التحكم والبطاريات',
                          hintText: '20 - 25',
                          suffixText: '°C',
                          isDense: true,
                        ),
                        onChanged: (v) => _setOpValue('op_temp', v, parameter: 'درجة حرارة غرفة البطاريات والتحكم', unit: '°C'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('مطابقة قراءات شاشة المراقبة مع الواقع الميداني', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    subtitle: const Text('تظهر كإشارة صح في السطر الأخير من نموذج التشغيل في التقرير', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    value: _getOpValue('op_mon_match', fallback: 'true') != 'false',
                    activeThumbColor: const Color(0xFF16A34A),
                    onChanged: (val) {
                      _setOpValue('op_mon_match', val ? 'true' : 'false', parameter: 'مطابقة القراءات مع الواقع');
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStringMeasurementsForm() {
    return PvCombinerBoxesWidget(
      report: _report,
      onReportUpdated: _onReportUpdated,
      pageSetupControl: _buildPageSetupControl(9, 'صفحة 9 (قياسات أداء الألواح)'),
    );
  }

  Widget _buildSignaturesAndApprovalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageSetupControl(10, 'صفحة 10 (إفادة الحضور والتواقيع)'),
        const Text(
          'التوقيعات الرقمية المعتمدة للتقرير:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
        ),
        const SizedBox(height: 8),
        ..._report.signatures.asMap().entries.map((entry) {
          final idx = entry.key;
          final sig = entry.value;
          final hasSig = sig.signatureBase64 != null && sig.signatureBase64!.isNotEmpty;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: hasSig ? AppTheme.statusGood.withValues(alpha: 0.4) : AppTheme.borderSubtle,
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Role, Name, and Status Badge (Responsive & Clean)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: hasSig ? AppTheme.statusGood.withValues(alpha: 0.12) : AppTheme.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasSig ? Icons.verified_rounded : Icons.edit_note_rounded,
                          size: 18,
                          color: hasSig ? AppTheme.statusGood : AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sig.role,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sig.signerName.isNotEmpty ? sig.signerName : 'لم يتم إدخال الاسم بعد',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: sig.signerName.isNotEmpty ? AppTheme.textDark : AppTheme.textMuted,
                                fontWeight: sig.signerName.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge (Non-overflowing pill)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasSig ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasSig ? Colors.green.shade400 : Colors.amber.shade400,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasSig ? Icons.check_circle_rounded : Icons.schedule_rounded,
                              size: 11,
                              color: hasSig ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasSig ? 'معتمد رقمياً' : 'بانتظار التوقيع',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: hasSig ? Colors.green.shade800 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Row 2: Signature Preview & Actions
                  Row(
                    children: [
                      if (hasSig)
                        Container(
                          width: 85,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppTheme.borderSubtle),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Builder(builder: (context) {
                            final bytes = UiHelpers.safeDecodeBase64(sig.signatureBase64);
                            if (bytes != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.memory(bytes, fit: BoxFit.contain),
                              );
                            }
                            return const Icon(Icons.broken_image_outlined, size: 20, color: AppTheme.textMuted);
                          }),
                        ),
                      const Spacer(),
                      if (hasSig)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.statusRejected, size: 20),
                          tooltip: 'حذف التوقيع',
                          onPressed: () {
                            final list = List<ReportSignature>.from(_report.signatures);
                            list[idx] = sig.copyWith(signatureBase64: '');

                            final isEng = sig.role.contains('مهندس') || sig.role.contains('صيانة') || sig.role.contains('مقاول');
                            final isBen = sig.role.contains('مستفيد') || sig.role.contains('مرفق') || sig.role.contains('مدير');
                            ApprovalStatement stmt = _report.approvalStatement;
                            if (isEng) {
                              stmt = stmt.copyWith(contractorSignatureBase64: '');
                            }
                            if (isBen) {
                              stmt = stmt.copyWith(beneficiarySignatureBase64: '');
                            }
                            _onReportUpdated(_report.copyWith(signatures: list, approvalStatement: stmt));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم حذف توقيع (${sig.role})')),
                            );
                          },
                        ),
                      if (hasSig) const SizedBox(width: 4),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasSig ? AppTheme.primaryNavy : AppTheme.brandCyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                          elevation: 0,
                        ),
                        icon: Icon(hasSig ? Icons.edit_rounded : Icons.draw_rounded, size: 15),
                        label: Text(
                          hasSig ? 'تعديل التوقيع' : 'إضافة التوقيع الرقمي',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => SignaturePadDialog(
                              role: sig.role,
                              signerName: sig.signerName,
                              existingSignatureBase64: sig.signatureBase64,
                              onCleared: () {
                                final list = List<ReportSignature>.from(_report.signatures);
                                list[idx] = sig.copyWith(signatureBase64: '');

                                final isEng = sig.role.contains('مهندس') || sig.role.contains('صيانة') || sig.role.contains('مقاول');
                                final isBen = sig.role.contains('مستفيد') || sig.role.contains('مرفق') || sig.role.contains('مدير');
                                ApprovalStatement stmt = _report.approvalStatement;
                                if (isEng) {
                                  stmt = stmt.copyWith(contractorSignatureBase64: '');
                                }
                                if (isBen) {
                                  stmt = stmt.copyWith(beneficiarySignatureBase64: '');
                                }
                                _onReportUpdated(_report.copyWith(signatures: list, approvalStatement: stmt));
                              },
                              onSaved: (base64) {
                                final list = List<ReportSignature>.from(_report.signatures);
                                list[idx] = sig.copyWith(signatureBase64: base64);

                                final isEng = sig.role.contains('مهندس') || sig.role.contains('صيانة') || sig.role.contains('مقاول');
                                final isBen = sig.role.contains('مستفيد') || sig.role.contains('مرفق') || sig.role.contains('مدير');
                                ApprovalStatement stmt = _report.approvalStatement;
                                if (isEng) {
                                  stmt = stmt.copyWith(contractorSignatureBase64: base64);
                                }
                                if (isBen) {
                                  stmt = stmt.copyWith(beneficiarySignatureBase64: base64);
                                }
                                _onReportUpdated(_report.copyWith(signatures: list, approvalStatement: stmt));
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.approval_rounded, color: AppTheme.primaryNavy, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'الختم الرسمي للمنشأة / المرفق',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                      ),
                    ],
                  ),
                  if (_report.approvalStatement.stampBase64 != null && _report.approvalStatement.stampBase64!.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.statusRejected),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('حذف الختم', style: TextStyle(fontSize: 11)),
                      onPressed: _clearStamp,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'يظهر الختم الرسمي المعتمد في صفحة 10 (إفادة الحضور) بجوار توقيع إدارة المنشأة المعتمد ومصادقة الاستلام.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(38),
                      border: Border.all(color: AppTheme.borderSubtle, width: 1.5),
                    ),
                    child: (_report.approvalStatement.stampBase64 != null && _report.approvalStatement.stampBase64!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(38),
                            child: Builder(builder: (context) {
                              final bytes = UiHelpers.safeDecodeBase64(_report.approvalStatement.stampBase64);
                              if (bytes != null) {
                                return Image.memory(bytes, fit: BoxFit.contain);
                              }
                              return const Icon(Icons.broken_image_outlined, size: 32, color: AppTheme.textMuted);
                            }),
                          )
                        : const Center(
                            child: Icon(Icons.verified_outlined, size: 32, color: AppTheme.textMuted),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandCyan,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: Text(
                            (_report.approvalStatement.stampBase64 != null && _report.approvalStatement.stampBase64!.isNotEmpty)
                                ? 'تغيير صورة الختم'
                                : 'تحميل صورة الختم الرسمي',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: _pickStamp,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'يدعم ملفات الصور (PNG, JPG) بخلفية شفافة أو بيضاء',
                          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Dedicated Beneficiary Approval & Signature Card (Page 10 Attendance Statement)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Page Tag
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.brandCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppTheme.brandCyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'مصادقة واعتماد ممثل المنشأة والمستفيد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.brandCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'صفحة 10',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'تظهر هذه البيانات والتوقيع في إفادة الحضور الرسمية (صفحة 10) وتذييل صفحات التقرير المعتمدة.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
              ),
              const SizedBox(height: 16),

              // Full-Width Arabic Name Field
              TextFormField(
                key: const ValueKey('ben_rep_name_field'),
                initialValue: _report.approvalStatement.beneficiaryRepName.isNotEmpty
                    ? _report.approvalStatement.beneficiaryRepName
                    : _report.facilityInfo.contactPerson,
                decoration: InputDecoration(
                  labelText: 'اسم ممثل المنشأة / المستفيد (الاسم الكامل) *',
                  hintText: 'مثال: عنتر حسن ابكر',
                  prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppTheme.brandCyan),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) {
                  _onReportUpdated(_report.copyWith(
                    approvalStatement: _report.approvalStatement.copyWith(beneficiaryRepName: v),
                  ));
                },
              ),
              const SizedBox(height: 12),

              // Full-Width Arabic Role Field
              TextFormField(
                key: ValueKey('ben_rep_role_rev_$_roleRevision'),
                initialValue: _report.approvalStatement.beneficiaryRepRole.isNotEmpty
                    ? _report.approvalStatement.beneficiaryRepRole
                    : 'مدير المنشأة',
                decoration: InputDecoration(
                  labelText: 'المنصب / الصفة الرسمية (Title) *',
                  hintText: 'مثال: مدير المركز الصحي',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppTheme.brandCyan),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) {
                  _onReportUpdated(_report.copyWith(
                    approvalStatement: _report.approvalStatement.copyWith(beneficiaryRepRole: v),
                  ));
                },
              ),
              const SizedBox(height: 8),

              // Quick-Select Role Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'مدير المنشأة',
                  'ممثل المستفيد',
                  'مدير المركز الصحي',
                  'مسؤول الصيانة بالموقع',
                  'مهندس الموقع',
                ].map((roleOption) {
                  final isSelected = (_report.approvalStatement.beneficiaryRepRole.isNotEmpty
                          ? _report.approvalStatement.beneficiaryRepRole
                          : 'مدير المنشأة') ==
                      roleOption;
                  return ChoiceChip(
                    label: Text(roleOption, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppTheme.textDark)),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryNavy,
                    backgroundColor: const Color(0xFFF1F5F9),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _roleRevision++);
                        _onReportUpdated(_report.copyWith(
                          approvalStatement: _report.approvalStatement.copyWith(beneficiaryRepRole: roleOption),
                        ));
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // English Name & Title (Cleanly structured section)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.translate_outlined, size: 16, color: AppTheme.textMuted),
                        SizedBox(width: 6),
                        Text(
                          'البيانات باللغة الإنجليزية (اختياري للتقارير الثنائية)',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: _report.approvalStatement.beneficiaryRepNameEn,
                      decoration: InputDecoration(
                        labelText: 'الاسم بالإنجليزي (Name in English)',
                        hintText: 'e.g. Dr. Antar Hassan Abkar',
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) {
                        _onReportUpdated(_report.copyWith(
                          approvalStatement: _report.approvalStatement.copyWith(beneficiaryRepNameEn: v),
                        ));
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: _report.approvalStatement.beneficiaryRepRoleEn,
                      decoration: InputDecoration(
                        labelText: 'المنصب بالإنجليزي (Title in English)',
                        hintText: 'e.g. Health Center Director',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) {
                        _onReportUpdated(_report.copyWith(
                          approvalStatement: _report.approvalStatement.copyWith(beneficiaryRepRoleEn: v),
                        ));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Installation Date Picker with Clear Button
              InkWell(
                onTap: () async {
                  final picked = await UiHelpers.showArabicDatePicker(
                    context,
                    currentValue: _report.facilityInfo.installationDate,
                  );
                  if (picked != null) {
                    _onReportUpdated(_report.copyWith(
                      facilityInfo: _report.facilityInfo.copyWith(installationDate: picked),
                    ));
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاريخ تركيب منظومة الطاقة الشمسية (صفحة 10)',
                    hintText: 'يترك فارغاً إذا لم يحدد',
                    prefixIcon: const Icon(Icons.solar_power_outlined, size: 18, color: AppTheme.brandCyan),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: _report.facilityInfo.installationDate.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                            tooltip: 'مسح التاريخ (تركه فارغاً)',
                            onPressed: () {
                              _onReportUpdated(_report.copyWith(
                                facilityInfo: _report.facilityInfo.copyWith(installationDate: ''),
                              ));
                            },
                          )
                        : const Icon(Icons.calendar_month_outlined, size: 18, color: AppTheme.brandCyan),
                  ),
                  child: Text(
                    _report.facilityInfo.installationDate.isNotEmpty
                        ? _report.facilityInfo.installationDate
                        : 'فارغ (لم يحدد - يظهر فراغ في التقرير)',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _report.facilityInfo.installationDate.isNotEmpty ? AppTheme.textDark : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Beneficiary Digital Signature Box
              Builder(builder: (context) {
                final benSig = _report.approvalStatement.beneficiarySignatureBase64;
                final hasBenSig = benSig != null && benSig.isNotEmpty;
                final repName = _report.approvalStatement.beneficiaryRepName.isNotEmpty
                    ? _report.approvalStatement.beneficiaryRepName
                    : (_report.facilityInfo.contactPerson.isNotEmpty
                        ? _report.facilityInfo.contactPerson
                        : 'ممثل المنشأة');

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasBenSig ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasBenSig ? AppTheme.statusApproved.withValues(alpha: 0.3) : AppTheme.borderSubtle,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Signature Status Row
                      Row(
                        children: [
                          Icon(
                            hasBenSig ? Icons.check_circle_rounded : Icons.pending_outlined,
                            size: 16,
                            color: hasBenSig ? AppTheme.statusApproved : AppTheme.statusPending,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasBenSig ? 'توقيع ممثل المنشأة معتمد رقمياً' : 'توقيع ممثل المنشأة (بانتظار التوقيع)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: hasBenSig ? AppTheme.statusApproved : AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 96,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: hasBenSig ? AppTheme.statusApproved.withValues(alpha: 0.4) : AppTheme.borderSubtle,
                              ),
                            ),
                            child: hasBenSig
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Builder(builder: (context) {
                                      final bytes = UiHelpers.safeDecodeBase64(benSig);
                                      if (bytes != null) {
                                        return Image.memory(bytes, fit: BoxFit.contain);
                                      }
                                      return const Icon(Icons.broken_image_outlined, size: 24, color: AppTheme.textMuted);
                                    }),
                                  )
                                : const Center(
                                    child: Icon(Icons.draw_outlined, size: 24, color: AppTheme.textMuted),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasBenSig ? AppTheme.primaryNavy : AppTheme.brandCyan,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: Icon(hasBenSig ? Icons.edit_note_rounded : Icons.draw_rounded, size: 16),
                              label: Text(
                                hasBenSig ? 'تعديل التوقيع' : 'إضافة التوقيع الرقمي',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => SignaturePadDialog(
                                    role: 'ممثل المنشأة / المستفيد',
                                    signerName: repName,
                                    existingSignatureBase64: benSig,
                                    onCleared: () {
                                      final updatedSigs = _report.signatures.map((s) {
                                        if (s.id == 'sig_fac' || s.role.contains('مستفيد') || s.role.contains('مرفق') || s.role.contains('مدير')) {
                                          return s.copyWith(signatureBase64: '');
                                        }
                                        return s;
                                      }).toList();

                                      _onReportUpdated(_report.copyWith(
                                        signatures: updatedSigs,
                                        approvalStatement: _report.approvalStatement.copyWith(
                                          beneficiarySignatureBase64: '',
                                        ),
                                      ));
                                    },
                                    onSaved: (base64) {
                                      final updatedSigs = _report.signatures.map((s) {
                                        if (s.id == 'sig_fac' || s.role.contains('مستفيد') || s.role.contains('مرفق') || s.role.contains('مدير')) {
                                          return s.copyWith(signatureBase64: base64, signerName: repName);
                                        }
                                        return s;
                                      }).toList();

                                      _onReportUpdated(_report.copyWith(
                                        signatures: updatedSigs,
                                        approvalStatement: _report.approvalStatement.copyWith(
                                          beneficiarySignatureBase64: base64,
                                          beneficiaryRepName: repName,
                                        ),
                                      ));
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          if (hasBenSig) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.statusRejected, size: 20),
                              tooltip: 'حذف التوقيع',
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: const EdgeInsets.all(8),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: AppTheme.statusRejected.withValues(alpha: 0.3)),
                                ),
                              ),
                              onPressed: () {
                                final updatedSigs = _report.signatures.map((s) {
                                  if (s.id == 'sig_fac' || s.role.contains('مستفيد') || s.role.contains('مرفق') || s.role.contains('مدير')) {
                                    return s.copyWith(signatureBase64: '');
                                  }
                                  return s;
                                }).toList();

                                _onReportUpdated(_report.copyWith(
                                  signatures: updatedSigs,
                                  approvalStatement: _report.approvalStatement.copyWith(
                                    beneficiarySignatureBase64: '',
                                  ),
                                ));
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTeamSection() {
    final list = _report.attendanceList;
    final signedCount = list.where((a) => a.signatureBase64 != null && a.signatureBase64!.isNotEmpty).length;
    final totalCount = list.length;
    final progressRatio = totalCount > 0 ? (signedCount / totalCount) : 0.0;
    final isAllSigned = totalCount > 0 && signedCount == totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageSetupControl(11, 'صفحة 11 (كشف حضور وتوقيعات الفريق)'),
        // Header with Actions (Responsive & Overflow-Free)
        Row(
          children: [
            const Icon(Icons.people_alt_rounded, size: 18, color: AppTheme.primaryNavy),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'أعضاء الفريق المسجلون ($totalCount):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (totalCount > 0)
              IconButton(
                tooltip: 'مسح قائمة الفريق',
                icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppTheme.statusRejected),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.all(7),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('مسح قائمة أعضاء الفريق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      content: const Text('هل أنت متأكد من مسح جميع أعضاء الفريق المسجلين؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRejected),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _onReportUpdated(_report.copyWith(attendanceList: const []));
                          },
                          child: const Text('مسح الكل', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandCyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.person_add_rounded, size: 15),
              label: const Text('إضافة عضو', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddAttendanceDialog(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Signatures Progress & Status Overview Bar
        if (totalCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isAllSigned ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAllSigned ? Colors.green.shade300 : Colors.amber.shade300,
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isAllSigned ? Icons.verified_rounded : Icons.pending_actions_rounded,
                      size: 18,
                      color: isAllSigned ? Colors.green.shade700 : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAllSigned
                            ? 'اكتملت جميع توقيعات أعضاء الفريق بنجاح ($signedCount من $totalCount)'
                            : 'اكتمال التوقيعات: $signedCount من أصل $totalCount عضو',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAllSigned ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAllSigned ? Colors.green.shade700 : Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(progressRatio * 100).round()}% تم التوقيع',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    minHeight: 6,
                    backgroundColor: Colors.black.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isAllSigned ? Colors.green.shade600 : Colors.amber.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                const Icon(Icons.people_outline, size: 36, color: AppTheme.textMuted),
                const SizedBox(height: 6),
                const Text('لم يتم إضافة أي عضو لفريق الصيانة بعد', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                  onPressed: () => _showAddAttendanceDialog(),
                  child: const Text('إضافة عضو جديد الآن', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          )
        else
          ...list.asMap().entries.map((entry) {
            final idx = entry.key;
            final att = entry.value;
            final hasSig = att.signatureBase64 != null && att.signatureBase64!.isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasSig ? Colors.green.shade600 : Colors.amber.shade400,
                  width: hasSig ? 1.6 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: hasSig ? Colors.green.withValues(alpha: 0.06) : Colors.amber.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header: Serial, Name, Status Badge & Actions
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    decoration: BoxDecoration(
                      color: hasSig ? const Color(0xFFF0FDF4) : const Color(0xFFFFFDF5),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: hasSig ? Colors.green.shade700 : Colors.amber.shade800,
                          child: Text(
                            '${att.serialNo}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                att.name.isNotEmpty ? att.name : 'لم يتم إدخال الاسم',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 2),
                              // Status pill badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasSig ? Colors.green.shade100 : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: hasSig ? Colors.green.shade400 : Colors.amber.shade400, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasSig ? Icons.verified_rounded : Icons.schedule_rounded,
                                      size: 11,
                                      color: hasSig ? Colors.green.shade800 : Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      hasSig ? 'معتمد بالتوقيع الرقمي ✅' : 'في انتظار التوقيع ⏳',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: hasSig ? Colors.green.shade800 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Quick Action Buttons
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.primaryNavy),
                          tooltip: 'تعديل البيانات',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          onPressed: () => _showAddAttendanceDialog(existing: att, index: idx),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                          tooltip: 'حذف العضو',
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            final updated = List<AttendanceRecord>.from(_report.attendanceList);
                            updated.removeAt(idx);
                            final finalList = <AttendanceRecord>[];
                            for (int i = 0; i < updated.length; i++) {
                              final item = updated[i];
                              finalList.add(AttendanceRecord(
                                serialNo: i + 1,
                                name: item.name,
                                role: item.role,
                                affiliation: item.affiliation,
                                signatureBase64: item.signatureBase64,
                                notes: item.notes,
                              ));
                            }
                            _onReportUpdated(_report.copyWith(attendanceList: finalList));
                          },
                        ),
                      ],
                    ),
                  ),

                  // Member Chips: Role & Affiliation
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (att.role.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 240),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.engineering_outlined, size: 12, color: AppTheme.primaryNavy),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    att.role,
                                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (att.affiliation.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 240),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.brandCyan.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business_outlined, size: 12, color: AppTheme.brandCyan),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    att.affiliation,
                                    style: const TextStyle(fontSize: 10.5, color: AppTheme.primaryNavy),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (att.notes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(att.notes, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700)),
                          ),
                      ],
                    ),
                  ),

                  // State-dependent Signing Panel
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Builder(builder: (context) {
                      if (!hasSig) {
                        // BEFORE SIGNING STATE: Inviting, high-visibility Action Button
                        return InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => SignaturePadDialog(
                                role: att.role,
                                signerName: att.name,
                                existingSignatureBase64: att.signatureBase64,
                                onCleared: () {
                                  final updated = List<AttendanceRecord>.from(_report.attendanceList);
                                  updated[idx] = att.copyWith(signatureBase64: '');
                                  _onReportUpdated(_report.copyWith(attendanceList: updated));
                                },
                                onSaved: (base64) {
                                  final updated = List<AttendanceRecord>.from(_report.attendanceList);
                                  updated[idx] = att.copyWith(signatureBase64: base64);
                                  _onReportUpdated(_report.copyWith(attendanceList: updated));
                                },
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade300, width: 1.2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.draw_rounded, size: 17, color: Colors.amber.shade900),
                                const SizedBox(width: 8),
                                Text(
                                  'اضغط هنا للتوقيع الرقمي لعضو الفريق الآن ✍️',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // AFTER SIGNING STATE: Official Verified Presentation Panel
                        final bytes = UiHelpers.safeDecodeBase64(att.signatureBase64);
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200, width: 1.0),
                          ),
                          child: Row(
                            children: [
                              // Signature Preview Box
                              Container(
                                width: 110,
                                height: 50,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                ),
                                child: bytes != null
                                    ? Image.memory(bytes, fit: BoxFit.contain)
                                    : const Icon(Icons.broken_image_outlined, size: 20, color: AppTheme.textMuted),
                              ),
                              const SizedBox(width: 10),
                              // Verified details & Quick Actions
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.statusGood),
                                        SizedBox(width: 4),
                                        Text(
                                          'توقيع معتمد وموثق',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.statusGood,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        // Edit signature
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.edit_rounded, size: 12),
                                          label: const Text('تعديل', style: TextStyle(fontSize: 10.5)),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => SignaturePadDialog(
                                                role: att.role,
                                                signerName: att.name,
                                                existingSignatureBase64: att.signatureBase64,
                                                onCleared: () {
                                                  final updated = List<AttendanceRecord>.from(_report.attendanceList);
                                                  updated[idx] = att.copyWith(signatureBase64: '');
                                                  _onReportUpdated(_report.copyWith(attendanceList: updated));
                                                },
                                                onSaved: (base64) {
                                                  final updated = List<AttendanceRecord>.from(_report.attendanceList);
                                                  updated[idx] = att.copyWith(signatureBase64: base64);
                                                  _onReportUpdated(_report.copyWith(attendanceList: updated));
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        // Delete signature
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.statusRejected,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.delete_outline_rounded, size: 12),
                                          label: const Text('مسح', style: TextStyle(fontSize: 10.5)),
                                          onPressed: () {
                                            final updated = List<AttendanceRecord>.from(_report.attendanceList);
                                            updated[idx] = att.copyWith(signatureBase64: '');
                                            _onReportUpdated(_report.copyWith(attendanceList: updated));
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showAddAttendanceDialog({AttendanceRecord? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final roleCtrl = TextEditingController(text: existing?.role ?? 'مهندس صيانة المنظومة (رئيس الفريق)');
    final affCtrl = TextEditingController(text: existing?.affiliation ?? 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة');
    final notesCtrl = TextEditingController(text: existing?.notes ?? 'حاضر');
    String? sigBase64 = existing?.signatureBase64;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: AppTheme.brandCyan, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        existing == null ? 'إضافة عضو فريق صيانة جديد' : 'تعديل بيانات عضو الفريق',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المتدرب / الفني / المهندس *',
                    hintText: 'مثال: م. أحمد سعيد العنسي',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الصفة / التخصص (Role) *',
                    prefixIcon: Icon(Icons.engineering_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'مهندس صيانة المنظومة (رئيس الفريق)',
                    'فني كهرباء وطاقة شمسية',
                    'فني بطاريات وتكييف',
                    'مدير المنشأة (ممثل المستفيد)',
                  ].map((role) {
                    final isSel = roleCtrl.text == role;
                    return ActionChip(
                      avatar: Icon(
                        isSel ? Icons.check : Icons.person_outline,
                        size: 13,
                        color: isSel ? AppTheme.statusGood : AppTheme.brandCyan,
                      ),
                      label: Text(
                        role,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? AppTheme.primaryNavy : AppTheme.textDark,
                        ),
                      ),
                      backgroundColor: isSel ? AppTheme.statusGood.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isSel ? AppTheme.statusGood.withValues(alpha: 0.5) : AppTheme.borderSubtle,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () {
                        setModalState(() {
                          roleCtrl.text = role;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: affCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الجهة التابع لها',
                    hintText: 'مثال: مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة أو المرفق الخدمي',
                    prefixIcon: Icon(Icons.business_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
                    'وزارة الصحة العامة والسكان',
                    'إدارة المرفق الصحي',
                    'وزارة التربية والتعليم',
                  ].map((aff) {
                    final isSel = affCtrl.text == aff;
                    return ActionChip(
                      avatar: Icon(
                        isSel ? Icons.check : Icons.domain,
                        size: 13,
                        color: isSel ? AppTheme.statusGood : AppTheme.brandCyan,
                      ),
                      label: Text(
                        aff,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? AppTheme.primaryNavy : AppTheme.textDark,
                        ),
                      ),
                      backgroundColor: isSel ? AppTheme.statusGood.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isSel ? AppTheme.statusGood.withValues(alpha: 0.5) : AppTheme.borderSubtle,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () {
                        setModalState(() {
                          affCtrl.text = aff;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الملاحظات / حالة الحضور',
                    hintText: 'مثال: حاضر ومصادق',
                    prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'حاضر',
                    'حاضر ومصادق',
                    'مستلم التقرير',
                    'تم التدريب بنجاح',
                  ].map((note) {
                    final isSel = notesCtrl.text == note;
                    return ActionChip(
                      avatar: Icon(
                        isSel ? Icons.check : Icons.edit_note,
                        size: 13,
                        color: isSel ? AppTheme.statusGood : AppTheme.brandCyan,
                      ),
                      label: Text(
                        note,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? AppTheme.primaryNavy : AppTheme.textDark,
                        ),
                      ),
                      backgroundColor: isSel ? AppTheme.statusGood.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isSel ? AppTheme.statusGood.withValues(alpha: 0.5) : AppTheme.borderSubtle,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () {
                        setModalState(() {
                          notesCtrl.text = note;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (sigBase64 != null && sigBase64!.isNotEmpty) ...[
                      Builder(builder: (context) {
                        final bytes = UiHelpers.safeDecodeBase64(sigBase64);
                        return Container(
                          width: 65,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.borderSubtle),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: bytes != null
                              ? Image.memory(bytes, fit: BoxFit.contain)
                              : const Icon(Icons.broken_image_outlined, size: 18, color: AppTheme.textMuted),
                        );
                      }),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.statusRejected),
                        tooltip: 'حذف التوقيع',
                        onPressed: () {
                          setModalState(() {
                            sigBase64 = '';
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(sigBase64 != null && sigBase64!.isNotEmpty ? Icons.edit : Icons.draw, size: 18),
                        label: Text(sigBase64 != null && sigBase64!.isNotEmpty ? 'تعديل التوقيع الرقمي' : 'إضافة توقيع رقمي الآن'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (c) => SignaturePadDialog(
                              role: roleCtrl.text,
                              signerName: nameCtrl.text,
                              existingSignatureBase64: sigBase64,
                              onCleared: () {
                                setModalState(() {
                                  sigBase64 = '';
                                });
                              },
                              onSaved: (b64) {
                                setModalState(() {
                                  sigBase64 = b64;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: Text(
                      existing == null ? 'إضافة إلى سجل الحضور' : 'حفظ التعديلات',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى إدخال اسم عضو الفريق')),
                        );
                        return;
                      }
                      final current = List<AttendanceRecord>.from(_report.attendanceList);
                      if (existing == null) {
                        final newRecord = AttendanceRecord(
                          serialNo: current.length + 1,
                          name: name,
                          role: roleCtrl.text.trim(),
                          affiliation: affCtrl.text.trim(),
                          signatureBase64: sigBase64,
                          notes: notesCtrl.text.trim(),
                        );
                        current.add(newRecord);
                      } else if (index != null && index >= 0 && index < current.length) {
                        current[index] = existing.copyWith(
                          name: name,
                          role: roleCtrl.text.trim(),
                          affiliation: affCtrl.text.trim(),
                          signatureBase64: sigBase64,
                          notes: notesCtrl.text.trim(),
                        );
                      }
                      _onReportUpdated(_report.copyWith(attendanceList: current));
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showDuplicateDialog() {
    final facilityCtrl = TextEditingController(
      text: _report.facilityInfo.facilityName.isNotEmpty
          ? _report.facilityInfo.facilityName
          : _report.title,
    );
    final now = DateTime.now();
    final dateCtrl = TextEditingController(
      text: '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}',
    );
    bool clearSignatures = true;
    bool clearPhotos = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.copy_rounded, color: AppTheme.brandCyan, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حفظ كتقرير جديد (استنساخ البيانات)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'سيتم حفظ نسخة جديدة ومستقلة برقم تسلسلي جديد لمتابعة التعديل عليها',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('اسم المنشأة / المرفق للتقرير الجديد:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: facilityCtrl,
                  decoration: const InputDecoration(
                    hintText: 'مثال: مركز صحي الرازي',
                    prefixIcon: Icon(Icons.business_outlined, size: 20),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('تاريخ الزيارة الجديد:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    hintText: 'YYYY/MM/DD',
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        dense: true,
                        title: const Text('تصفير التواقيع لبدء توقيع معتمد جديد', style: TextStyle(fontSize: 12)),
                        subtitle: const Text('يحتفظ بأسماء وصفات الموقعين ويزيل صور التواقيع القديمة', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                        value: clearSignatures,
                        onChanged: (val) => setModalState(() => clearSignatures = val ?? true),
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        dense: true,
                        title: const Text('تصفير صور الفحص السابقة', style: TextStyle(fontSize: 12)),
                        subtitle: const Text('لإتاحة التقاط صور فوتوغرافية جديدة للزيارة الحالية', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                        value: clearPhotos,
                        onChanged: (val) => setModalState(() => clearPhotos = val ?? true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 20),
                        label: const Text('إنشاء وفتح للتعديل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final modalNavigator = Navigator.of(ctx);

                          final newRep = await ref.read(reportsProvider.notifier).duplicateReport(
                            _report,
                            newFacilityName: facilityCtrl.text.trim(),
                            newVisitDate: dateCtrl.text.trim(),
                            clearSignatures: clearSignatures,
                            clearPhotos: clearPhotos,
                          );

                          modalNavigator.pop();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('تم إنشاء التقرير الجديد بنجاح (${newRep.reportNumber})'),
                              backgroundColor: AppTheme.statusGood,
                            ),
                          );
                          navigator.pushReplacement(
                            MaterialPageRoute(builder: (_) => ReportEditorScreen(reportId: newRep.id)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
