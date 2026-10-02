import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../services/default_templates.dart';
import '../../state/reports_provider.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../state/branding_provider.dart';
import '../../models/report.dart';
import '../../models/organization.dart';
import '../editor/report_editor_screen.dart';
import '../session/dialogs/create_session_dialog.dart';
import '../session/maintenance_session_screen.dart';
import '../reports/reports_list_screen.dart';
import '../editor/widgets/stats_summary_card.dart';
import '../onboarding/onboarding_screen.dart';
import '../licensing/license_status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);
    final drafts = ref.watch(draftReportsProvider);
    final clients = ref.watch(clientsProvider);
    final sites = ref.watch(sitesProvider);
    final branding = ref.watch(brandingProvider);
    final sitesByGov = ref.watch(sitesGroupedByGovernorateProvider);

    if (clients.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(branding),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _EmptyDashboardExperience(onNavigateTab: onNavigateTab),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(branding),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(reportsProvider.notifier).load();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: AdaptiveContentContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderGreeting(context, reports, drafts),
                const SizedBox(height: 16),
                _buildActionHub(context),
                const SizedBox(height: 22),
                _buildStatsSummary(context, clients.length, sites.length, reports, ref),
                const SizedBox(height: 22),
                if (drafts.isNotEmpty) ...[
                  _buildPendingDrafts(context, drafts, ref),
                  const SizedBox(height: 22),
                ],
                if (reports.isNotEmpty) ...[
                  _buildRecentReports(context, reports, ref),
                  const SizedBox(height: 22),
                ],
                _buildSitesByGovernorate(context, sitesByGov),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(OrganizationProfile branding) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.solar_power_rounded, color: AppTheme.solarGold, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  branding.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  branding.subTitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const LicenseStatusBadge(),
        IconButton(
          icon: const Icon(Icons.palette_outlined),
          tooltip: 'الهوية البصرية',
          onPressed: () => onNavigateTab?.call(3),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'الإعدادات',
          onPressed: () => onNavigateTab?.call(4),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildHeaderGreeting(BuildContext context, List<Report> reports, List<Report> drafts) {
    final now = DateTime.now();
    final hour = now.hour;
    final timeGreeting = (hour >= 5 && hour < 12)
        ? 'صباح الخير والنشاط الميداني ☀️'
        : (hour >= 12 && hour < 17)
            ? 'طاب يومك بكل خير وإنجاز ⚡'
            : 'مساء الخير والعمل المتقن 🌙';
    final dateStr = intl.DateFormat('EEEE، d MMMM yyyy', 'ar').format(now);
    final hasDrafts = drafts.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.dashboard_customize_rounded, color: AppTheme.primaryNavy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeGreeting,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: hasDrafts ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasDrafts
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                    : const Color(0xFF10B981).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasDrafts ? Icons.pending_actions_rounded : Icons.verified_user_rounded,
                  size: 14,
                  color: hasDrafts ? const Color(0xFFB45309) : const Color(0xFF059669),
                ),
                const SizedBox(width: 5),
                Text(
                  hasDrafts ? '${drafts.length} مهام جارية' : 'جاهز للمهام',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasDrafts ? const Color(0xFFB45309) : const Color(0xFF065F46),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionHub(BuildContext context) {
    return Row(
      children: [
        // كارت بدء زيارة ميدانية جديدة
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                CreateSessionDialog.show(context);
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0B3A60),
                      Color(0xFF072740),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF0B3A60)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B3A60).withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.solarGold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.electric_bolt_rounded,
                            color: Color(0xFF0F172A),
                            size: 22,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 13,
                          color: Colors.white60,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'بدء زيارة ميدانية',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'فحص وتوثيق مباشر بالموقع',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // كارت إنشاء تقرير فحص
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                CreateSessionDialog.show(context, openSessionDirectly: false);
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFBAE6FD),
                    width: 1.3,
                  ),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.post_add_rounded,
                            color: Color(0xFF0284C7),
                            size: 22,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'إنشاء تقرير فحص',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'من النماذج الفنية المعتمدة',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary(BuildContext context, int totalClients, int totalSites, List<Report> reports, WidgetRef ref) {
    final completedCount = reports.where((r) => r.isCompleted).length;
    final draftCount = reports.where((r) => !r.isCompleted).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        final cardClients = StatsSummaryCard(
          title: 'إجمالي العملاء',
          value: '$totalClients',
          icon: Icons.apartment_rounded,
          color: AppTheme.primaryNavy,
          onTap: () => onNavigateTab?.call(2),
        );

        final cardSites = StatsSummaryCard(
          title: 'إجمالي المواقع',
          value: '$totalSites',
          icon: Icons.solar_power_rounded,
          color: const Color(0xFF0284C7),
          onTap: () => onNavigateTab?.call(2),
        );

        final cardCompleted = StatsSummaryCard(
          title: 'التقارير المكتملة',
          value: '$completedCount',
          icon: Icons.verified_rounded,
          color: const Color(0xFF059669),
          onTap: () {
            ref.read(activeReportsTabFilterProvider.notifier).state = ReportFilterTab.completed;
            onNavigateTab?.call(1);
          },
        );

        final cardDrafts = StatsSummaryCard(
          title: 'مسودات قيد العمل',
          value: '$draftCount',
          icon: Icons.pending_actions_rounded,
          color: const Color(0xFFD97706),
          onTap: () {
            ref.read(activeReportsTabFilterProvider.notifier).state = ReportFilterTab.drafts;
            onNavigateTab?.call(1);
          },
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: cardClients),
              const SizedBox(width: 12),
              Expanded(child: cardSites),
              const SizedBox(width: 12),
              Expanded(child: cardCompleted),
              const SizedBox(width: 12),
              Expanded(child: cardDrafts),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cardClients),
                  const SizedBox(width: 12),
                  Expanded(child: cardSites),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cardCompleted),
                  const SizedBox(width: 12),
                  Expanded(child: cardDrafts),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildPendingDrafts(BuildContext context, List<Report> drafts, WidgetRef ref) {
    final sortedDrafts = List<Report>.from(drafts)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.pending_actions_rounded, size: 18, color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 10),
            const Text(
              'مسودات فحص تحتاج إكمال',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Text(
                '${drafts.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB45309)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedDrafts.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final draft = sortedDrafts[index];
            final client = ref.watch(clientByIdProvider(draft.clientId));
            final site = ref.watch(siteByIdProvider(draft.siteId));
            
            final progress = draft.completionRatio;
            final progressColor = progress < 0.5 
                ? const Color(0xFFEF4444) 
                : (progress < 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: AppTheme.cardShadow,
              ),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportEditorScreen(reportId: draft.id)),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.domain_rounded, size: 14, color: AppTheme.primaryNavy),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${client?.displayName ?? "عميل غير محدد"} > ${site?.displayName ?? "موقع غير محدد"}',
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              intl.DateFormat('yyyy-MM-dd HH:mm').format(draft.updatedAt),
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        draft.facilityInfo.facilityName.isNotEmpty ? draft.facilityInfo.facilityName : draft.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(fontWeight: FontWeight.w900, color: progressColor, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'زيارة #${draft.visitNumber}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFFD97706)),
                            label: const Text('متابعة الفحص', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => MaintenanceSessionScreen(reportId: draft.id)),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 17),
                            label: const Text('المحرر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ReportEditorScreen(reportId: draft.id)),
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
    );
  }

  Widget _buildRecentReports(BuildContext context, List<Report> reports, WidgetRef ref) {
    final recentReports = List<Report>.from(reports)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_rounded, size: 18, color: AppTheme.primaryNavy),
                ),
                const SizedBox(width: 10),
                const Text(
                  'آخر التقارير والزيارات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                ref.read(activeReportsTabFilterProvider.notifier).state = ReportFilterTab.all;
                onNavigateTab?.call(1);
              },
              icon: const Icon(Icons.view_list_rounded, size: 16),
              label: const Text('عرض الكل', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentReports.take(5).length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final report = recentReports[index];
            final client = ref.watch(clientByIdProvider(report.clientId));
            final site = ref.watch(siteByIdProvider(report.siteId));
            
            final isCompleted = report.isCompleted;
            final progress = report.completionRatio;
            
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: AppTheme.cardShadow,
              ),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReportEditorScreen(reportId: report.id)),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.domain_rounded, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${client?.displayName ?? "عميل غير محدد"} > ${site?.displayName ?? "موقع غير محدد"}',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCompleted 
                                    ? const Color(0xFF10B981).withValues(alpha: 0.3) 
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                              color: isCompleted ? const Color(0xFF059669) : const Color(0xFFD97706),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.facilityInfo.facilityName.isNotEmpty ? report.facilityInfo.facilityName : report.title,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'زيارة #${report.facilityInfo.visitNumber.isNotEmpty ? report.facilityInfo.visitNumber : "1"}',
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      intl.DateFormat('yyyy-MM-dd').format(report.updatedAt),
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isCompleted ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCompleted 
                                    ? const Color(0xFF10B981).withValues(alpha: 0.3) 
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              isCompleted ? 'مكتمل' : '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? const Color(0xFF065F46) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: AppTheme.textMuted),
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
    );
  }

  Widget _buildSitesByGovernorate(BuildContext context, Map<String, List<dynamic>> sitesByGov) {
    if (sitesByGov.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.map_rounded, size: 18, color: Color(0xFF0284C7)),
            ),
            const SizedBox(width: 10),
            const Text(
              'التغطية الجغرافية للمواقع',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: sitesByGov.entries.map((entry) {
              final govName = entry.key;
              final sitesInGov = entry.value;
              final siteCount = sitesInGov.length;
              
              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onNavigateTab?.call(2);
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_city_rounded, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          govName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          '$siteCount موقع',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// تجربة البداية الاحترافية للوحة التحكم الفارغة
class _EmptyDashboardExperience extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const _EmptyDashboardExperience({this.onNavigateTab});

  @override
  ConsumerState<_EmptyDashboardExperience> createState() => _EmptyDashboardExperienceState();
}

class _EmptyDashboardExperienceState extends ConsumerState<_EmptyDashboardExperience> {
  bool _isLoadingDemo = false;

  Future<void> _loadDemoReport() async {
    if (_isLoadingDemo) return;
    setState(() => _isLoadingDemo = true);

    try {
      final client = await ref.read(clientsProvider.notifier).addClient(
        nameAr: 'وزارة الصحة العامة والسكان',
        nameEn: 'Ministry of Public Health & Population',
        clientType: 'جهة حكومية / وزارة',
        contactPerson: 'د. عبد الله أحمد - ممثل المرفق',
        phone: '777 123 456',
        notes: 'عميل افتراضي للتقرير التجريبي النموذجي',
      );

      final site = await ref.read(sitesProvider.notifier).addSite(
        clientId: client.id,
        nameAr: 'مستشفى الثورة العام - مركز الغسيل الكلوي',
        nameEn: 'Al-Thawra General Hospital - Dialysis Center',
        governorate: 'صنعاء',
        directorate: 'السبعين',
        facilityType: 'مستشفى / مركز صحي',
        category: 'CAT 8',
        projectName: 'توريد وتركيب وصيانة 21 منظومة طاقة شمسية منفصلة عن الشبكة',
        contactPerson: 'د. عبد الله أحمد',
        phone: '777 123 456',
        systemSpecs: const SystemSpecs(
          systemType: 'منظومة طاقة شمسية منفصلة عن الشبكة Off-Grid',
          capacityKw: '57.6 kW',
          panelsCountAndWatt: '96 x 600Wp',
          invertersCapacity: '10KVA',
          invertersCount: '6',
          chargeControllersCapacity: '100 A (150-250) Vdc',
          chargeControllersCount: '13',
          batteryUnitsCapacity: '2500Ah',
          batteryUnitsCount: '96 x 2V',
          otherAppliances: 'مكيف هواء 1 طن عدد 2',
        ),
      );

      final sampleReport = DefaultTemplates.sampleDialysisReport.copyWith(
        clientId: client.id,
        siteId: site.id,
        updatedAt: DateTime.now(),
      );
      await ref.read(reportsProvider.notifier).addReport(sampleReport);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportEditorScreen(reportId: sampleReport.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل التقرير التجريبي: $e'),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.solarGold.withValues(alpha: 0.12),
            border: Border.all(color: AppTheme.solarGold.withValues(alpha: 0.35), width: 2),
          ),
          child: const Icon(Icons.solar_power_rounded, size: 44, color: AppTheme.solarGold),
        ),
        const SizedBox(height: 18),
        const Text(
          'أهلاً بك في ReportCraft! ⚡',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'منظومتك المتكاملة لتوثيق وإدارة تقارير صيانة الطاقة الشمسية.\nاختر كيف تود البدء اليوم:',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.5),
        ),
        const SizedBox(height: 24),

        // بطاقة المسار السريع: تقرير تجريبي
        InkWell(
          onTap: _isLoadingDemo ? null : _loadDemoReport,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryNavy, Color(0xFF1E3C72)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.solarGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isLoadingDemo
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryNavy),
                        )
                      : const Icon(Icons.rocket_launch_rounded, color: AppTheme.primaryNavy, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'تقرير تجريبي',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.solarGold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'موصى به',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'استعرض نموذج مركز الغسيل الكلوي (11 صفحة مع الـ PDF)',
                        style: TextStyle(fontSize: 11.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // بطاقة إضافة أول عميل
        InkWell(
          onTap: () => widget.onNavigateTab?.call(2),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.brandCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_rounded, color: AppTheme.brandCyan, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إضافة عميل ومنشأة جديدة',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'سجّل بيانات الجهة ومواقع المنظومات لبدء عملك الميداني',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // زر تشغيل معالج الإعداد
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingScreen(isFromSettings: true)),
            );
          },
          icon: const Icon(Icons.tune_rounded, size: 16, color: AppTheme.textMuted),
          label: const Text(
            'تشغيل معالج الإعداد التفاعلي',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

