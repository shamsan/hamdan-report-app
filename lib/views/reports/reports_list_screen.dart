import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/breadcrumb_widget.dart';
import '../../state/reports_provider.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../models/report.dart';
import '../editor/report_editor_screen.dart';
import '../preview/pdf_preview_screen.dart';
import '../session/maintenance_session_screen.dart';
import '../session/dialogs/create_session_dialog.dart';

class ReportsListScreen extends ConsumerStatefulWidget {
  const ReportsListScreen({super.key});

  @override
  ConsumerState<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends ConsumerState<ReportsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  ReportStatus? _filterStatus;
  ReportSortOrder _sortOrder = ReportSortOrder.updatedAtDesc;
  String? _filterClientId;
  String? _filterSiteId;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(reportsProvider);

    var filtered = ref.watch(reportsProvider.notifier).getFiltered(
      query: _searchController.text.trim(),
      status: _filterStatus,
      sortOrder: _sortOrder,
    );

    if (_filterClientId != null && _filterClientId!.isNotEmpty) {
      filtered = filtered.where((r) => r.clientId == _filterClientId).toList();
    }
    if (_filterSiteId != null && _filterSiteId!.isNotEmpty) {
      filtered = filtered.where((r) => r.siteId == _filterSiteId).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة تقارير الصيانة'),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: AdaptiveContentContainer(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'البحث باسم المنشأة، رقم التقرير، أو رقم العقد...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      isDense: true,
                    ),
                    onChanged: (_) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                        setState(() {});
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل (${reports.length})', _filterStatus == null, () {
                          setState(() => _filterStatus = null);
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'قيد التحرير (${reports.where((r) => r.status == ReportStatus.draft).length})',
                          _filterStatus == ReportStatus.draft,
                          () => setState(() => _filterStatus = ReportStatus.draft),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'المكتملة (${reports.where((r) => r.status == ReportStatus.completed).length})',
                          _filterStatus == ReportStatus.completed,
                          () => setState(() => _filterStatus = ReportStatus.completed),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 24,
                          width: 1,
                          color: AppTheme.borderSubtle,
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<ReportSortOrder>(
                          tooltip: 'ترتيب التقارير',
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort_rounded, size: 18, color: AppTheme.primaryNavy),
                              const SizedBox(width: 4),
                              Text(
                                switch (_sortOrder) {
                                  ReportSortOrder.updatedAtDesc => 'الأحدث',
                                  ReportSortOrder.updatedAtAsc  => 'الأقدم',
                                  ReportSortOrder.nameAsc       => 'أبجدياً',
                                  ReportSortOrder.nameDesc      => 'عكسياً',
                                },
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                              ),
                            ],
                          ),
                          onSelected: (order) => setState(() => _sortOrder = order),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: ReportSortOrder.updatedAtDesc,
                              child: Text('الأحدث تعديلاً أولاً'),
                            ),
                            const PopupMenuItem(
                              value: ReportSortOrder.updatedAtAsc,
                              child: Text('الأقدم تعديلاً أولاً'),
                            ),
                            const PopupMenuItem(
                              value: ReportSortOrder.nameAsc,
                              child: Text('أبجدياً بالاسم (أ - ي)'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Client & Site cascading dropdown row
                  Consumer(
                    builder: (context, ref, _) {
                      final clients = ref.watch(clientsProvider);
                      final sites = ref.watch(sitesProvider);
                      if (clients.isEmpty) return const SizedBox.shrink();

                      final availableSites = _filterClientId != null
                          ? sites.where((s) => s.clientId == _filterClientId).toList()
                          : sites;

                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            // Client filter dropdown
                            Expanded(
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: _filterClientId,
                                    isExpanded: true,
                                    hint: const Text('فلترة بالعميل: الكل', style: TextStyle(fontSize: 11.5)),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('كافة العملاء', style: TextStyle(fontSize: 11.5)),
                                      ),
                                      ...clients.map((c) => DropdownMenuItem<String?>(
                                        value: c.id,
                                        child: Text(c.displayName, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                                      )),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _filterClientId = val;
                                        _filterSiteId = null; // reset site when client changes
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Site filter dropdown
                            Expanded(
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: _filterSiteId,
                                    isExpanded: true,
                                    hint: const Text('فلترة بالموقع: الكل', style: TextStyle(fontSize: 11.5)),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('كافة المواقع', style: TextStyle(fontSize: 11.5)),
                                      ),
                                      ...availableSites.map((s) => DropdownMenuItem<String?>(
                                        value: s.id,
                                        child: Text(s.displayName, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                                      )),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _filterSiteId = val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            if (_filterClientId != null || _filterSiteId != null) ...[
                              IconButton(
                                tooltip: 'إلغاء الفلاتر',
                                icon: const Icon(Icons.filter_alt_off_rounded, size: 18, color: AppTheme.statusRejected),
                                onPressed: () {
                                  setState(() {
                                    _filterClientId = null;
                                    _filterSiteId = null;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Reports List or Grid
          Expanded(
            child: reports.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: EmptyStateGuide(
                        icon: Icons.assignment_outlined,
                        title: 'لا توجد تقارير صيانة مسجلة بعد',
                        description: 'ابدأ جلستك الأولى باختيار العميل والموقع لإنشاء تقرير فحص ميداني متكامل',
                        actionLabel: 'بدء جلسة صيانة جديدة',
                        onAction: () => _showNewReportModal(context),
                      ),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_outlined, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text(
                              'لم يتم العثور على تقارير مطابقة للفلاتر الحالية',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'جرّب إعادة تعيين فلاتر البحث أو العميل/الموقع.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _filterStatus = null;
                                  _filterClientId = null;
                                  _filterSiteId = null;
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('إعادة ضبط كافة الفلاتر'),
                            ),
                          ],
                        ),
                      )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 750;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: AdaptiveContentContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: isWide
                              ? GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    mainAxisExtent: 180,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    return _buildReportItem(context, filtered[index]);
                                  },
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    return _buildReportItem(context, filtered[index]);
                                  },
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewReportModal(context),
        backgroundColor: AppTheme.solarGold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'تقرير جديد',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.12),
      checkmarkColor: AppTheme.primaryNavy,
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AppTheme.primaryNavy : AppTheme.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryNavy : AppTheme.borderSubtle,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildReportItem(BuildContext context, Report report) {
    final progress = report.completionRatio;
    final isCompleted = report.status == ReportStatus.completed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReportEditorScreen(reportId: report.id)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client > Site > Visit Breadcrumb Pill
                Consumer(
                  builder: (context, ref, _) {
                    final client = ref.watch(clientByIdProvider(report.clientId));
                    final site = ref.watch(siteByIdProvider(report.siteId));
                    final clientName = client?.displayName ?? 'عميل غير محدد';
                    final siteName = site?.displayName ?? (report.facilityInfo.facilityName.isNotEmpty ? report.facilityInfo.facilityName : 'موقع غير محدد');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_rounded, size: 12, color: AppTheme.primaryNavy),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              clientName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.chevron_left_rounded, size: 12, color: AppTheme.textMuted),
                          ),
                          const Icon(Icons.location_on_rounded, size: 12, color: AppTheme.solarGold),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              siteName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.brandCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'زيارة #${report.visitNumber}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppTheme.statusGoodBg : AppTheme.statusFollowupBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCompleted
                              ? AppTheme.statusGood.withValues(alpha: 0.3)
                              : AppTheme.statusFollowup.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        color: isCompleted ? AppTheme.statusGood : AppTheme.statusFollowup,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.facilityInfo.facilityName.isNotEmpty
                                ? report.facilityInfo.facilityName
                                : report.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'عقد: ${report.contractNumber} • الزيارة: ${report.facilityInfo.visitDate}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        if (val == 'session') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MaintenanceSessionScreen(reportId: report.id)),
                          );
                        } else if (val == 'duplicate') {
                          _showDuplicateReportDialog(context, report);
                        } else if (val == 'preview') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PdfPreviewScreen(report: report)),
                          );
                        } else if (val == 'delete') {
                          _confirmDelete(context, report);
                        }
                      },
                      itemBuilder: (_) => [
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
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf, size: 18, color: AppTheme.primaryNavy),
                              SizedBox(width: 8),
                              Text('معاينة وتصدير PDF', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف التقرير', style: TextStyle(fontSize: 12.5, color: Colors.red, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الإنجاز: ${(progress * 100).toInt()}% (${isCompleted ? "مكتمل" : "مسودة"})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isCompleted ? AppTheme.statusGood : const Color(0xFFD97706),
                      ),
                    ),
                    Text(
                      report.systemSpecs.capacityKw.isNotEmpty ? report.systemSpecs.capacityKw : '57.6 kW',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? AppTheme.statusGood : AppTheme.brandCyan,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'الفئة: ${report.facilityInfo.category.isNotEmpty ? report.facilityInfo.category : "CAT 8"}',
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.flash_on_rounded, size: 15, color: AppTheme.solarGold),
                      label: const Text('الفحص', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MaintenanceSessionScreen(reportId: report.id)),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                      label: const Text('PDF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PdfPreviewScreen(report: report)),
                        );
                      },
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

  void _showNewReportModal(BuildContext context) {
    CreateSessionDialog.show(context);
  }

  void _confirmDelete(BuildContext context, Report report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('تأكيد حذف التقرير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text('هل أنت متأكد من حذف التقرير الخاص بـ "${report.facilityInfo.facilityName.isNotEmpty ? report.facilityInfo.facilityName : report.title}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRejected, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(reportsProvider.notifier).deleteReport(report.id);
              UiHelpers.showDeleteUndoSnackBar(
                context,
                report.facilityInfo.facilityName.isNotEmpty ? report.facilityInfo.facilityName : report.title,
                () {
                  ref.read(reportsProvider.notifier).addReport(report);
                },
              );
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateReportDialog(BuildContext context, Report source) {
    final facilityCtrl = TextEditingController(
      text: source.facilityInfo.facilityName.isNotEmpty
          ? source.facilityInfo.facilityName
          : source.title,
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
                            'نسخ وتعديل كتقرير جديد',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'سيتم نسخ بيانات المشروع والمنظومة وجداول الفحص لتقرير جديد مستقل',
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
                            source,
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
                          navigator.push(
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
