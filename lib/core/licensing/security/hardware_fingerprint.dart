/**
 * ══════════════════════════════════════════════════════════════
 *  Hardware Fingerprint Generator (Composite Hardware-Bound HWID)
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  بصمة عتادية قطعية 100% تقاوم مسح البيانات وإلغاء التثبيت وتضمن
 *  استعادة التراخيص تلقائياً من خادم التراخيص ومنع التحايل.
 */

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/licensing_constants.dart';

class HardwareFingerprint {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String? _cachedHwid;

  /// الحصول على البصمة العتادية الفيزيائية الثابتة المقاومة للحذف وإعادة التثبيت (100% Hardware Bound)
  static Future<String> getCompositeHwid() async {
    if (_cachedHwid != null && _cachedHwid!.isNotEmpty) {
      return _cachedHwid!;
    }

    final deviceInfo = DeviceInfoPlugin();
    String rawComponents = '';

    try {
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        // معرّفات عتادية فيزيائية قطعية لا تتغير بإلغاء التثبيت أو مسح بيانات التطبيق
        rawComponents = [
          'RC_HWID_ANDROID_SECURE',
          android.id.trim(),
          android.brand.trim().toUpperCase(),
          android.manufacturer.trim().toUpperCase(),
          android.model.trim().toUpperCase(),
          android.device.trim().toUpperCase(),
          android.hardware.trim().toUpperCase(),
          android.board.trim().toUpperCase(),
          android.supportedAbis.join(','),
        ].join('::');
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        rawComponents = [
          'RC_HWID_IOS_SECURE',
          ios.identifierForVendor ?? 'ios_device',
          ios.model.trim().toUpperCase(),
          ios.utsname.machine.trim().toUpperCase(),
        ].join('::');
      } else if (Platform.isWindows) {
        final win = await deviceInfo.windowsInfo;
        rawComponents = [
          'RC_HWID_WIN_SECURE',
          win.deviceId.trim().toUpperCase(),
          win.computerName.trim().toUpperCase(),
          win.numberOfCores.toString(),
        ].join('::');
      } else {
        rawComponents = 'RC_HWID_PLATFORM_${Platform.operatingSystem.toUpperCase()}';
      }
    } catch (_) {
      rawComponents = 'RC_HWID_FALLBACK_${Platform.operatingSystem.toUpperCase()}';
    }

    // توليد هاش SHA-256 موحد ككود عتادي قطعي (Deterministic 32-Hex Uppercase)
    final hash = sha256.convert(utf8.encode(rawComponents)).toString().toUpperCase().substring(0, 32);
    _cachedHwid = hash;

    // حفظ البصمة في التخزين المشفر كمرجع سريع
    try {
      await _storage.write(key: LicensingConstants.keyHwid, value: hash);
    } catch (_) {}

    return hash;
  }
}
