/**
 * ══════════════════════════════════════════════════════════════
 *  Secure Quota Store — Anti-Bypass & Anti-Recycling Engine
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  حماية عداد الـ 15 تقريراً ضد حيل حذف التقارير وإعادة تدويرها
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/licensing_constants.dart';

class SecureQuotaStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _sigKey = 'rc_quota_hmac_sig_v1';
  static const String _secretKey = 'REPORT_CRAFT_SECURE_QUOTA_SALT_2026';

  /// استرجاع عدد التقارير الفعلي التراكمي المحمي عتادياً
  /// القيمة لا تنقص أبداً حتى لو حذف المستخدم جميع التقارير المحلية!
  static Future<int> getEffectiveReportsCount(int currentExistingReportsCount) async {
    final rawCountStr = await _storage.read(key: LicensingConstants.keyLifetimeCount);
    final rawSig      = await _storage.read(key: _sigKey);

    int secureCount = 0;
    if (rawCountStr != null && rawSig != null) {
      if (_verifySignature(rawCountStr, rawSig)) {
        secureCount = int.tryParse(rawCountStr) ?? 0;
      } else {
        // تم كشف تلاعب بمحتوى العداد في ملف التخزين -> فرض سقف الحظر فوراً
        return 999;
      }
    }

    // القيمة الحقيقية هي الأكبر بين العداد التراكمي وعدد التقارير الموجودة فعلياً
    final effective = secureCount > currentExistingReportsCount ? secureCount : currentExistingReportsCount;
    return effective;
  }

  /// زيادة العداد التراكمي عند إنشاء تقرير جديد من قالب
  static Future<void> recordNewReportCreation([int currentExistingReportsCount = 0]) async {
    final current = await getEffectiveReportsCount(currentExistingReportsCount);
    final newCount = current + 1;
    await _saveCount(newCount);
  }

  /// حماية سيناريو إعادة التدوير (In-place Report Recycling):
  /// إذا قام المهندس بتعديل بيانات نفس التقرير القديم وتصديره لعميل آخر،
  /// يتم احتسابه كتقرير مستهلك جديد ويُخصم من رصيد الـ 15 تقريراً!
  static Future<bool> trackPdfExportEvent({
    required String reportId,
    required String facilityName,
    required String visitDate,
    int currentExistingReportsCount = 0,
  }) async {
    // 1. حساب بصمة محتوى التقرير المُصدَّر
    final contentRaw = '${reportId.trim()}|${facilityName.trim().toLowerCase()}|${visitDate.trim()}';
    final contentHash = sha256.convert(utf8.encode(contentRaw)).toString().substring(0, 20);

    // 2. قراءة سجل بصمات التقارير المصدرة مسبقاً
    final rawHashes = await _storage.read(key: LicensingConstants.keyExportHashes);
    List<dynamic> exportedList = [];
    if (rawHashes != null && rawHashes.isNotEmpty) {
      try {
        exportedList = jsonDecode(rawHashes);
      } catch (_) {
        exportedList = [];
      }
    }

    // 3. هل تم تصدير هذا المحتوى المحدد من قبل؟
    if (!exportedList.contains(contentHash)) {
      // محتوى جديد يُصدر لأول مرة -> تسجيله وخصم تقرير من الحصة فوراً
      exportedList.add(contentHash);
      if (exportedList.length > 200) exportedList.removeAt(0); // حفظ آخر 200 بصمة
      await _storage.write(key: LicensingConstants.keyExportHashes, value: jsonEncode(exportedList));

      // زيادة العداد التراكمي
      await recordNewReportCreation(currentExistingReportsCount);
      return true; // تقرير جديد تم احتسابه
    }

    return false; // إعادة تصدير لنفس التقرير المعتمد سابقاً دون تغيير جوهري
  }

  static Future<void> _saveCount(int count) async {
    final str = count.toString();
    final sig = _generateSignature(str);
    await _storage.write(key: LicensingConstants.keyLifetimeCount, value: str);
    await _storage.write(key: _sigKey, value: sig);
  }

  static String _generateSignature(String value) {
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    return hmac.convert(utf8.encode(value)).toString();
  }

  static bool _verifySignature(String value, String signature) {
    return _generateSignature(value) == signature;
  }
}
