/**
 * ══════════════════════════════════════════════════════════════
 *  Offline License Verifier (Zero-Trust RSA-256)
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  التحقق الأوفلاين الصارم بنسبة 100% من توقيع JWT وبصمة العتاد
 */

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/licensing_constants.dart';
import '../security/hardware_fingerprint.dart';
import '../security/time_tamper_engine.dart';
import '../security/public_key_pinning.dart';

enum RawVerificationStatus {
  valid,
  missingLicense,
  missingPublicKey,
  keyTampered,
  hwidMismatch,
  expired,
  timeTampered,
  signatureInvalid,
}

class RawVerificationResult {
  final RawVerificationStatus status;
  final String? message;
  final Map<String, dynamic>? payload;

  const RawVerificationResult({required this.status, this.message, this.payload});
  bool get isValid => status == RawVerificationStatus.valid;
}

class LicenseVerifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// التحقق الأوفلاين الشامل من الترخيص المحلي
  static Future<RawVerificationResult> verifyOffline() async {
    // 1. تدقيق التلاعب الزمني وسقف التوقيت العالي
    final isTimeValid = await TimeTamperEngine.isSystemClockValid();
    if (!isTimeValid) {
      return const RawVerificationResult(
        status: RawVerificationStatus.timeTampered,
        message: 'تم كشف تلاعب في ساعة الهاتف أو محاولة إرجاع التاريخ للخلف.',
      );
    }

    // 2. استخراج التوكن والمفتاح العام من التخزين العتادي المشفر
    final token = await _storage.read(key: LicensingConstants.keyJwtToken);
    var publicKeyPem = await _storage.read(key: LicensingConstants.keyPublicKey);
    if (publicKeyPem == null || publicKeyPem.isEmpty) {
      publicKeyPem = LicensingConstants.embeddedPublicKey;
      await _storage.write(key: LicensingConstants.keyPublicKey, value: publicKeyPem);
    }

    if (token == null || token.isEmpty) {
      return const RawVerificationResult(
        status: RawVerificationStatus.missingLicense,
        message: 'لا يوجد ترخيص مسجل على هذا الهاتف.',
      );
    }

    // 3. التحقق الصارم من تثبيت المفتاح العام (Public Key Pinning)
    if (!PublicKeyPinning.isAllowed(publicKeyPem)) {
      return const RawVerificationResult(
        status: RawVerificationStatus.keyTampered,
        message: 'تحذير أمني: المفتاح العام المحلي غير معتمد ومعدل.',
      );
    }

    try {
      // 4. التحقق من التوقيع الرقمي غير المتماثل RS256 بالمفتاح العام
      final normalizedKey = publicKeyPem.replaceAll('\r\n', '\n').trim();
      final rsaKey = RSAPublicKey(normalizedKey);
      final jwt = JWT.verify(token, rsaKey, checkHeaderType: false);
      final payload = jwt.payload as Map<String, dynamic>;

      // 5. فحص تطابق البصمة العتادية للهاتف (Node-Locking)
      final currentHwid = await HardwareFingerprint.getCompositeHwid();
      final tokenHwid = (payload['hardwareId'] ?? payload['hwid']) as String?;
      if (tokenHwid != null &&
          tokenHwid.trim().isNotEmpty &&
          tokenHwid.trim().toUpperCase() != currentHwid.trim().toUpperCase()) {
        return const RawVerificationResult(
          status: RawVerificationStatus.hwidMismatch,
          message: 'هذا الترخيص مخصص لهاتف آخر ولا يعمل على هذا الجهاز.',
        );
      }

      // 6. فحص تاريخ انتهاء الصلاحية
      if (payload['endDate'] != null) {
        final endDate = DateTime.parse(payload['endDate'] as String);
        final trustedNow = await TimeTamperEngine.getTrustedTime();
        if (trustedNow.isAfter(endDate)) {
          return RawVerificationResult(
            status: RawVerificationStatus.expired,
            message: 'انتهت صلاحية هذا الترخيص.',
            payload: payload,
          );
        }
      }

      return RawVerificationResult(
        status: RawVerificationStatus.valid,
        message: 'الترخيص صالح وموثق بنجاح.',
        payload: payload,
      );
    } on JWTExpiredException {
      final unverified = JWT.decode(token);
      return RawVerificationResult(
        status: RawVerificationStatus.expired,
        message: 'انتهت صلاحية الرمز الرقمي للترخيص.',
        payload: unverified.payload as Map<String, dynamic>,
      );
    } catch (_) {
      return const RawVerificationResult(
        status: RawVerificationStatus.signatureInvalid,
        message: 'توقيع الترخيص الرقمي غير صالح أو تالف.',
      );
    }
  }
}
