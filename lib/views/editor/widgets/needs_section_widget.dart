import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/maintenance_need.dart';
import '../../../../models/report.dart';
import '../../session/widgets/quick_need_dialog.dart';

class NeedsSectionWidget extends StatelessWidget {
  final Report report;
  final ValueChanged<Report> onReportUpdated;

  const NeedsSectionWidget({
    super.key,
    required this.report,
    required this.onReportUpdated,
  });

  void _onNeedSaved(BuildContext context, MaintenanceNeedItem need) {
    final existingIdx = report.requestedNeeds.indexWhere((n) => n.id == need.id);
    final updatedNeeds = List<MaintenanceNeedItem>.from(report.requestedNeeds);
    if (existingIdx >= 0) {
      updatedNeeds[existingIdx] = need;
    } else {
      updatedNeeds.add(need);
    }
    onReportUpdated(report.copyWith(
      requestedNeeds: updatedNeeds,
      updatedAt: DateTime.now(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ المادة "${need.name}" بنجاح'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteNeed(BuildContext context, String needId) {
    final updatedNeeds = report.requestedNeeds.where((n) => n.id != needId).toList();
    onReportUpdated(report.copyWith(
      requestedNeeds: updatedNeeds,
      updatedAt: DateTime.now(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف المادة من القائمة'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleNeedStatus(MaintenanceNeedItem need) {
    final nextStatus = switch (need.status) {
      NeedStatus.requested => NeedStatus.supplied,
      NeedStatus.supplied => NeedStatus.installed,
      NeedStatus.installed => NeedStatus.requested,
      NeedStatus.cancelled => NeedStatus.requested,
    };
    final updatedItem = need.copyWith(
      status: nextStatus,
      installedAt: nextStatus == NeedStatus.installed ? DateTime.now() : null,
    );
    final updatedNeeds = report.requestedNeeds.map((n) => n.id == need.id ? updatedItem : n).toList();
    onReportUpdated(report.copyWith(
      requestedNeeds: updatedNeeds,
      updatedAt: DateTime.now(),
    ));
  }

  void _toggleItemPdf(MaintenanceNeedItem need, bool val) {
    final updatedItem = need.copyWith(includeInPdf: val);
    final updatedNeeds = report.requestedNeeds.map((n) => n.id == need.id ? updatedItem : n).toList();
    onReportUpdated(report.copyWith(
      requestedNeeds: updatedNeeds,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final currentVisit = report.visitNumber.isNotEmpty ? report.visitNumber : '1';
    final targetVisit = ((int.tryParse(currentVisit) ?? 1) + 1).toString();

    final criticalCount = report.requestedNeeds.where((n) => n.priority == NeedPriority.critical).length;
    final urgentCount = report.requestedNeeds.where((n) => n.priority == NeedPriority.urgent).length;
    final normalCount = report.requestedNeeds.where((n) => n.priority == NeedPriority.normal).length;
    final installedCount = report.requestedNeeds.where((n) => n.status == NeedStatus.installed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master PDF Visibility & Privacy Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: report.showNeedsInReport ? AppTheme.primaryNavy.withValues(alpha: 0.3) : AppTheme.borderSubtle,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: report.showNeedsInReport
                          ? AppTheme.primaryNavy.withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: report.showNeedsInReport ? AppTheme.primaryNavy : AppTheme.textMuted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تضمين جدول الاحتياجات في تقرير الـ PDF المعتمد',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          report.showNeedsInReport
                              ? 'سيتم توليد صفحة ملحق رسمية بجدول المواد والقطع المطلوبة للزيارة القادمة.'
                              : 'الجدول محجوب من الـ PDF — محفوظ كبيانات وسجل داخلي للمقاول وفريق الصيانة.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: report.showNeedsInReport ? AppTheme.brandCyan : AppTheme.textMuted,
                            fontWeight: report.showNeedsInReport ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: report.showNeedsInReport,
                    activeThumbColor: AppTheme.solarGold,
                    activeTrackColor: AppTheme.primaryNavy,
                    onChanged: (val) {
                      onReportUpdated(report.copyWith(
                        showNeedsInReport: val,
                        updatedAt: DateTime.now(),
                      ));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Metrics Summary Row
        Row(
          children: [
            _buildStatCard(
              title: 'إجمالي المواد',
              count: report.requestedNeeds.length,
              color: AppTheme.primaryNavy,
              icon: Icons.inventory_2_outlined,
            ),
            const SizedBox(width: 6),
            _buildStatCard(
              title: 'حرجة',
              count: criticalCount,
              color: const Color(0xFFD32F2F),
              icon: Icons.error_outline_rounded,
            ),
            const SizedBox(width: 6),
            _buildStatCard(
              title: 'عاجلة',
              count: urgentCount,
              color: const Color(0xFFED6C02),
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(width: 6),
            _buildStatCard(
              title: 'وقائية',
              count: normalCount,
              color: const Color(0xFF2E7D32),
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(width: 6),
            _buildStatCard(
              title: 'تم التركيب',
              count: installedCount,
              color: AppTheme.brandCyan,
              icon: Icons.task_alt_rounded,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Section Title & Add Button Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'المواد المطلوبة للزيارة القادمة',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.brandCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'الزيارة رقم $targetVisit',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                      ),
                    ),
                  ],
                ),
                Text(
                  'الموقع: ${report.facilityInfo.facilityName.isNotEmpty ? report.facilityInfo.facilityName : "المنشأة الحالية"}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.solarGold),
              label: const Text('إضافة مادة يدوياً', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              onPressed: () {
                QuickNeedDialog.show(
                  context,
                  report: report,
                  onSave: (need) => _onNeedSaved(context, need),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        // List of Needs or Empty State
        if (report.requestedNeeds.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 14),
                const Text(
                  'لا توجد مواد أو قطع غيار مسجلة لهذه الزيارة',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تستطيع إضافة قطع الغيار المطلوبة إما مباشرة من شاشة الفحص الميداني عند رصد أي عطل، أو عبر زر "إضافة مادة يدوياً" أعلاه.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    side: const BorderSide(color: AppTheme.primaryNavy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('تسجيل أول مادة للزيارة القادمة'),
                  onPressed: () {
                    QuickNeedDialog.show(
                      context,
                      report: report,
                      onSave: (need) => _onNeedSaved(context, need),
                    );
                  },
                ),
              ],
            ),
          ),
        ] else ...[
          ...report.requestedNeeds.asMap().entries.map((entry) {
            final idx = entry.key;
            final need = entry.value;
            return _buildNeedItemCard(context, idx + 1, need);
          }),
        ],
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedItemCard(BuildContext context, int serial, MaintenanceNeedItem need) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Serial + Category + Priority + Status + Menu
            Row(
              children: [
                // Serial Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#$serial',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    need.category,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                ),
                const SizedBox(width: 6),
                // Priority Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: need.priority.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: need.priority.color, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(need.priority.icon, size: 12, color: need.priority.color),
                      const SizedBox(width: 4),
                      Text(
                        need.priority.labelAr,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: need.priority.color),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Status Pill (Clickable to advance)
                InkWell(
                  onTap: () => _toggleNeedStatus(need),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: need.status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: need.status.color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(need.status.icon, size: 13, color: need.status.color),
                        const SizedBox(width: 4),
                        Text(
                          need.status.labelAr,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: need.status.color),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.sync_alt, size: 11, color: need.status.color),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: Item Name & Quantity
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (need.photoBase64 != null && need.photoBase64!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(need.photoBase64!),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        need.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'الكمية: ${need.quantity % 1 == 0 ? need.quantity.toInt() : need.quantity} ${need.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.brandCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Reason & Related Item Note
            if (need.reason.isNotEmpty || need.relatedInspectionItemTitle != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (need.relatedInspectionItemTitle != null)
                      Text(
                        'بند الفحص: ${need.relatedInspectionItemTitle}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      ),
                    if (need.reason.isNotEmpty)
                      Text(
                        'سبب الطلب: ${need.reason}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
            ],

            const Divider(height: 18),

            // Row 3: Include in PDF toggle + Edit & Delete
            Row(
              children: [
                InkWell(
                  onTap: () => _toggleItemPdf(need, !need.includeInPdf),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: need.includeInPdf,
                        activeColor: AppTheme.primaryNavy,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (val) => _toggleItemPdf(need, val ?? true),
                      ),
                      Text(
                        'عرض في PDF',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: need.includeInPdf ? AppTheme.primaryNavy : AppTheme.textMuted,
                          fontWeight: need.includeInPdf ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19, color: AppTheme.brandCyan),
                  tooltip: 'تعديل المادة',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    QuickNeedDialog.show(
                      context,
                      report: report,
                      existingNeed: need,
                      onSave: (updated) => _onNeedSaved(context, updated),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 19, color: Colors.red),
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteNeed(context, need.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
