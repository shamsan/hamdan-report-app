/**
 * ══════════════════════════════════════════════════════════════
 *  Trial Status Bar & License Indicator Widget (Fully Responsive)
 *  ReportCraft Enterprise Mobile UI
 * ══════════════════════════════════════════════════════════════
 *  شريط حالة ومؤشرات النسخة التجريبية المزدوجة المتوافق مع جميع مقاسات الشاشات
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../state/licensing_provider.dart';
import 'license_activation_dialog.dart';
import 'pending_request_banner.dart';

class TrialStatusBar extends ConsumerWidget {
  const TrialStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licensingProvider);

    // إذا كان الترخيص مقفلاً، تظهر شاشة القفل الرئيسية بدلاً من هذا الشريط
    if (license.isLocked) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── 1. شريط متابعة الطلب المعلق إن وُجد ───
        const PendingRequestBanner(isDark: false),

        // ─── 2. شريط حالة الترخيص الرئيسي ───
        if (license.isUnlimitedReports)
          _buildUnlimitedProCard(context, license)
        else
          _buildTrialCard(context, license),
      ],
    );
  }

  Widget _buildUnlimitedProCard(BuildContext context, dynamic license) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'النسخة الاحترافية (${license.tier}) — تقارير غير محدودة (∞)',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF166534),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (license.endDate != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'متبقي ${license.daysLeft} يوماً',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF15803D),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrialCard(BuildContext context, dynamic license) {
    // حساب نسب التقدم بدقة وأمان
    final double daysRatio = license.totalTrialDays > 0
        ? (license.daysLeft / license.totalTrialDays).clamp(0.0, 1.0)
        : 0.0;
    final double reportsRatio = license.maxReports > 0
        ? (license.reportsUsed / license.maxReports).clamp(0.0, 1.0)
        : 0.0;

    final bool isNearExpiry = license.daysLeft <= 7 || license.reportsLeft <= 3;
    final Color accentColor = isNearExpiry ? AppTheme.statusFollowup : AppTheme.brandCyan;
    final Color bgColor = isNearExpiry ? const Color(0xFFFFFBEB) : const Color(0xFFF0F9FF);
    final Color borderColor = isNearExpiry ? const Color(0xFFFDE68A) : const Color(0xFFBAE6FD);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header: العنوان والشارة وزر الترقية ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    isNearExpiry ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded,
                    color: accentColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'النسخة التجريبية (TRIAL)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const LicenseActivationDialog(),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium, color: Colors.amber, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'ترقية',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ─── المقياس الأول: الأيام المتبقية ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isNarrow
                          ? 'المهلة:'
                          : (license.endDate != null
                              ? 'المهلة (حتى ${_formatDate(license.endDate)}):'
                              : 'المهلة الزمنية:'),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'متبقي ${license.daysLeft} يوماً',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: license.daysLeft <= 7 ? AppTheme.statusRejected : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: daysRatio,
                  minHeight: 5,
                  backgroundColor: Colors.black.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    license.daysLeft <= 7 ? AppTheme.statusFollowup : AppTheme.brandCyan,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ─── المقياس الثاني: حصة التقارير ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isNarrow ? 'التقارير:' : 'سقف التقارير المسموحة (${license.maxReports}):',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    isNarrow
                        ? '${license.reportsUsed}/${license.maxReports} (باقي ${license.reportsLeft})'
                        : 'مستهلك ${license.reportsUsed} من ${license.maxReports} (متبقي ${license.reportsLeft})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: license.reportsLeft <= 3 ? AppTheme.statusRejected : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: reportsRatio,
                  minHeight: 5,
                  backgroundColor: Colors.black.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    license.reportsLeft <= 3 ? AppTheme.statusRejected : const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}
