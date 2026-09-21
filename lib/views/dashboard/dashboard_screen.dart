import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_defaults.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../state/reports_provider.dart';
import '../../state/branding_provider.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../models/report.dart';
import '../editor/widgets/stats_summary_card.dart';
import '../editor/report_editor_screen.dart';
import '../preview/pdf_preview_screen.dart';
import '../session/dialogs/create_session_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);
    final branding = ref.watch(brandingProvider);
    final clients = ref.watch(clientsProvider);
    final sites = ref.watch(sitesProvider);

    final completedCount = reports.where((r) => r.status == ReportStatus.completed).length;
    final draftCount = reports.where((r) => r.status == ReportStatus.draft).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.solar_power, color: AppTheme.solarGold, size: 20),
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
        ],
      ),
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
                // Modern Android M3 Quick Action Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                    boxShadow: AppTheme.cardShadow,
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
                            child: const Icon(Icons.flash_on_rounded, color: AppTheme.solarGold, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'إجراءات سريعة',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.bgSurface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: const Text(
                              'UNOPS • MOH (11 صفحة)',
                              style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildM3ActionButton(
                              icon: Icons.add_rounded,
                              label: 'تقرير جديد',
                              bgColor: AppTheme.primaryNavy,
                              fgColor: Colors.white,
                              onTap: () {
                                CreateSessionDialog.show(
                                  context,
                                  openSessionDirectly: false,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildM3ActionButton(
                              icon: Icons.picture_as_pdf_outlined,
                              label: 'معاينة PDF',
                              bgColor: AppTheme.bgSurface,
                              fgColor: AppTheme.textSecondary,
                              borderColor: AppTheme.borderSubtle,
                              onTap: () {
                                if (reports.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('يرجى إنشاء أو فتح تقرير للمعاينة')),
                                  );
                                } else if (reports.length == 1) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => PdfPreviewScreen(report: reports.first)),
                                  );
                                } else {
                                  _showSelectReportSheet(context, reports);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // بطاقة دليل العملاء والمواقع
                InkWell(
                  onTap: () => onNavigateTab?.call(2),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.business_center, color: AppTheme.solarGold, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'دليل العملاء والمواقع والمنشآت',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${clients.length} جهات وعملاء معتمدين • ${sites.length} مواقع ميدانية بممولين مستقلين',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.brandCyan),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Responsive Statistics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(
                            child: StatsSummaryCard(
                              title: 'إجمالي التقارير',
                              value: '${reports.length}',
                              icon: Icons.description_outlined,
                              color: AppTheme.primaryNavy,
                              onTap: () => onNavigateTab?.call(1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatsSummaryCard(
                              title: 'المكتملة والجاهزة',
                              value: '$completedCount',
                              icon: Icons.check_circle_outline,
                              color: AppTheme.statusGood,
                              onTap: () => onNavigateTab?.call(1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatsSummaryCard(
                              title: 'قيد التحرير (مسودة)',
                              value: '$draftCount',
                              icon: Icons.edit_note_outlined,
                              color: AppTheme.statusFollowup,
                              onTap: () => onNavigateTab?.call(1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatsSummaryCard(
                              title: 'المواقع والمنشآت',
                              value: '${sites.length}',
                              icon: Icons.location_city_outlined,
                              color: AppTheme.brandCyan,
                              onTap: () => onNavigateTab?.call(2),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: StatsSummaryCard(
                                  title: 'إجمالي التقارير',
                                  value: '${reports.length}',
                                  icon: Icons.description_outlined,
                                  color: AppTheme.primaryNavy,
                                  onTap: () => onNavigateTab?.call(1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: StatsSummaryCard(
                                  title: 'المكتملة',
                                  value: '$completedCount',
                                  icon: Icons.check_circle_outline,
                                  color: AppTheme.statusGood,
                                  onTap: () => onNavigateTab?.call(1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: StatsSummaryCard(
                                  title: 'مسودة',
                                  value: '$draftCount',
                                  icon: Icons.edit_note_outlined,
                                  color: AppTheme.statusFollowup,
                                  onTap: () => onNavigateTab?.call(1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: StatsSummaryCard(
                                  title: 'المواقع والمنشآت',
                                  value: '${sites.length}',
                                  icon: Icons.location_city_outlined,
                                  color: AppTheme.brandCyan,
                                  onTap: () => onNavigateTab?.call(2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Recent Reports Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'أحدث التقارير الميدانية',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('عرض كافة التقارير'),
                      onPressed: () => onNavigateTab?.call(1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (reports.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد تقارير حالياً',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'اضغط زر "إنشاء تقرير جديد" لتوليد تقرير صيانة جديد من القالب المعتمد.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reports.take(5).length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return _buildReportCard(context, ref, report);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, WidgetRef ref, Report report) {
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppTheme.statusGoodBg
                            : AppTheme.statusFollowupBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCompleted
                              ? AppTheme.statusGood.withValues(alpha: 0.3)
                              : AppTheme.statusFollowup.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        color: isCompleted ? AppTheme.statusGood : AppTheme.statusFollowup,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.facilityInfo.facilityName.isNotEmpty
                                ? report.facilityInfo.facilityName
                                : report.title,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'عقد: ${report.contractNumber} • ${report.facilityInfo.visitDate}',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppTheme.statusGoodBg
                            : AppTheme.statusFollowupBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCompleted
                              ? AppTheme.statusGood.withValues(alpha: 0.4)
                              : AppTheme.statusFollowup.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        isCompleted ? 'مكتمل ومعتمد' : 'مسودة (${(progress * 100).toInt()}%)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isCompleted ? AppTheme.statusGood : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? AppTheme.statusGood : AppTheme.brandCyan,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.systemSpecs.capacityKw.isNotEmpty ? report.systemSpecs.capacityKw : AppDefaults.defaultCapacityKw,
                        style: const TextStyle(fontSize: 11, color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${report.activeBatteryGroups.length} مجموعات بطاريات',
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppTheme.primaryNavy),
                      tooltip: 'تصدير ومشاركة PDF',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PdfPreviewScreen(report: report)),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textDark),
                      tooltip: 'تعديل التقرير',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ReportEditorScreen(reportId: report.id)),
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

  Widget _buildM3ActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectReportSheet(BuildContext context, List<Report> reports) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختر التقرير المطلوب للمعاينة والتصدير:',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textDark),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.borderSubtle),
                  itemBuilder: (context, idx) {
                    final rep = reports[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: rep.status == ReportStatus.completed
                            ? AppTheme.statusGoodBg
                            : AppTheme.statusFollowupBg,
                        child: Icon(
                          rep.status == ReportStatus.completed ? Icons.check_circle : Icons.pending_actions,
                          size: 18,
                          color: rep.status == ReportStatus.completed
                              ? AppTheme.statusGood
                              : AppTheme.statusFollowup,
                        ),
                      ),
                      title: Text(
                        rep.facilityInfo.facilityName.isNotEmpty ? rep.facilityInfo.facilityName : rep.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'عقد: ${rep.contractNumber} • تاريخ: ${rep.facilityInfo.visitDate}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      trailing: const Icon(Icons.chevron_left, size: 20, color: AppTheme.textMuted),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PdfPreviewScreen(report: rep)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
