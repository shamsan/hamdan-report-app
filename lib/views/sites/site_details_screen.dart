import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breadcrumb_widget.dart';
import '../../models/site.dart';
import '../../models/client.dart';
import '../../models/report.dart';
import '../../models/maintenance_need.dart';
import '../../state/reports_provider.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../session/maintenance_session_screen.dart';
import '../editor/report_editor_screen.dart';
import '../preview/pdf_preview_screen.dart';
import 'site_form_screen.dart';

class SiteDetailsScreen extends ConsumerStatefulWidget {
  final Site site;

  const SiteDetailsScreen({super.key, required this.site});

  @override
  ConsumerState<SiteDetailsScreen> createState() => _SiteDetailsScreenState();
}

class _SiteDetailsScreenState extends ConsumerState<SiteDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep live site state if updated
    final allSites = ref.watch(sitesProvider);
    final site = allSites.firstWhere(
      (s) => s.id == widget.site.id,
      orElse: () => widget.site,
    );

    final clients = ref.watch(clientsProvider);
    final client = clients.firstWhere(
      (c) => c.id == site.clientId,
      orElse: () => Client(
        id: site.clientId,
        nameAr: 'العميل المستفيد',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final allReports = ref.watch(reportsProvider);
    final siteReports = allReports
        .where((r) => r.siteId == site.id || r.facilityInfo.facilityName == site.nameAr)
        .toList();

    // Sort: newest visit first
    siteReports.sort((a, b) {
      final aNum = int.tryParse(a.visitNumber) ?? 0;
      final bNum = int.tryParse(b.visitNumber) ?? 0;
      if (aNum != bNum) return bNum.compareTo(aNum);
      return b.updatedAt.compareTo(a.updatedAt);
    });

    // Next visit calculation
    int nextVisitNum = 1;
    if (siteReports.isNotEmpty) {
      final nums = siteReports.map((r) => int.tryParse(r.visitNumber) ?? 1).toList();
      nums.sort();
      nextVisitNum = nums.last + 1;
    }

    // Aggregate all needs across visits for this site
    final allNeeds = <_NeedWithVisit>[];
    for (final rep in siteReports) {
      for (final need in rep.requestedNeeds) {
        allNeeds.add(_NeedWithVisit(need: need, report: rep));
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: AppBar(
        title: Text(
          site.nameAr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: 'تعديل بيانات الموقع',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SiteFormScreen(
                    clientId: site.clientId,
                    siteToEdit: site,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white70),
            tooltip: 'حذف الموقع',
            onPressed: () => _confirmDeleteSite(context, site, client),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Breadcrumb Navigation Bar ─────────────────────────────────
          BreadcrumbBar(
            items: [
              BreadcrumbItem(
                label: 'دليل العملاء',
                icon: Icons.business_center_rounded,
                onTap: () => Navigator.pop(context),
              ),
              BreadcrumbItem(
                label: client.displayName,
                onTap: () => Navigator.pop(context),
              ),
              BreadcrumbItem(label: site.displayName),
            ],
          ),

          // ─── Header Operations Hub ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.primaryNavy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client & Location Row
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.brandCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          client.nameAr,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.solarGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        site.category,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.solarGold),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.location_on, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      '${site.governorate} • ${site.directorate}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dedicated Funder & Specs Badge Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: AppTheme.solarGold, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              site.funderNameAr,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'عقد: ${site.contractNumber.isNotEmpty ? site.contractNumber : "غير محدد"} • القدرة: ${site.systemSpecs.capacityKw.isNotEmpty ? site.systemSpecs.capacityKw : "حسب الفحص"}',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Tab Bar ────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryNavy,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.solarGold,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  icon: const Icon(Icons.timeline_rounded, size: 18),
                  text: 'سجل الزيارات (${siteReports.length})',
                ),
                Tab(
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  text: 'سجل المواد (${allNeeds.length})',
                ),
                Tab(
                  icon: const Icon(Icons.solar_power_outlined, size: 18),
                  text: 'المواصفات الفنية',
                ),
              ],
            ),
          ),

          // ─── Tab Bar Views ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVisitsTab(context, site, client, siteReports, nextVisitNum),
                _buildNeedsTab(context, allNeeds),
                _buildSpecsTab(context, site),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppTheme.borderSubtle)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.solarGold,
              foregroundColor: AppTheme.textDark,
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.rocket_launch, size: 20),
            label: Text(
              '🚀 بدء زيارة صيانة جديدة للموقع (الزيارة رقم $nextVisitNum)',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _startNewVisitForSite(context, site, client, nextVisitNum);
            },
          ),
        ),
      ),
    );
  }

  // ─── Tab 1: Visits Timeline Log ─────────────────────────────────────────────
  Widget _buildVisitsTab(
    BuildContext context,
    Site site,
    Client client,
    List<Report> siteReports,
    int nextVisitNum,
  ) {
    if (siteReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: EmptyStateGuide(
            icon: Icons.timeline_rounded,
            title: 'لم يتم تنفيذ أي زيارة صيانة لهذا الموقع بعد',
            description: 'ابدأ أول زيارة صيانة ميدانية للموقع لاختبار مكونات المنظومة وإصدار تقرير الفحص.',
            actionLabel: 'بدء الزيارة الأولى الآن',
            onAction: () => _startNewVisitForSite(context, site, client, nextVisitNum),
          ),
        ),
      );
    }

    final completedCount = siteReports.where((r) => r.isCompleted).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        // ─── Timeline Overview Bar ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.history_toggle_off_rounded, color: AppTheme.primaryNavy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المخطط الزمني: إجمالي ${siteReports.length} زيارات ($completedCount معتمدة)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.brandCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'التالية #$nextVisitNum',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                ),
              ),
            ],
          ),
        ),

        // ─── Interactive Vertical Timeline Nodes ───
        ...List.generate(siteReports.length, (index) {
          final report = siteReports[index];
          final isFirst = index == 0;
          final isLast = index == siteReports.length - 1;
          final visitNum = report.visitNumber.isNotEmpty ? report.visitNumber : '${siteReports.length - index}';

          return _buildTimelineItem(
            context: context,
            report: report,
            visitNum: visitNum,
            isFirst: isFirst,
            isLast: isLast,
          );
        }),
      ],
    );
  }

  Widget _buildTimelineItem({
    required BuildContext context,
    required Report report,
    required String visitNum,
    required bool isFirst,
    required bool isLast,
  }) {
    final isCompleted = report.isCompleted;
    final nodeColor = isCompleted ? AppTheme.statusGood : AppTheme.solarGold;
    final needsCount = report.requestedNeeds.length;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Timeline Axis & Node Indicator ───
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Top Connector line
                Container(
                  width: 2.5,
                  height: 16,
                  color: isFirst ? Colors.transparent : AppTheme.borderSubtle,
                ),
                // Timeline Node Circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: nodeColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(Icons.check, size: 16, color: nodeColor)
                        : Text(
                            visitNum,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: nodeColor,
                            ),
                          ),
                  ),
                ),
                // Bottom Connector line
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: isLast ? Colors.transparent : AppTheme.borderSubtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ─── Timeline Card Content ───
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isFirst ? AppTheme.solarGold.withValues(alpha: 0.4) : AppTheme.borderSubtle,
                  width: isFirst ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Visit Badge, Status, Date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'الزيارة رقم ($visitNum)',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppTheme.statusGoodBg
                                : AppTheme.statusFollowupBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isCompleted ? 'معتمد' : 'مسودة قيد الإعداد',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? AppTheme.statusGood : AppTheme.statusFollowup,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.calendar_today, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          report.visitDate,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Report Title
                    Text(
                      report.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Progress bar & completion ratio
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: report.completionRatio,
                              backgroundColor: Colors.grey[200],
                              color: report.completionRatio > 0.8 ? AppTheme.statusGood : AppTheme.solarGold,
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(report.completionRatio * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Chips summary row: Inspection items and requested needs
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fact_check_outlined, size: 12, color: AppTheme.primaryNavy),
                              const SizedBox(width: 4),
                              Text(
                                '${report.inspectionGroups.fold(0, (sum, g) => sum + g.items.length)} بنود فحص',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textDark),
                              ),
                            ],
                          ),
                        ),
                        if (needsCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  '$needsCount قطع مطلوبة',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                ),
                              ],
                            ),
                          ),
                        if (report.photos.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppTheme.brandCyan.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_camera_back_outlined, size: 12, color: AppTheme.brandCyan),
                                const SizedBox(width: 4),
                                Text(
                                  '${report.photos.length} صور',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.brandCyan, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppTheme.borderSubtle),
                    const SizedBox(height: 6),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.checklist_rtl, size: 16),
                          label: const Text('جلسة الفحص', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MaintenanceSessionScreen(reportId: report.id),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.brandCyan,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('المحرر', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportEditorScreen(reportId: report.id),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.solarGold,
                            foregroundColor: AppTheme.textDark,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 15),
                          label: const Text('PDF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfPreviewScreen(report: report),
                              ),
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
        ],
      ),
    );
  }

  // ─── Tab 2: Materials & Spare Parts History ──────────────────────────────────
  Widget _buildNeedsTab(BuildContext context, List<_NeedWithVisit> allNeeds) {
    if (allNeeds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: EmptyStateGuide(
            icon: Icons.checklist_rounded,
            title: 'سجل المواد والاحتياجات سليم',
            description: 'لم يتم تسجيل أي قطع غيار مطلوبة أو صيانات تصحيحية معلقة في زيارات هذا الموقع حتى الآن.',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: allNeeds.length,
      itemBuilder: (context, index) {
        final item = allNeeds[index];
        final need = item.need;
        final report = item.report;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: need.priority.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(need.priority.icon, color: need.priority.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              need.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: need.priority.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              need.priority.labelAr,
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: need.priority.color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'الكمية: ${need.quantity} ${need.unit} • طُلبت في الزيارة (${report.visitNumber}) بتاريخ ${report.visitDate}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      if (need.reason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          need.reason,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textDark),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: need.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    need.status.labelAr,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: need.status.color),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Tab 3: Solar System Specs ───────────────────────────────────────────────
  Widget _buildSpecsTab(BuildContext context, Site site) {
    final s = site.systemSpecs;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSpecTile('نوع المنظومة المنفذة', s.systemType.isNotEmpty ? s.systemType : 'منظومة هجينة (Hybrid)'),
          _buildSpecTile('القدرة الكلية للتيار (kWp)', s.capacityKw.isNotEmpty ? s.capacityKw : 'غير محددة'),
          _buildSpecTile('الألواح الشمسية المنفذة', s.panelsCountAndWatt.isNotEmpty ? s.panelsCountAndWatt : 'غير محددة'),
          _buildSpecTile('الإنفرترات والمحولات', s.invertersCapacity.isNotEmpty ? s.invertersCapacity : 'غير محددة'),
          _buildSpecTile('بنك البطاريات والتخزين', s.batteryUnitsCapacity.isNotEmpty ? s.batteryUnitsCapacity : 'غير محدد'),
          _buildSpecTile('منظمات الشحن (Controllers)', s.chargeControllersCapacity.isNotEmpty ? s.chargeControllersCapacity : 'غير محدد'),
          _buildSpecTile('أجهزة الحماية ومكونات أخرى', s.otherAppliances.isNotEmpty ? s.otherAppliances : 'غير محدد'),
          _buildSpecTile('تاريخ التركيب والاستلام', site.installationDate.isNotEmpty ? site.installationDate : 'غير مسجل'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryNavy,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('تعديل المواصفات الفنية لمنظومة الموقع'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SiteFormScreen(
                      clientId: site.clientId,
                      siteToEdit: site,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.solarGold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startNewVisitForSite(
    BuildContext context,
    Site site,
    Client client,
    int nextVisitNum,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: AppTheme.solarGold),
            SizedBox(width: 8),
            Text('بدء زيارة صيانة ميدانية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'سيتم إنشاء جلسة فحص برقم الزيارة ($nextVisitNum) لموقع "${site.nameAr}" التابع لـ "${client.nameAr}" مع نسخ المواصفات الفنية والممول تلقائياً.',
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بدء الزيارة الميدانية', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final newReport = await ref.read(reportsProvider.notifier).createReportForSite(
      site: site,
      client: client,
      customVisitNumber: nextVisitNum.toString(),
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MaintenanceSessionScreen(reportId: newReport.id),
        ),
      );
    }
  }

  void _confirmDeleteSite(BuildContext context, Site site, Client client) {
    final reports = ref.read(reportsProvider);
    final siteReports = reports.where((r) => r.siteId == site.id).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.statusRejected, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'حذف الموقع: ${site.nameAr}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيؤدي حذف هذا الموقع إلى حذف كافة البيانات والتقارير المرتبطة به نهائياً:',
              style: TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusRejected.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.statusRejected.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• الجهة المالكة: ${client.displayName}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('• عدد التقارير والزيارات: ${siteReports.length} تقرير', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('• كافة القياسات والصور والتوقيعات التابعة للموقع', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'تحذير: لا يمكن التراجع عن هذه العملية بعد التأكيد.',
              style: TextStyle(fontSize: 12, color: AppTheme.statusRejected, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await deleteSiteCascade(ref, site.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حذف الموقع "${site.nameAr}" وكافة تقاريره بنجاح'),
                    backgroundColor: AppTheme.primaryNavy,
                  ),
                );
              }
            },
            child: const Text('حذف نهائي شامل', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _NeedWithVisit {
  final MaintenanceNeedItem need;
  final Report report;
  const _NeedWithVisit({required this.need, required this.report});
}
