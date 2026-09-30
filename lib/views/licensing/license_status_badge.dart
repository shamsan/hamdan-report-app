/**
 * ══════════════════════════════════════════════════════════════
 *  License Status Badge & Information Sheet
 *  ReportCraft Enterprise Mobile Client
 * ══════════════════════════════════════════════════════════════
 *  شارة أيقونية ذكية مدمجة في الشريط العلوي تعبر عن نوع النسخة
 *  (تجريبية أو رسمية) وتفتح تفاصيل الترخيص بنافذة سفلية أنيقة
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/licensing/security/hardware_fingerprint.dart';
import '../../core/licensing/utils/license_whatsapp_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../state/licensing_provider.dart';
import 'license_activation_dialog.dart';

class LicenseStatusBadge extends ConsumerWidget {
  final bool showLabel;

  const LicenseStatusBadge({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licensingProvider);
    final isTrial = license.tier == 'TRIAL';
    final isPro = license.isUnlimitedReports || license.tier == 'PRO' || license.tier == 'ENTERPRISE';

    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;
    String badgeText;

    if (license.isLocked) {
      badgeColor = AppTheme.statusRejected;
      badgeBg = Colors.white.withValues(alpha: 0.15);
      badgeIcon = Icons.lock_clock_rounded;
      badgeText = 'منتهي';
    } else if (isPro) {
      badgeColor = const Color(0xFF10B981);
      badgeBg = Colors.white.withValues(alpha: 0.15);
      badgeIcon = Icons.verified_rounded;
      badgeText = 'رسمي';
    } else if (isTrial) {
      badgeColor = AppTheme.solarGold;
      badgeBg = Colors.white.withValues(alpha: 0.15);
      badgeIcon = Icons.hourglass_top_rounded;
      badgeText = '${license.daysLeft}ي';
    } else {
      badgeColor = Colors.white70;
      badgeBg = Colors.white.withValues(alpha: 0.15);
      badgeIcon = Icons.help_outline_rounded;
      badgeText = 'غير مفعل';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => const LicenseStatusBottomSheet(),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: badgeColor, size: 16),
                if (showLabel) ...[
                  const SizedBox(width: 5),
                  Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                      fontFamily: 'Almarai',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// نافذة التفاصيل السفلية عند نقر شارة الترخيص
class LicenseStatusBottomSheet extends ConsumerWidget {
  const LicenseStatusBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licensingProvider);
    final isTrial = license.tier == 'TRIAL';
    final isPro = license.isUnlimitedReports || license.tier == 'PRO' || license.tier == 'ENTERPRISE';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مقبض النافذة
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),

          // الرأس
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPro
                      ? AppTheme.statusGoodBg
                      : isTrial
                          ? AppTheme.statusFollowupBg
                          : AppTheme.statusRejectedBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPro
                      ? Icons.verified_rounded
                      : isTrial
                          ? Icons.hourglass_top_rounded
                          : Icons.lock_outline_rounded,
                  color: isPro
                      ? AppTheme.statusGood
                      : isTrial
                          ? AppTheme.solarGold
                          : AppTheme.statusRejected,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro
                          ? 'نسخة رسمية معتمدة (PRO)'
                          : isTrial
                              ? 'نسخة تجريبية نشطة (TRIAL)'
                              : 'الترخيص مقفل أو غير مسجل',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                        fontFamily: 'Almarai',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isPro
                          ? 'تقارير غير محدودة (∞) • ترخيص مؤسسي'
                          : isTrial
                              ? 'متبقي ${license.daysLeft} يوماً • استهلاك التقارير ${license.reportsUsed}/${license.maxReports}'
                              : 'يرجى تفعيل ترخيص صالح لمتابعة العمل',
                      style: TextStyle(
                        fontSize: 12,
                        color: isPro ? AppTheme.statusGood : AppTheme.textMuted,
                        fontFamily: 'Almarai',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // كارت التفاصيل والأشرطة
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                if (isTrial) ...[
                  _buildProgressRow(
                    label: 'الأيام المتبقية في التجربة:',
                    valueText: '${license.daysLeft} من أصل ${license.totalTrialDays} يوماً',
                    ratio: license.totalTrialDays > 0
                        ? (license.daysLeft / license.totalTrialDays).clamp(0.0, 1.0)
                        : 0.0,
                    progressColor: AppTheme.solarGold,
                  ),
                  const Divider(height: 20),
                  _buildProgressRow(
                    label: 'التقارير المنجزة:',
                    valueText: '${license.reportsUsed} من أصل ${license.maxReports} تقريراً',
                    ratio: license.maxReports > 0
                        ? (license.reportsUsed / license.maxReports).clamp(0.0, 1.0)
                        : 0.0,
                    progressColor: AppTheme.primaryNavy,
                  ),
                  const Divider(height: 20),
                ],
                // معلومات معرّف الجهاز
                FutureBuilder<String>(
                  future: HardwareFingerprint.getCompositeHwid(),
                  builder: (context, snapshot) {
                    final hwid = snapshot.data ?? 'جاري التحميل...';
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'معرّف الهاتف (HWID):',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontFamily: 'Almarai'),
                        ),
                        InkWell(
                          onTap: () {
                            if (snapshot.hasData) {
                              Clipboard.setData(ClipboardData(text: hwid));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم نسخ معرّف الهاتف للحافظة'), duration: Duration(seconds: 1)),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              Text(
                                hwid.length > 12 ? '${hwid.substring(0, 10)}...' : hwid,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy_rounded, size: 14, color: AppTheme.primaryNavy),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // أزرار الإجراءات
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: Text(
                    isPro ? 'إدارة الترخيص' : 'تفعيل ترخيص رسمي',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => const LicenseActivationDialog(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text(
                  'واتساب الإدارة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  LicenseWhatsAppHelper.openWhatsAppForSupport(
                    context: context,
                    subject: isTrial ? 'طلب ترقية ترخيص تجريبي' : 'استفسار عن الترخيص',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required String valueText,
    required double ratio,
    required Color progressColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontFamily: 'Almarai')),
            Text(valueText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: progressColor, fontFamily: 'Almarai')),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: progressColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
