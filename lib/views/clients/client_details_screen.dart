import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breadcrumb_widget.dart';
import '../../models/client.dart';
import '../../models/site.dart';
import '../../models/report.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../state/reports_provider.dart';
import '../sites/site_details_screen.dart';
import '../sites/site_form_screen.dart';
import '../editor/report_editor_screen.dart';
import '../session/maintenance_session_screen.dart';
import '../session/dialogs/create_session_dialog.dart';

class ClientDetailsScreen extends ConsumerWidget {
  final Client client;

  const ClientDetailsScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep live client state if edited
    final allClients = ref.watch(clientsProvider);
    final currentClient = allClients.firstWhere(
      (c) => c.id == client.id,
      orElse: () => client,
    );

    final sites = ref.watch(sitesForClientProvider(currentClient.id));
    final clientReports = ref.watch(reportsForClientProvider(currentClient.id));
    final stats = ref.watch(clientStatsProvider(currentClient.id));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.bgSurface,
        appBar: AppBar(
          title: Text(
            currentClient.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppTheme.primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
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
                BreadcrumbItem(label: currentClient.displayName),
              ],
            ),

            // ─── Client Profile Banner ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryNavy,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client Avatar or Logo
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: currentClient.logoBase64 != null && currentClient.logoBase64!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  base64Decode(currentClient.logoBase64!),
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const Icon(Icons.apartment, color: AppTheme.primaryNavy, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentClient.nameAr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (currentClient.nameEn.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                currentClient.nameEn,
                                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.brandCyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentClient.clientType,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.brandCyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (currentClient.contactPerson.isNotEmpty || currentClient.phone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: AppTheme.solarGold, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              currentClient.contactPerson,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (currentClient.phone.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.phone, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              currentClient.phone,
                              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  // Quick Summary Stats Bar
                  Row(
                    children: [
                      _buildQuickStat('المواقع', '${stats.sitesCount}', Icons.pin_drop, AppTheme.solarGold),
                      const SizedBox(width: 8),
                      _buildQuickStat('الزيارات', '${stats.reportsCount}', Icons.assignment, Colors.greenAccent),
                      const SizedBox(width: 8),
                      _buildQuickStat('المسودات', '${stats.draftReports}', Icons.edit_document, AppTheme.brandCyan),
                    ],
                  ),
                ],
              ),
            ),

            // ─── TabBar ─────────────────────────────────────────────────────────
            Container(
              color: Colors.white,
              child: TabBar(
                indicatorColor: AppTheme.solarGold,
                indicatorWeight: 3,
                labelColor: AppTheme.primaryNavy,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.pin_drop_outlined, size: 18),
                    text: 'المواقع والمنشآت (${sites.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.history_rounded, size: 18),
                    text: 'سجل الزيارات والتقارير (${clientReports.length})',
                  ),
                ],
              ),
            ),

            // ─── TabBarView ─────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Sites List
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'كافة المنشآت التابعة (${sites.length})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.solarGold,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.add_location_alt, size: 16),
                              label: const Text('إضافة موقع جديد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SiteFormScreen(clientId: currentClient.id),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: sites.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: EmptyStateGuide(
                                    icon: Icons.add_location_alt_rounded,
                                    title: 'لا توجد مواقع مسجلة لهذا العميل بعد',
                                    description: 'أضف أول موقع أو منشأة لهذا العميل لتبدأ تسجيل زيارات الصيانة الدورية وتتبع المواصفات الفنية.',
                                    actionLabel: 'إضافة موقع جديد الآن',
                                    onAction: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SiteFormScreen(clientId: currentClient.id),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(14),
                                itemCount: sites.length,
                                itemBuilder: (context, index) {
                                  final site = sites[index];
                                  final siteReports = clientReports.where((r) => r.siteId == site.id).toList();
                                  return _buildSiteCard(context, ref, site, currentClient, siteReports);
                                },
                              ),
                      ),
                    ],
                  ),

                  // Tab 2: Client Reports History
                  clientReports.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: EmptyStateGuide(
                              icon: Icons.history_edu_rounded,
                              title: 'لم تُنفذ أي زيارات صيانة لهذا العميل بعد',
                              description: 'ابدأ أول زيارة صيانة لأي من مواقع هذا العميل من تبويب "المواقع والمنشآت".',
                              actionLabel: sites.isNotEmpty ? 'بدء زيارة صيانة' : 'إضافة موقع أولاً',
                              onAction: () {
                                if (sites.isNotEmpty) {
                                  CreateSessionDialog.show(
                                    context,
                                    initialClient: currentClient,
                                    initialSite: sites.first,
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SiteFormScreen(clientId: currentClient.id),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: clientReports.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final report = clientReports[index];
                            final site = sites.firstWhere(
                              (s) => s.id == report.siteId,
                              orElse: () => Site(
                                id: report.siteId,
                                clientId: currentClient.id,
                                nameAr: report.facilityInfo.facilityName,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              ),
                            );

                            final isCompleted = report.isCompleted;
                            final progress = report.completionRatio;

                            return Card(
                              margin: EdgeInsets.zero,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppTheme.borderSubtle),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ReportEditorScreen(reportId: report.id)),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.solarGold),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    site.displayName,
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isCompleted ? AppTheme.statusGoodBg : AppTheme.statusFollowupBg,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isCompleted ? 'مكتمل' : 'مسودة',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isCompleted ? AppTheme.statusGood : AppTheme.statusFollowup,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.brandCyan.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'زيارة #${report.visitNumber}',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'تاريخ الزيارة: ${report.visitDate} • عقد: ${report.contractNumber}',
                                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 5,
                                                backgroundColor: AppTheme.borderSubtle,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  progress < 0.5
                                                      ? AppTheme.statusRejected
                                                      : (progress < 0.8 ? AppTheme.statusFollowup : AppTheme.statusGood),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${(progress * 100).round()}%',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(height: 1, color: AppTheme.borderSubtle),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            icon: const Icon(Icons.assignment, size: 14),
                                            label: const Text('المحرر', style: TextStyle(fontSize: 11)),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => ReportEditorScreen(reportId: report.id)),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryNavy,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            icon: const Icon(Icons.fact_check_rounded, size: 14),
                                            label: const Text('جلسة الفحص', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => MaintenanceSessionScreen(reportId: report.id)),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteCard(
    BuildContext context,
    WidgetRef ref,
    Site site,
    Client client,
    List<Report> siteReports,
  ) {
    final nextVisitNum = siteReports.isNotEmpty
        ? (siteReports.map((r) => int.tryParse(r.visitNumber) ?? 1).reduce((a, b) => a > b ? a : b) + 1)
        : 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SiteDetailsScreen(site: site),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Site Row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.solarGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.solar_power, color: AppTheme.solarGold, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.nameAr,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        if (site.nameEn.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            site.nameEn,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          '${site.governorate} • ${site.directorate}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      site.category,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Dedicated Funder & Specs Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 16, color: AppTheme.brandCyan),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'الممول: ${site.funderNameAr}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (site.systemSpecs.capacityKw.isNotEmpty) ...[
                          Text(
                            site.systemSpecs.capacityKw,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.solarGold),
                          ),
                        ],
                      ],
                    ),
                    if (site.systemSpecs.panelsCountAndWatt.isNotEmpty || site.systemSpecs.invertersCapacity.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (site.systemSpecs.panelsCountAndWatt.isNotEmpty) ...[
                            const Icon(Icons.solar_power_outlined, size: 13, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                site.systemSpecs.panelsCountAndWatt,
                                style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (site.systemSpecs.invertersCapacity.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.bolt, size: 13, color: AppTheme.solarGold),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                site.systemSpecs.invertersCapacity,
                                style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: AppTheme.borderSubtle),
              const SizedBox(height: 8),

              // Bottom Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'الزيارات المنفذة: ${siteReports.length}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.rocket_launch, size: 14),
                        label: Text(
                          'بدء زيارة ($nextVisitNum)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
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
                        },
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SiteDetailsScreen(site: site),
                            ),
                          );
                        },
                        child: const Text('ملف الموقع', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
