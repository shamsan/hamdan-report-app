import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/report.dart';
import '../../../models/inspection_item.dart';
import '../../../core/theme/app_theme.dart';

/// Modern, creative, and fully responsive Export Readiness Dialog
/// Prevents screen overflow on all mobile devices and provides an executive inspection checklist.
class ReportReadinessDialog extends StatelessWidget {
  final Report report;
  final VoidCallback onExportNow;
  final VoidCallback? onEditReport;

  const ReportReadinessDialog({
    super.key,
    required this.report,
    required this.onExportNow,
    this.onEditReport,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Calculate detailed readiness metrics
    final missingFields = report.validateMissingFields();
    final progress = report.completionRatio;
    final percent = (progress * 100).round();

    // Categorized Inspection Details
    final totalInspectionItems = report.inspectionGroups.fold<int>(
      0, (sum, g) => sum + g.items.length,
    );
    final uninspectedCount = report.inspectionGroups.fold<int>(
      0, (sum, g) => sum + g.items.where((i) => i.status == InspectionStatus.uninspected).length,
    );
    final inspectedCount = totalInspectionItems - uninspectedCount;
    final rejectedCount = report.inspectionGroups.fold<int>(
      0, (sum, g) => sum + g.items.where((i) => i.status == InspectionStatus.rejected || i.status == InspectionStatus.needsFollowup).length,
    );

    // Signatures details
    final hasEngSig = report.signatures.any((s) => s.signatureBase64 != null && s.signatureBase64!.isNotEmpty) ||
        (report.approvalStatement.contractorSignatureBase64 != null && report.approvalStatement.contractorSignatureBase64!.isNotEmpty);
    final hasBenSig = (report.approvalStatement.beneficiarySignatureBase64 != null && report.approvalStatement.beneficiarySignatureBase64!.isNotEmpty);
    final hasStamp = (report.approvalStatement.stampBase64 != null && report.approvalStatement.stampBase64!.isNotEmpty);

    // Battery measurements details
    final totalBatteries = report.batteryMeasurements.length;
    final measuredBatteries = report.batteryMeasurements.where((b) => b.voltage > 0).length;

    // Section Readiness Status
    final isSec1Complete = report.projectInfo.projectName.trim().isNotEmpty &&
        report.facilityInfo.facilityName.trim().isNotEmpty &&
        report.contractNumber.trim().isNotEmpty &&
        report.visitDate.trim().isNotEmpty;

    final isSec2Complete = uninspectedCount == 0 && totalInspectionItems > 0;
    final isSec3Complete = totalBatteries == 0 || measuredBatteries > 0;
    final isSec4Complete = hasEngSig;
    final isSec5Complete = report.photos.isNotEmpty;

    int completeCount = 0;
    if (isSec1Complete) completeCount++;
    if (isSec2Complete) completeCount++;
    if (isSec3Complete) completeCount++;
    if (isSec4Complete) completeCount++;
    if (isSec5Complete) completeCount++;

    // Color theme based on score
    final Color scoreColor = percent >= 90
        ? const Color(0xFF10B981) // Emerald
        : (percent >= 65
            ? const Color(0xFFF59E0B) // Amber
            : const Color(0xFFEF4444)); // Rose

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Executive Gradient Header
              _buildHeader(context, scoreColor),

              // 2. Scrollable Body Content (Guaranteed No Overflow)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Score Gauge Card
                      _buildScoreCard(
                        percent: percent,
                        scoreColor: scoreColor,
                        completeCount: completeCount,
                        missingCount: missingFields.length,
                        hasWarnings: rejectedCount > 0,
                      ),
                      const SizedBox(height: 16),

                      // Section Title
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.brandCyan,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'تفاصيل جاهزية أقسام التقرير',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Section 1: Basic Information
                      _buildSectionTile(
                        icon: Icons.business_outlined,
                        title: 'البيانات الأساسية للمشروع والمرفق',
                        isComplete: isSec1Complete,
                        summary: isSec1Complete
                            ? 'اسم المشروع، المرفق، رقم العقد، وتاريخ الزيارة مكتملة'
                            : 'توجد بيانات أساسية ناقصة',
                        details: [
                          _buildDetailRow('اسم المشروع', report.projectInfo.projectName),
                          _buildDetailRow('اسم المنشأة الخدمية', report.facilityInfo.facilityName),
                          _buildDetailRow('رقم العقد', report.contractNumber),
                          _buildDetailRow('تاريخ الزيارة', report.visitDate),
                          _buildDetailRow(
                            'رقم الزيارة',
                            report.visitNumber.isNotEmpty ? report.visitNumber : report.facilityInfo.visitNumber,
                            isOptional: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Section 2: Technical Inspection
                      _buildSectionTile(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'الفحص الميداني الفني',
                        isComplete: isSec2Complete,
                        summary: totalInspectionItems == 0
                            ? 'لا توجد بنود فحص مسجلة'
                            : (uninspectedCount == 0
                                ? 'تم تقييم كافة بنود الفحص ($totalInspectionItems بند)'
                                : 'متبقي $uninspectedCount بند لم يتم تقييمها بعد'),
                        details: [
                          _buildDetailItem(
                            'إجمالي بنود الفحص المقيمة',
                            '$inspectedCount من $totalInspectionItems',
                            isGood: uninspectedCount == 0,
                          ),
                          if (rejectedCount > 0)
                            _buildDetailItem(
                              'بنود تحتاج متابعة / مرفوضة',
                              '$rejectedCount بند',
                              isWarning: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Section 3: Batteries & Operational Data
                      _buildSectionTile(
                        icon: Icons.battery_charging_full_outlined,
                        title: 'قياسات البطاريات والتشغيل',
                        isComplete: isSec3Complete,
                        summary: totalBatteries == 0
                            ? 'لا توجد قياسات مسجلة للبطاريات'
                            : (measuredBatteries == totalBatteries
                                ? 'تم تسجيل قياسات كافة البطاريات ($measuredBatteries خلية)'
                                : 'تم تسجيل $measuredBatteries من إجمالي $totalBatteries خلية'),
                        details: [
                          _buildDetailItem(
                            'خلايا البطاريات المقاسة',
                            '$measuredBatteries / $totalBatteries',
                            isGood: measuredBatteries > 0,
                          ),
                          _buildDetailItem(
                            'بيانات الإنفرترات ومنظمات الشحن',
                            report.operationalData.isNotEmpty ? 'مسجلة' : 'فارغة',
                            isGood: report.operationalData.isNotEmpty,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Section 4: Signatures & Approvals
                      _buildSectionTile(
                        icon: Icons.draw_outlined,
                        title: 'التوقيعات والاعتماد الرسمي',
                        isComplete: isSec4Complete,
                        summary: hasEngSig
                            ? (hasBenSig && hasStamp ? 'جميع التوقيعات والختم مكتملة' : 'تم إضافة توقيع مهندس الصيانة')
                            : 'لم يتم إضافة توقيع مهندس الصيانة بعد',
                        details: [
                          _buildDetailItem(
                            'توقيع مهندس الصيانة',
                            hasEngSig ? 'مكتمل ومعتمد' : 'غير مضاف *',
                            isGood: hasEngSig,
                          ),
                          _buildDetailItem(
                            'توقيع ممثل الجهة المستفيدة',
                            hasBenSig ? 'مضاف' : 'فارغ (يمكن توقيعه يدوياً)',
                            isGood: hasBenSig,
                            isWarning: !hasBenSig,
                          ),
                          _buildDetailItem(
                            'ختم المنشأة / المرفق',
                            hasStamp ? 'مضاف' : 'فارغ (يُختم ورقياً)',
                            isGood: hasStamp,
                            isWarning: !hasStamp,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Section 5: Photos Appendix
                      _buildSectionTile(
                        icon: Icons.photo_library_outlined,
                        title: 'التوثيق الفوتوغرافي الميداني',
                        isComplete: isSec5Complete,
                        summary: report.photos.isNotEmpty
                            ? 'يحتوي التقرير على ${report.photos.length} صورة توثيقية ملحقة'
                            : 'لا توجد صور توثيقية ملحقة (ملحق اختياري)',
                        details: [
                          _buildDetailItem(
                            'عدد الصور المرفقة',
                            '${report.photos.length} صورة',
                            isGood: report.photos.isNotEmpty,
                          ),
                          _buildDetailItem(
                            'الصفحة 12 (ملحق الصور)',
                            report.photos.isNotEmpty ? 'سيتم تصديرها تلقائياً' : 'لن يتم تصديرها لعدم وجود صور',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Section 6: Next Visit Requisitions
                      _buildSectionTile(
                        icon: Icons.inventory_2_outlined,
                        title: 'الاحتياجات والمواد للزيارة القادمة',
                        isComplete: true,
                        summary: report.requestedNeeds.isNotEmpty
                            ? (report.showNeedsInReport
                                ? 'سيتم تصدير صفحة ملحق رسمية بالمواد (${report.requestedNeeds.length} مادة مطلوبة)'
                                : 'تم تسجيل ${report.requestedNeeds.length} مادة (محجوبة من PDF التقرير كسجل داخلي)')
                            : 'لا توجد مواد أو قطع غيار مطلوبة للزيارة القادمة',
                        details: [
                          _buildDetailItem(
                            'المواد المطلوبة',
                            '${report.requestedNeeds.length} مادة',
                            isGood: report.requestedNeeds.isNotEmpty,
                          ),
                          _buildDetailItem(
                            'الظهور في الـ PDF',
                            report.showNeedsInReport ? 'مفعّل (ملحق رسمي)' : 'مخفي (سجل داخلي)',
                            isGood: report.showNeedsInReport,
                          ),
                        ],
                      ),

                      if (missingFields.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildMissingFieldsAlert(missingFields),
                      ],
                    ],
                  ),
                ),
              ),

              // 3. Fixed Bottom Action Bar
              _buildBottomBar(context, percent),
            ],
          ),
        ),
      ),
    );
  }

  /// Executive Header Widget
  Widget _buildHeader(BuildContext context, Color scoreColor) {
    final facName = report.facilityInfo.facilityName.isNotEmpty
        ? report.facilityInfo.facilityName
        : 'المرفق الخدمي';
    final visitDate = report.visitDate.isNotEmpty ? report.visitDate : 'تاريخ غير محدد';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B3A60), Color(0xFF06223A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fact_check_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فحص جاهزية التقرير للتصدير',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$facName  •  $visitDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
            tooltip: 'إغلاق',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  /// Circular Progress & Score Card
  Widget _buildScoreCard({
    required int percent,
    required Color scoreColor,
    required int completeCount,
    required int missingCount,
    required bool hasWarnings,
  }) {
    String statusTitle;
    String statusDesc;

    if (percent >= 95) {
      statusTitle = 'التقرير مكتمل 100% وجاهز للاعتماد';
      statusDesc = 'كافة الفحوصات والبيانات الأساسية والتوقيعات معتمدة ومجهزة.';
    } else if (percent >= 70) {
      statusTitle = 'التقرير شبه مكتمل - جاهز مع ملاحظات';
      statusDesc = 'يمكنك التصدير الآن مع مراعاة الحقول التنبيهية المبينة أدناه.';
    } else {
      statusTitle = 'التقرير غير مكتمل - يتطلب بيانات هامة';
      statusDesc = 'يرجى مراجعة الحقول الأساسية قبل المشاركة الرسمية للتقرير.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Progress Indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  strokeWidth: 6.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppTheme.borderMedium.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Status Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDesc,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                // Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildMiniBadge(
                      label: '$completeCount / 5 مكتمل',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                      bgColor: const Color(0xFFECFDF5),
                    ),
                    if (missingCount > 0)
                      _buildMiniBadge(
                        label: '$missingCount حقول ناقصة',
                        icon: Icons.cancel_rounded,
                        color: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFFEF2F2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section Card Tile with expansion/summary
  Widget _buildSectionTile({
    required IconData icon,
    required String title,
    required bool isComplete,
    required String summary,
    required List<Widget> details,
  }) {
    final statusColor = isComplete ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final statusBg = isComplete ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isComplete ? AppTheme.borderSubtle : const Color(0xFFFDE68A),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: !isComplete,
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            leading: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: statusColor, size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            subtitle: Text(
              summary,
              style: TextStyle(
                fontSize: 11,
                color: isComplete ? AppTheme.textMuted : const Color(0xFFD97706),
              ),
            ),
            trailing: Icon(
              isComplete ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: statusColor,
              size: 20,
            ),
            children: details,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isOptional = false}) {
    final isFilled = value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isFilled ? Icons.check_rounded : (isOptional ? Icons.remove_rounded : Icons.close_rounded),
            size: 14,
            color: isFilled ? const Color(0xFF10B981) : (isOptional ? AppTheme.textMuted : const Color(0xFFEF4444)),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              isFilled ? value : (isOptional ? 'اختياري / فارغ' : 'غير محدد *'),
              style: TextStyle(
                fontSize: 12,
                color: isFilled ? AppTheme.textDark : (isOptional ? AppTheme.textMuted : const Color(0xFFEF4444)),
                fontWeight: isFilled ? FontWeight.normal : FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String status, {bool isGood = false, bool isWarning = false}) {
    Color color = AppTheme.textDark;
    if (isGood) color = const Color(0xFF10B981);
    if (isWarning) color = const Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_rounded : (isWarning ? Icons.priority_high_rounded : Icons.radio_button_unchecked_rounded),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          Text(
            status,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingFieldsAlert(List<String> missing) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'حقول هامة يوصى بإكمالها قبل التصدير:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...missing.map((m) => Padding(
            padding: const EdgeInsets.only(top: 3, right: 12),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 5, color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    m,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C)),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMiniBadge({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Fixed Bottom Action Bar
  Widget _buildBottomBar(BuildContext context, int percent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          if (onEditReport != null)
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text('تعديل التقرير'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  side: const BorderSide(color: AppTheme.borderMedium, width: 1.5),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onEditReport?.call();
                },
              ),
            ),
          if (onEditReport != null) const SizedBox(width: 12),
          Expanded(
            flex: onEditReport != null ? 2 : 1,
            child: FilledButton.icon(
              icon: const Icon(Icons.share_rounded, size: 20),
              label: Text(
                percent >= 90 ? 'تصدير ومشاركة التقرير' : 'متابعة التصدير على أية حال',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: percent >= 90 ? const Color(0xFF10B981) : AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                onExportNow();
              },
            ),
          ),
        ],
      ),
    );
  }
}
