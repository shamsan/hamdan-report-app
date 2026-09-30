/**
 * ══════════════════════════════════════════════════════════════
 *  Time Tamper Engine — Anti-Clock Rollback & Tri-Anchor System
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  مكافحة التلاعب بزمن الهاتف عبر الأقمار الصناعية وسقف التوقيت العالي
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../config/licensing_constants.dart';

class TimeTamperEngine {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _saltSecret = 'RC_TIME_PROTECTION_HMAC_SALT_2026';
  static const String _sigKey = 'rc_watermark_hmac_signature_v1';

  /// فحص هل تم التلاعب بساعة الهاتف وتأخيرها للخلف (Clock Rollback)
  static Future<bool> isSystemClockValid() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final watermarkStr = await _storage.read(key: LicensingConstants.keyHighWatermark);
    final sigStr = await _storage.read(key: _sigKey);

    if (watermarkStr != null && sigStr != null) {
      // 1. التحقق من توقيع سقف التوقيت العالي السابق
      final expectedSig = _generateHmac(watermarkStr);
      if (sigStr != expectedSig) {
        return false; // تلاعب بملف الختم الزمني
      }

      final highWatermark = int.tryParse(watermarkStr) ?? 0;

      // 2. إذا كانت ساعة الهاتف الحالية أقل من أعلى تاريخ حقيقي مر بنا سابقاً
      if (nowMs < highWatermark) {
        // تم كشف إرجاع تاريخ الهاتف للخلف (CLOCK_ROLLBACK)
        return false;
      }
    }

    // 3. تحديث سقف التوقيت العالي بالطابع الجديد
    await _updateHighWatermark(nowMs);
    return true;
  }

  /// الحصول على التوقيت الموثوق (Trusted Current Time)
  static Future<DateTime> getTrustedTime() async {
    final now = DateTime.now();
    await _updateHighWatermark(now.millisecondsSinceEpoch);
    return now;
  }

  /// معايرة الوقت من الأقمار الصناعية لنظام تحديد المواقع GPS (أوفلاين بدون إنترنت)
  static Future<void> calibrateFromGps() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 4),
      );

      final gpsTimeMs = position.timestamp.millisecondsSinceEpoch;
      await _updateHighWatermark(gpsTimeMs);
    } catch (_) {
      // عدم توفر GPS لا يعطل التطبيق بل يعتمد على السقف العالي
    }
  }

  /// معايرة الوقت من استجابة خادم التراخيص الرسمي
  static Future<void> calibrateFromServer(int serverUtcMs) async {
    if (serverUtcMs > 0) {
      await _updateHighWatermark(serverUtcMs);
    }
  }

  static Future<void> _updateHighWatermark(int timestampMs) async {
    final watermarkStr = await _storage.read(key: LicensingConstants.keyHighWatermark);
    final currentMax = int.tryParse(watermarkStr ?? '0') ?? 0;

    // لا يُسجل إلا القيمة الأكبر تصاعدياً فقط
    if (timestampMs > currentMax) {
      final strVal = timestampMs.toString();
      final sig = _generateHmac(strVal);
      await _storage.write(key: LicensingConstants.keyHighWatermark, value: strVal);
      await _storage.write(key: _sigKey, value: sig);
    }
  }

  static String _generateHmac(String value) {
    final hmac = Hmac(sha256, utf8.encode(_saltSecret));
    return hmac.convert(utf8.encode(value)).toString();
  }
}
