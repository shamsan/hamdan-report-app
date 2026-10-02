/**
 * ══════════════════════════════════════════════════════════════
 *  License Guard — Dual-Constraint Evaluator
 *  ReportCraft Enterprise Business Logic
 * ══════════════════════════════════════════════════════════════
 *  تطبيق شرط القفل المزدوج للتجربة (60 يوماً / 15 تقريراً)
 *  وفتح التقارير غير المحدودة لنسخ PRO و ENTERPRISE
 */

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/licensing_constants.dart';
import '../security/secure_quota_store.dart';
import '../security/time_tamper_engine.dart';
import 'license_models.dart';
import 'license_verifier.dart';

class LicenseGuard {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// خطاف محاكاة الترخيص لأغراض الاختبارات الآلية فقط
  @visibleForTesting
  static LicenseInfo? mockLicenseForTesting;

  /// تقييم حالة الترخيص بدقة استناداً إلى القيد المزدوج
  static Future<LicenseInfo> evaluateLicense(int existingReportsCount) async {
    if (mockLicenseForTesting != null) {
      return mockLicenseForTesting!;
    }
    // 1. حساب عدد التقارير الفعلي المحمي عتادياً
    final effectiveReportsUsed = await SecureQuotaStore.getEffectiveReportsCount(existingReportsCount);

    // 2. فحص هل هناك رسالة إيقاف تعليق سابقة (Revocation Message)
    final suspensionReason = await _storage.read(key: LicensingConstants.keySuspensionReason);

    // 3. التحقق الأوفلاين الصارم
    final rawResult = await LicenseVerifier.verifyOffline();

    if (!rawResult.isValid) {
      if (rawResult.status == RawVerificationStatus.missingLicense) {
        return LicenseInfo(
          status: LicenseStatus.locked,
          lockReason: suspensionReason != null 
              ? LicenseLockReason.revoked 
              : LicenseLockReason.notRegistered,
          tier: 'NONE',
          daysLeft: 0,
          reportsUsed: effectiveReportsUsed,
          reportsLeft: 0,
          maxReports: LicensingConstants.trialMaxReports,
          isUnlimitedReports: false,
          suspensionReason: suspensionReason,
          message: suspensionReason != null
              ? 'تم إيقاف الترخيص مركزياً: $suspensionReason'
              : 'التطبيق غير مفعل. يرجى بدء الفترة التجريبية أو تفعيل الترخيص.',
        );
      }

      if (rawResult.status == RawVerificationStatus.timeTampered) {
        return LicenseInfo(
          status: LicenseStatus.locked,
          lockReason: LicenseLockReason.timeTampered,
          tier: 'LOCKED',
          daysLeft: 0,
          reportsUsed: effectiveReportsUsed,
          reportsLeft: 0,
          maxReports: LicensingConstants.trialMaxReports,
          isUnlimitedReports: false,
          message: 'تم كشف تراجع ساعة الهاتف للخلف. أعد ضبط الوقت الصحيح لمواصلة العمل.',
        );
      }

      if (rawResult.status == RawVerificationStatus.hwidMismatch) {
        return LicenseInfo(
          status: LicenseStatus.locked,
          lockReason: LicenseLockReason.hwidMismatch,
          tier: 'LOCKED',
          daysLeft: 0,
          reportsUsed: effectiveReportsUsed,
          reportsLeft: 0,
          maxReports: LicensingConstants.trialMaxReports,
          isUnlimitedReports: false,
          message: 'هذا الترخيص مخصص لهاتف آخر ولا يعمل على هذا الجهاز.',
        );
      }

      return LicenseInfo(
        status: LicenseStatus.locked,
        lockReason: LicenseLockReason.signatureInvalid,
        tier: 'INVALID',
        daysLeft: 0,
        reportsUsed: effectiveReportsUsed,
        reportsLeft: 0,
        maxReports: LicensingConstants.trialMaxReports,
        isUnlimitedReports: false,
        message: rawResult.message ?? 'رمز الترخيص غير صالح. يرجى إعادة التفعيل.',
      );
    }

    final payload = rawResult.payload!;
    final tier = (payload['tier'] as String?)?.toUpperCase() ?? 'TRIAL';
    final licenseKey = payload['key'] as String?;
    final endDateStr = payload['endDate'] as String?;
    final endDate = endDateStr != null ? DateTime.parse(endDateStr) : DateTime.now();
    final trustedNow = await TimeTamperEngine.getTrustedTime();
    final daysLeft = endDate.difference(trustedNow).inDays.clamp(0, 9999);

    // ─── أ. النسخ المدفوعة (PRO أو ENTERPRISE): تقارير مفتوحة دون سقف ───
    if (tier == 'PRO' || tier == 'ENTERPRISE') {
      final isExpired = trustedNow.isAfter(endDate);
      if (isExpired) {
        return LicenseInfo(
          status: LicenseStatus.locked,
          lockReason: LicenseLockReason.paidExpired,
          tier: tier,
          licenseKey: licenseKey,
          daysLeft: 0,
          reportsUsed: effectiveReportsUsed,
          reportsLeft: 999999,
          maxReports: 0,
          isUnlimitedReports: true,
          endDate: endDate,
          message: 'انتهت فترة اشتراكك المدفوع في $tier. يرجى تجديد الترخيص.',
        );
      }

      return LicenseInfo(
        status: LicenseStatus.activeUnlimited,
        lockReason: LicenseLockReason.none,
        tier: tier,
        licenseKey: licenseKey,
        daysLeft: daysLeft,
        reportsUsed: effectiveReportsUsed,
        reportsLeft: 999999, // مفتوح بلا حدود
        maxReports: 0,
        isUnlimitedReports: true,
        endDate: endDate,
        message: 'الترخيص الاحترافي فعال (تقارير غير محدودة ∞).',
      );
    }

    // ─── ب. النسخة التجريبية (TRIAL): القاعدة المزدوجة (60 يوماً أو 15 تقريراً) ───
    final isTimeExpired = trustedNow.isAfter(endDate);
    final isQuotaExceeded = effectiveReportsUsed >= LicensingConstants.trialMaxReports;

    // أيهما ينتهي أولاً يُقفل التطبيق فوراً
    if (isTimeExpired) {
      return LicenseInfo(
        status: LicenseStatus.locked,
        lockReason: LicenseLockReason.trialTimeExpired,
        tier: 'TRIAL',
        licenseKey: licenseKey,
        daysLeft: 0,
        totalTrialDays: LicensingConstants.trialDurationDays,
        reportsUsed: effectiveReportsUsed,
        reportsLeft: 0,
        maxReports: LicensingConstants.trialMaxReports,
        isUnlimitedReports: false,
        endDate: endDate,
        message: 'انتهت مهلة الـ ${LicensingConstants.trialDurationDays} يوماً التجريبية (تم إنجاز $effectiveReportsUsed تقريراً من أصل ${LicensingConstants.trialMaxReports}). يرجى شراء ترخيص لمواصلة العمل.',
      );
    }

    if (isQuotaExceeded) {
      return LicenseInfo(
        status: LicenseStatus.locked,
        lockReason: LicenseLockReason.trialQuotaExceeded,
        tier: 'TRIAL',
        licenseKey: licenseKey,
        daysLeft: daysLeft,
        totalTrialDays: LicensingConstants.trialDurationDays,
        reportsUsed: effectiveReportsUsed,
        reportsLeft: 0,
        maxReports: LicensingConstants.trialMaxReports,
        isUnlimitedReports: false,
        endDate: endDate,
        message: 'تم استهلاك الحد الأقصى للتجربة (${LicensingConstants.trialMaxReports} تقريراً) خلال $daysLeft يوماً متبقية. يرجى الترقية إلى النسخة المدفوعة.',
      );
    }

    // لا يزال ضمن المهلة ولديه تقارير متبقية
    final reportsLeft = LicensingConstants.trialMaxReports - effectiveReportsUsed;
    return LicenseInfo(
      status: LicenseStatus.activeTrial,
      lockReason: LicenseLockReason.none,
      tier: 'TRIAL',
      licenseKey: licenseKey,
      daysLeft: daysLeft,
      totalTrialDays: LicensingConstants.trialDurationDays,
      reportsUsed: effectiveReportsUsed,
      reportsLeft: reportsLeft,
      maxReports: LicensingConstants.trialMaxReports,
      isUnlimitedReports: false,
      endDate: endDate,
      message: 'النسخة التجريبية: متبقي $daysLeft يوماً و $reportsLeft تقارير.',
    );
  }
}
