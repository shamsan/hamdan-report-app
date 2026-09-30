import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../models/report.dart';
import '../../state/branding_provider.dart';
import '../../state/reports_provider.dart';
import '../../services/pdf_export_service.dart';
import '../branding/branding_screen.dart';
import '../common/page_layout_settings_sheet.dart';
import 'widgets/report_readiness_dialog.dart';

class PdfPreviewScreen extends ConsumerStatefulWidget {
  final Report report;

  const PdfPreviewScreen({super.key, required this.report});

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  late Report _report;
  late Map<int, String> _pageOrientations;
  final Set<int> _selectedPages = {};
  int _previewVersion = 0;

  static const Map<int, String> _pageTitles = {
    1: 'بيانات المشروع والمرفق والمواصفات',
    2: 'الفحص الميداني 1 (الألواح والبطاريات)',
    3: 'الفحص الميداني 2 (لوحات القواطع ومفاتيح التبديل)',
    4: 'الفحص الميداني 3 (الهياكل والتأريض والتهوية)',
    5: 'الفحص الميداني 4 (التوصيلات والبيئة والسلامة)',
    6: 'مصفوفة خلايا البطاريات (م1 - م2)',
    7: 'مصفوفة خلايا البطاريات (م3 - م4)',
    8: 'بيانات التشغيل والجهد والأحمال وقراءات الإنفرترات',
    9: 'أداء المنظومة ونتائج الاختبارات والتوليد الشمسي',
    10: 'محضر إفادة الحضور والتواقيع والختم الرسمي',
    11: 'كشف حضور فريق العمل الميداني',
    12: 'ملحق التوثيق الفوتوغرافي للزيارة',
    13: 'جدول الاحتياجات والمواد للزيارة القادمة',
  };

  List<int> get _availablePages {
    final pages = <int>[1, 2, 3, 4, 5, 6];
    if (_report.activeBatteryGroups.length > 2) pages.add(7);
    pages.addAll([8, 9, 10, 11]);
    if (_report.photos.isNotEmpty) pages.add(12);
    if (_report.showNeedsInReport && _report.requestedNeeds.any((n) => n.includeInPdf)) pages.add(13);
    return pages;
  }

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _pageOrientations = Map<int, String>.from(widget.report.pageOrientations);
    _selectedPages.addAll(_availablePages);
  }

  void _saveOrientations() {
    setState(() {
      _previewVersion++;
      _report = _report.copyWith(pageOrientations: Map<int, String>.from(_pageOrientations));
    });
    ref.read(reportsProvider.notifier).updateReport(_report);
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider);
    final missingFields = _report.validateMissingFields();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_report);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_report),
          ),
          title: const Text('معاينة وتصدير التقرير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.greenAccent),
            tooltip: 'مشاركة التقرير مع نص رسمي',
            onPressed: () => _shareViaWhatsApp(context, branding),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'إعدادات مقاسات وتنسيق الصفحات (A4 / A3)',
            onPressed: () => _showPageSelectorSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tooltip: 'خيارات إضافية',
            onSelected: (val) {
              if (val == 'validate') _showValidationDialog(context, branding);
              if (val == 'branding') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BrandingScreen()),
                );
              }
              if (val == 'pages') _showPageSelectorSheet(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'validate',
                child: Row(
                  children: [
                    Icon(Icons.fact_check_outlined, size: 18, color: AppTheme.primaryNavy),
                    SizedBox(width: 8),
                    Text('فحص جاهزية التقرير للتصدير', style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'branding',
                child: Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 18, color: AppTheme.primaryNavy),
                    SizedBox(width: 8),
                    Text('تخصيص الشعارات والهوية', style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pages',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18, color: AppTheme.primaryNavy),
                    SizedBox(width: 8),
                    Text('إدارة وتنسيق الصفحات', style: TextStyle(fontSize: 12.5)),
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
          // Pre-export validation warning banner if missing fields exist
          if (missingFields.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF3E0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFED6C02), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه: يوجد ${missingFields.length} ملاحظات/حقول ناقصة في التقرير قبل التصدير النهائي.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    child: const Text('عرض التفاصيل'),
                    onPressed: () => _showValidationDialog(context, branding),
                  ),
                ],
              ),
            ),
          // Interactive PDF Preview Widget
          Expanded(
            child: PdfPreview(
              key: ValueKey('preview_${_report.id}_${_previewVersion}_${_selectedPages.length}'),
              build: (format) => PdfExportService.generateReportPdf(
                report: _report,
                branding: branding,
                pagesToExport: _selectedPages.length == _availablePages.length ? null : _selectedPages.toList(),
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              initialPageFormat: _pageOrientations.values.any((v) => v.toLowerCase().contains('a3')) ? PdfPageFormat.a3 : PdfPageFormat.a4,
              pdfFileName: '${_report.facilityInfo.facilityName}_تقرير_الصيانة.pdf',
              onShared: (context) {
                ref.read(reportsProvider.notifier).updateReport(
                  _report.copyWith(status: ReportStatus.exported),
                );
              },
              onPrinted: (context) {
                ref.read(reportsProvider.notifier).updateReport(
                  _report.copyWith(status: ReportStatus.exported),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _shareViaWhatsApp(context, branding),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'مشاركة وإرسال التقرير',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _directPrint(context, branding),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    side: const BorderSide(color: AppTheme.primaryNavy),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'طباعة مباشرة',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _directPrint(BuildContext context, dynamic branding) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => PdfExportService.generateReportPdf(
          report: _report,
          branding: branding,
          pagesToExport: _selectedPages.length == _availablePages.length ? null : _selectedPages.toList(),
        ),
        name: '${_report.facilityInfo.facilityName}_تقرير_الصيانة',
      );
      if (!context.mounted) return;
      ref.read(reportsProvider.notifier).updateReport(
        _report.copyWith(status: ReportStatus.exported),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال أمر الطباعة: $e')),
      );
    }
  }

  void _showValidationDialog(BuildContext context, dynamic branding) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReportReadinessDialog(
        report: _report,
        onExportNow: () {
          Navigator.pop(ctx);
          _shareViaWhatsApp(context, branding);
        },
        onEditReport: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _showPageSelectorSheet(BuildContext context) async {
    final result = await PageLayoutSettingsSheet.show(
      context,
      initialOrientations: _pageOrientations,
      initialSelectedPages: _selectedPages,
      allowPageSelection: true,
      customPageLabels: _pageTitles,
      activeCombinerBoxesCount: _report.activeCombinerBoxes.length,
    );
    if (result != null && mounted) {
      setState(() {
        _pageOrientations = Map<int, String>.from(result.pageOrientations);
        if (result.selectedPages != null) {
          _selectedPages.clear();
          _selectedPages.addAll(result.selectedPages!);
        }
        _report = _report.copyWith(pageOrientations: Map<int, String>.from(_pageOrientations));
        _previewVersion++;
      });
      _saveOrientations();
    }
  }

  Future<void> _shareViaWhatsApp(BuildContext context, dynamic branding) async {
    try {
      final pdfBytes = await PdfExportService.generateReportPdf(
        report: _report,
        branding: branding,
        pagesToExport: _selectedPages.length == _availablePages.length ? null : _selectedPages.toList(),
      );

      final facName = _report.facilityInfo.facilityName.isNotEmpty
          ? _report.facilityInfo.facilityName
          : 'المرفق';
      final fileName = '${facName}_تقرير_الصيانة_المعتمد.pdf';
      final shareText = 'مرفق لكم تقرير الصيانة الدورية المعتمد لمنظومة الطاقة الشمسية - $facName\n'
          'رقم العقد: ${_report.contractNumber.isNotEmpty ? _report.contractNumber : "غير محدد"}\n'
          'تاريخ الزيارة: ${_report.visitDate}\n'
          'المشروع: ${_report.projectInfo.projectName}';

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
        subject: 'تقرير الصيانة الدورية - $facName',
        body: shareText,
      );

      if (!context.mounted) return;
      ref.read(reportsProvider.notifier).updateReport(
        _report.copyWith(status: ReportStatus.exported),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز التقرير للمشاركة بنجاح')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تجهيز التقرير: $e')),
      );
    }
  }
}
