/**
 * ══════════════════════════════════════════════════════════════
 *  License State Models & Definitions
 *  ReportCraft Enterprise Mobile Client
 * ══════════════════════════════════════════════════════════════
 */

enum LicenseLockReason {
  none,
  trialTimeExpired,      // انتهت مهلة الـ 60 يوماً للتجربة
  trialQuotaExceeded,    // تم استهلاك الـ 15 تقريراً كاملة
  paidExpired,           // انتهى اشتراك PRO أو ENTERPRISE
  revoked,               // تم إيقاف الترخيص مركزياً من لوحة التحكم (Revoke)
  timeTampered,          // تم اكتشاف تلاعب بساعة الجهاز وتأخير التاريخ
  hwidMismatch,          // الترخيص مخصص لجهاز آخر ولا يطابق هذا العتاد
  signatureInvalid,      // توقيع الترخيص الرقمي مزور أو غير صالح
  notRegistered,         // لم يتم طلب تجربة أو تفعيل ترخيص بعد
}

enum LicenseStatus {
  activeUnlimited,       // نسخة مدفوعة PRO / ENTERPRISE (تقارير غير محدودة ∞)
  activeTrial,           // نسخة تجريبية فعالة (أقل من 60 يوماً وأقل من 15 تقريراً)
  locked,                // التطبيق مقفل ويطلب ترخيصاً
}

class LicenseInfo {
  final LicenseStatus status;
  final LicenseLockReason lockReason;
  final String tier;                // 'TRIAL', 'PRO', 'ENTERPRISE', 'NONE'
  final String? licenseKey;
  final int daysLeft;              // الأيام المتبقية
  final int totalTrialDays;         // 60 يوماً
  final int reportsUsed;            // عدد التقارير المستهلكة
  final int reportsLeft;            // عدد التقارير المتبقية (في التجربة)
  final int maxReports;             // 15 في التجربة، 0 في PRO
  final bool isUnlimitedReports;    // true في PRO و ENTERPRISE
  final String? message;            // رسالة التوضيح للمستخدم
  final String? suspensionReason;   // سبب الإيقاف القادم من السيرفر (عند Revoke)
  final DateTime? endDate;

  const LicenseInfo({
    required this.status,
    required this.lockReason,
    required this.tier,
    this.licenseKey,
    required this.daysLeft,
    this.totalTrialDays = 60,
    required this.reportsUsed,
    required this.reportsLeft,
    required this.maxReports,
    required this.isUnlimitedReports,
    this.message,
    this.suspensionReason,
    this.endDate,
  });

  bool get isLocked => status == LicenseStatus.locked;
  bool get canCreateReport => !isLocked;

  /// النسبة المئوية لاستهلاك التقارير في التجربة (0.0 إلى 1.0)
  double get quotaProgress => isUnlimitedReports || maxReports == 0 
      ? 0.0 
      : (reportsUsed / maxReports).clamp(0.0, 1.0);

  /// النسبة المئوية لاستهلاك الأيام في التجربة (0.0 إلى 1.0)
  double get daysProgress {
    if (isUnlimitedReports || totalTrialDays == 0) return 0.0;
    final daysUsed = totalTrialDays - daysLeft;
    return (daysUsed / totalTrialDays).clamp(0.0, 1.0);
  }
}
