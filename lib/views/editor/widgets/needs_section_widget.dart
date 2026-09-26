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

  void _setAllPdfVisibility(BuildContext context, bool includeAll) {
    final total = report.requestedNeeds.length;
    final updatedNeeds = report.requestedNeeds.map((n) => n.copyWith(includeInPdf: includeAll)).toList();
    onReportUpdated(report.copyWith(
      requestedNeeds: updatedNeeds,
      showNeedsInReport: includeAll ? true : report.showNeedsInReport,
      updatedAt: DateTime.now(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(includeAll
            ? 'تم تحديد كافة المواد ($total) للظهور في تقرير الـ PDF'
            : 'تم إلغاء تحديد كافة المواد من الظهور في تقرير الـ PDF'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentVisit = report.visitNumber.isNotEmpty ? report.visitNumber : '1';
    final targetVisit = ((int.tryParse(currentVisit) ?? 1) + 1).toString();

    final totalNeeds = report.requestedNeeds.length;
    final criticalCount = report.requestedNeeds.where((n) => n.priority == NeedPriority.critical).length;
    final urgentCount = report.requestedNeeds.where((n) => n.priority == NeedPriority.urgent).length;
    final normalCount = report.requestedNeeds.where((n) => n.priority == NeedPriority.normal).length;
    final installedCount = report.requestedNeeds.where((n) => n.status == NeedStatus.installed).length;
    final selectedForPdfCount = report.requestedNeeds.where((n) => n.includeInPdf).length;
    final isAllSelected = totalNeeds > 0 && selectedForPdfCount == totalNeeds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Master PDF Visibility Card
        Container(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: report.showNeedsInReport
                      ? AppTheme.primaryNavy.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: report.showNeedsInReport ? AppTheme.primaryNavy : AppTheme.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تضمين جدول الاحتياجات في تقرير الـ PDF',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.showNeedsInReport
                          ? 'سيتم توليد ملحق رسمي بجدول المواد والقطع المحددة للزيارة القادمة.'
                          : 'الجدول محجوب من الـ PDF — محفوظ كبيانات داخلية لفريق الصيانة.',
                      style: TextStyle(
                        fontSize: 11,
                        color: report.showNeedsInReport ? AppTheme.brandCyan : AppTheme.textMuted,
                        fontWeight: report.showNeedsInReport ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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
        ),

        const SizedBox(height: 12),

        // 2. Metrics Summary - Responsive Scrollable Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildStatCard(
                title: 'إجمالي المواد',
                count: totalNeeds,
                color: AppTheme.primaryNavy,
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                title: 'حرجة',
                count: criticalCount,
                color: const Color(0xFFD32F2F),
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                title: 'عاجلة',
                count: urgentCount,
                color: const Color(0xFFED6C02),
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                title: 'وقائية',
                count: normalCount,
                color: const Color(0xFF2E7D32),
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                title: 'تم التركيب',
                count: installedCount,
                color: AppTheme.brandCyan,
                icon: Icons.task_alt_rounded,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                title: 'محدد بالتقرير',
                count: selectedForPdfCount,
                color: Colors.indigo,
                icon: Icons.picture_as_pdf_outlined,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Section Title & Add Button Bar (Overflow-Free)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'المواد المطلوبة للزيارة القادمة',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.brandCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'الزيارة رقم $targetVisit',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الموقع: ${report.facilityInfo.facilityName.isNotEmpty ? report.facilityInfo.facilityName : "المنشأة الحالية"}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                visualDensity: VisualDensity.compact,
                elevation: 0,
              ),
              icon: const Icon(Icons.add_circle_outline, size: 16, color: AppTheme.solarGold),
              label: const Text('إضافة مادة', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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

        // 4. Select All / Deselect All Action Bar
        if (totalNeeds > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isAllSelected
                  ? const Color(0xFFF0FDF4)
                  : (selectedForPdfCount == 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAllSelected
                    ? Colors.green.shade300
                    : (selectedForPdfCount == 0 ? Colors.red.shade200 : AppTheme.borderSubtle),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAllSelected
                      ? Icons.check_circle_rounded
                      : (selectedForPdfCount == 0 ? Icons.cancel_outlined : Icons.tune_rounded),
                  size: 18,
                  color: isAllSelected
                      ? Colors.green.shade700
                      : (selectedForPdfCount == 0 ? Colors.red.shade700 : AppTheme.primaryNavy),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الظهور في التقرير: $selectedForPdfCount من $totalNeeds مادة',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isAllSelected
                              ? Colors.green.shade800
                              : (selectedForPdfCount == 0 ? Colors.red.shade800 : AppTheme.textDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!report.showNeedsInReport)
                        Text(
                          'تنبيه: قسم الاحتياجات محجوب من الـ PDF (فعّل المفتاح بالأعلى)',
                          style: TextStyle(fontSize: 9.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    if (!isAllSelected)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.08),
                          foregroundColor: AppTheme.primaryNavy,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.select_all_rounded, size: 15),
                        label: const Text('تحديد الكل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _setAllPdfVisibility(context, true),
                      ),
                    if (selectedForPdfCount > 0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFFEE2E2),
                          foregroundColor: const Color(0xFFB91C1C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.deselect_rounded, size: 15),
                        label: const Text('إلغاء الكل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _setAllPdfVisibility(context, false),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // 5. List of Needs or Empty State
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined, size: 38, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد مواد أو قطع غيار مسجلة لهذه الزيارة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تستطيع إضافة قطع الغيار المطلوبة إما مباشرة من شاشة الفحص الميداني عند رصد أي عطل، أو عبر زر "إضافة مادة" أعلاه.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 14),
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
    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildNeedItemCard(BuildContext context, int serial, MaintenanceNeedItem need) {
    final isIncluded = need.includeInPdf;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isIncluded ? AppTheme.primaryNavy.withValues(alpha: 0.35) : AppTheme.borderSubtle,
          width: isIncluded ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isIncluded ? AppTheme.primaryNavy.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Badges - Serial + Category + Priority + Status (Wrapped & Overflow-Free)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Serial Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$serial',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    // Category Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        need.category,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                    ),
                    // Priority Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: need.priority.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: need.priority.color, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(need.priority.icon, size: 11, color: need.priority.color),
                          const SizedBox(width: 3),
                          Text(
                            need.priority.labelAr,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: need.priority.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Status Pill (Clickable to advance)
                InkWell(
                  onTap: () => _toggleNeedStatus(need),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: need.status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: need.status.color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(need.status.icon, size: 12, color: need.status.color),
                        const SizedBox(width: 3),
                        Text(
                          need.status.labelAr,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: need.status.color),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.sync_alt, size: 10, color: need.status.color),
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
                    child: Builder(builder: (_) {
                      try {
                        return Image.memory(
                          base64Decode(need.photoBase64!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined, size: 20, color: AppTheme.textMuted),
                          ),
                        );
                      } catch (_) {
                        return Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_outlined, size: 20, color: AppTheme.textMuted),
                        );
                      }
                    }),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'الكمية: ${need.quantity % 1 == 0 ? need.quantity.toInt() : need.quantity} ${need.unit}',
                        style: const TextStyle(
                          fontSize: 11.5,
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

            const Divider(height: 16),

            // Row 3: Include in PDF toggle + Edit & Delete
            Row(
              children: [
                InkWell(
                  onTap: () => _toggleItemPdf(need, !need.includeInPdf),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 22,
                          width: 22,
                          child: Checkbox(
                            value: need.includeInPdf,
                            activeColor: AppTheme.primaryNavy,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) => _toggleItemPdf(need, val ?? true),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تضمين في التقرير',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: need.includeInPdf ? AppTheme.primaryNavy : AppTheme.textMuted,
                            fontWeight: need.includeInPdf ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.brandCyan),
                  tooltip: 'تعديل المادة',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    QuickNeedDialog.show(
                      context,
                      report: report,
                      existingNeed: need,
                      onSave: (updated) => _onNeedSaved(context, updated),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  tooltip: 'حذف',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
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
