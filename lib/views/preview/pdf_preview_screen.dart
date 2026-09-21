import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../models/report.dart';
import '../../state/branding_provider.dart';
import '../../state/reports_provider.dart';
import '../../services/pdf_export_service.dart';
import '../branding/branding_screen.dart';
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
    8: 'بيانات التشغيل وملاحظات المنظومة',
    9: 'نموذج قياسات أداء الألواح (64 سترينج)',
    10: 'محضر إفادة الحضور والتواقيع والاعتماد',
    11: 'كشف حضور فريق العمل الميداني',
    12: 'ملحق التوثيق الفوتوغرافي للزيارة',
    13: 'جدول الاحتياجات والمواد للزيارة القادمة',
  };

  static const Map<int, IconData> _pageIcons = {
    1: Icons.description_outlined,
    2: Icons.checklist_rtl_rounded,
    3: Icons.electrical_services_rounded,
    4: Icons.security_rounded,
    5: Icons.health_and_safety_rounded,
    6: Icons.battery_charging_full_rounded,
    7: Icons.battery_charging_full_rounded,
    8: Icons.analytics_outlined,
    9: Icons.solar_power_rounded,
    10: Icons.verified_user_rounded,
    11: Icons.people_alt_rounded,
    12: Icons.photo_library_rounded,
    13: Icons.inventory_2_rounded,
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
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'تخصيص الشعارات والهوية',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BrandingScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'فحص جاهزية التقرير للتصدير',
            onPressed: () => _showValidationDialog(context, branding),
          ),
          IconButton(
            icon: const Icon(Icons.view_quilt_rounded),
            tooltip: 'إدارة تخطيط وصفحات التقرير (عمودي / أفقي)',
            onPressed: () => _showPageSelectorDialog(context),
          ),
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
              initialPageFormat: PdfPageFormat.a4,
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
    ),
  );
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

  void _showPageSelectorDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allSelected = _availablePages.every((p) => _selectedPages.contains(p));
          final totalCount = _availablePages.length;
          final selectedCount = _selectedPages.length;

          // Helpers for size and orientation
          String getPageSize(int pageNum) {
            final val = (_pageOrientations[pageNum] ?? (pageNum == 9 ? 'a4_landscape' : 'a4_portrait')).toLowerCase();
            return val.contains('a3') ? 'a3' : 'a4';
          }

          String getPageOrientation(int pageNum) {
            final val = (_pageOrientations[pageNum] ?? (pageNum == 9 ? 'a4_landscape' : 'a4_portrait')).toLowerCase();
            return (val.contains('landscape') || val.contains('horizontal')) ? 'landscape' : 'portrait';
          }

          final a4Count = _availablePages.where((p) => getPageSize(p) == 'a4').length;
          final a3Count = _availablePages.where((p) => getPageSize(p) == 'a3').length;
          final portraitCount = _availablePages.where((p) => getPageOrientation(p) == 'portrait').length;
          final landscapeCount = _availablePages.where((p) => getPageOrientation(p) == 'landscape').length;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 540,
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Modern Gradient Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0B3A60), Color(0xFF1565C0)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.view_quilt_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'إدارة وتخطيط صفحات التقرير',
                                style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'تخصيص مقاس الورق (A4 / A3) والاتجاه (عمودي / أفقي) لكل صفحة',
                                style: TextStyle(color: Colors.white70, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // 2. Stats Summary Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: const Color(0xFFF1F5F9),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatChip(Icons.insert_drive_file_outlined, '$totalCount صفحة', Colors.blueGrey),
                          const SizedBox(width: 6),
                          _buildStatChip(Icons.check_circle_outline, '$selectedCount محددة', Colors.green.shade700),
                          const SizedBox(width: 6),
                          _buildStatChip(Icons.description, '$a4Count A4', const Color(0xFF00897B)),
                          const SizedBox(width: 6),
                          _buildStatChip(Icons.photo_size_select_actual, '$a3Count A3', const Color(0xFF6A1B9A)),
                          const SizedBox(width: 6),
                          _buildStatChip(Icons.stay_current_portrait, '$portraitCount عمودي', Colors.teal.shade700),
                          const SizedBox(width: 6),
                          _buildStatChip(Icons.stay_current_landscape, '$landscapeCount أفقي', Colors.indigo.shade700),
                        ],
                      ),
                    ),
                  ),

                  // 3. Quick Global Controls Bar (2 Rows x 2 Columns)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تطبيق سريع على كافة الصفحات بنقرة واحدة:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B3A60)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionButton(
                                icon: Icons.auto_awesome,
                                label: 'الوضع الذكي (موصى به)',
                                color: const Color(0xFF1565C0),
                                isSelected: _availablePages.every((p) =>
                                    (_pageOrientations[p] ?? (p == 9 ? 'a3_landscape' : 'a4_portrait')) ==
                                    ((p == 9) ? 'a3_landscape' : 'a4_portrait')),
                                onTap: () {
                                  setDialogState(() {
                                    for (final p in _availablePages) {
                                      _pageOrientations[p] = (p == 9) ? 'a3_landscape' : 'a4_portrait';
                                    }
                                  });
                                  _saveOrientations();
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildQuickActionButton(
                                icon: Icons.stay_current_portrait,
                                label: 'الكل A4 عمودي',
                                color: const Color(0xFF00897B),
                                isSelected: _availablePages.every((p) =>
                                    getPageSize(p) == 'a4' && getPageOrientation(p) == 'portrait'),
                                onTap: () {
                                  setDialogState(() {
                                    for (final p in _availablePages) {
                                      _pageOrientations[p] = 'a4_portrait';
                                    }
                                  });
                                  _saveOrientations();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionButton(
                                icon: Icons.stay_current_landscape,
                                label: 'الكل A4 أفقي',
                                color: const Color(0xFF1E88E5),
                                isSelected: _availablePages.every((p) =>
                                    getPageSize(p) == 'a4' && getPageOrientation(p) == 'landscape'),
                                onTap: () {
                                  setDialogState(() {
                                    for (final p in _availablePages) {
                                      _pageOrientations[p] = 'a4_landscape';
                                    }
                                  });
                                  _saveOrientations();
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildQuickActionButton(
                                icon: Icons.photo_size_select_actual_outlined,
                                label: 'الكل A3 أفقي (عريض)',
                                color: const Color(0xFF6A1B9A),
                                isSelected: _availablePages.every((p) =>
                                    getPageSize(p) == 'a3' && getPageOrientation(p) == 'landscape'),
                                onTap: () {
                                  setDialogState(() {
                                    for (final p in _availablePages) {
                                      _pageOrientations[p] = 'a3_landscape';
                                    }
                                  });
                                  _saveOrientations();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // 4. Scrollable List of Page Cards with A4/A3 & Orientation Pickers
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      itemCount: _availablePages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final pageNum = _availablePages[idx];
                        final isSelected = _selectedPages.contains(pageNum);
                        final currentSize = getPageSize(pageNum);
                        final currentOri = getPageOrientation(pageNum);
                        final isA4 = currentSize == 'a4';
                        final isPortrait = currentOri == 'portrait';
                        final pageTitle = _pageTitles[pageNum] ?? 'الصفحة $pageNum';
                        final iconData = _pageIcons[pageNum] ?? Icons.insert_drive_file_outlined;

                        // Badge color based on combined configuration
                        Color badgeBg;
                        Color badgeFg;
                        String badgeText;
                        if (isA4 && isPortrait) {
                          badgeBg = const Color(0xFFE6FFFA);
                          badgeFg = const Color(0xFF0D9488);
                          badgeText = 'A4 عمودي';
                        } else if (isA4 && !isPortrait) {
                          badgeBg = const Color(0xFFEFF6FF);
                          badgeFg = const Color(0xFF1D4ED8);
                          badgeText = 'A4 أفقي';
                        } else if (!isA4 && !isPortrait) {
                          badgeBg = const Color(0xFFFAF5FF);
                          badgeFg = const Color(0xFF7E22CE);
                          badgeText = 'A3 أفقي';
                        } else {
                          badgeBg = const Color(0xFFFFFBEB);
                          badgeFg = const Color(0xFFB45309);
                          badgeText = 'A3 عمودي';
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.4 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Row: Checkbox, Page Number, Title, and Badge
                              InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    if (isSelected && _selectedPages.length > 1) {
                                      _selectedPages.remove(pageNum);
                                    } else {
                                      _selectedPages.add(pageNum);
                                    }
                                  });
                                  setState(() {
                                    _previewVersion++;
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      visualDensity: VisualDensity.compact,
                                      activeColor: const Color(0xFF1565C0),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            _selectedPages.add(pageNum);
                                          } else if (_selectedPages.length > 1) {
                                            _selectedPages.remove(pageNum);
                                          }
                                        });
                                        setState(() {
                                          _previewVersion++;
                                        });
                                      },
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0B3A60).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(iconData, size: 14, color: const Color(0xFF0B3A60)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'ص $pageNum',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0B3A60)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        pageTitle,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                          color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: badgeFg.withValues(alpha: 0.3), width: 0.8),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Controls Row 1: مقاس الورق (A4 vs A3)
                              Row(
                                children: [
                                  // A4 Button
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            _pageOrientations[pageNum] = 'a4_$currentOri';
                                          });
                                          _saveOrientations();
                                        },
                                        borderRadius: BorderRadius.circular(7),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isA4 ? const Color(0xFF00897B) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(7),
                                            border: Border.all(
                                              color: isA4 ? const Color(0xFF00695C) : const Color(0xFFCBD5E1),
                                              width: isA4 ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.description_outlined,
                                                size: 14,
                                                color: isA4 ? Colors.white : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'مقاس A4 (قياسي)',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: isA4 ? FontWeight.bold : FontWeight.w600,
                                                  color: isA4 ? Colors.white : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // A3 Button
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            _pageOrientations[pageNum] = 'a3_$currentOri';
                                          });
                                          _saveOrientations();
                                        },
                                        borderRadius: BorderRadius.circular(7),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: !isA4 ? const Color(0xFF6A1B9A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(7),
                                            border: Border.all(
                                              color: !isA4 ? const Color(0xFF4A148C) : const Color(0xFFCBD5E1),
                                              width: !isA4 ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.photo_size_select_actual_outlined,
                                                size: 14,
                                                color: !isA4 ? Colors.white : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'مقاس A3 (عريض)',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: !isA4 ? FontWeight.bold : FontWeight.w600,
                                                  color: !isA4 ? Colors.white : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Controls Row 2: اتجاه الورق (عمودي vs أفقي)
                              Row(
                                children: [
                                  // Portrait Button
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            _pageOrientations[pageNum] = '${currentSize}_portrait';
                                          });
                                          _saveOrientations();
                                        },
                                        borderRadius: BorderRadius.circular(7),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isPortrait ? const Color(0xFF0B3A60) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(7),
                                            border: Border.all(
                                              color: isPortrait ? const Color(0xFF082740) : const Color(0xFFCBD5E1),
                                              width: isPortrait ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.stay_current_portrait,
                                                size: 14,
                                                color: isPortrait ? Colors.white : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'عمودي (Portrait)',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: isPortrait ? FontWeight.bold : FontWeight.w600,
                                                  color: isPortrait ? Colors.white : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Landscape Button
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            _pageOrientations[pageNum] = '${currentSize}_landscape';
                                          });
                                          _saveOrientations();
                                        },
                                        borderRadius: BorderRadius.circular(7),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: !isPortrait ? const Color(0xFF1565C0) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(7),
                                            border: Border.all(
                                              color: !isPortrait ? const Color(0xFF0D47A1) : const Color(0xFFCBD5E1),
                                              width: !isPortrait ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.stay_current_landscape,
                                                size: 14,
                                                color: !isPortrait ? Colors.white : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'أفقي (Landscape)',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: !isPortrait ? FontWeight.bold : FontWeight.w600,
                                                  color: !isPortrait ? Colors.white : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // 5. Footer Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 16),
                          label: Text(allSelected ? 'تحديد صفحة واحدة' : 'تحديد الكل'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0B3A60),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              if (allSelected) {
                                _selectedPages.clear();
                                _selectedPages.add(1);
                              } else {
                                _selectedPages.addAll(_availablePages);
                              }
                            });
                            setState(() {
                              _previewVersion++;
                            });
                          },
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('حفظ واعتماد التخطيط'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B3A60),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                          ),
                          onPressed: () {
                            _saveOrientations();
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: isSelected ? Colors.white : color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
