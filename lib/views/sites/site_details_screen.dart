import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
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
        ],
      ),
      body: Column(
        children: [
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.brandCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        client.nameAr,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
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
                const SizedBox(height: 14),

                // ─── CTA: One-Tap Start Visit ────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.solarGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.rocket_launch, size: 18),
                    label: Text(
                      '🚀 بدء زيارة صيانة جديدة للموقع (الزيارة رقم $nextVisitNum)',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _startNewVisitForSite(context, site, client, nextVisitNum),
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
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  text: 'الزيارات والتقارير (${siteReports.length})',
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
    );
  }

  // ─── Tab 1: Visits & Reports Log ─────────────────────────────────────────────
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_late_outlined, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text(
                'لم يتم تنفيذ أي زيارة صيانة لهذا الموقع بعد',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'اضغط على زر بدء زيارة صيانة جديدة بالأعلى لإنشاء أول تقرير فحص ميداني.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('بدء الزيارة الأولى الآن'),
                onPressed: () => _startNewVisitForSite(context, site, client, nextVisitNum),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: siteReports.length,
      itemBuilder: (context, index) {
        final report = siteReports[index];
        final visitNum = report.visitNumber.isNotEmpty ? report.visitNumber : '${siteReports.length - index}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Visit Badge, Status, Date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الزيارة رقم ($visitNum)',
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: report.status == ReportStatus.completed
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.status == ReportStatus.completed ? 'مكتمل ومعتمد' : 'مسودة قيد المراجعة',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: report.status == ReportStatus.completed ? Colors.green[700] : Colors.orange[800],
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_today, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      report.visitDate,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Report Title & Completion Progress
                Text(
                  report.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: report.completionRatio,
                          backgroundColor: Colors.grey[200],
                          color: report.completionRatio > 0.8 ? Colors.green : AppTheme.solarGold,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(report.completionRatio * 100).toInt()}% مكتمل',
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppTheme.borderSubtle),
                const SizedBox(height: 8),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryNavy,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.checklist_rtl, size: 16),
                      label: const Text('جلسة الفحص', style: TextStyle(fontSize: 11.5)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MaintenanceSessionScreen(reportId: report.id),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.brandCyan,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('محرر التقرير', style: TextStyle(fontSize: 11.5)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportEditorScreen(reportId: report.id),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.solarGold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 15),
                      label: const Text('معاينة PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
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
        );
      },
    );
  }

  // ─── Tab 2: Materials & Spare Parts History ──────────────────────────────────
  Widget _buildNeedsTab(BuildContext context, List<_NeedWithVisit> allNeeds) {
    if (allNeeds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMuted),
              SizedBox(height: 12),
              Text(
                'لا توجد مواد أو قطع غيار مسجلة لهذا الموقع بعد',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              SizedBox(height: 6),
              Text(
                'عندما يطلب المهندس قطع غيار أثناء الفحص الميداني، ستظهر هنا مجمعة ومصنفة بحسب الزيارات.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
            ],
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
                          Text(
                            need.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بدء الزيارة الميدانية'),
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
}

class _NeedWithVisit {
  final MaintenanceNeedItem need;
  final Report report;
  const _NeedWithVisit({required this.need, required this.report});
}
