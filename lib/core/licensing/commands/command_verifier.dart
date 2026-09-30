/**
 * ══════════════════════════════════════════════════════════════
 *  Command Verifier (RS256 JWT Verification)
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  التحقق الأمني من توقيع الأوامر الواردة من السيرفر قبل التنفيذ
 *  حماية ضد هجمات الوسيط (MITM) وحقن الأوامر التخريبية
 */

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/licensing_constants.dart';
import 'command_types.dart';

class CommandVerifier {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// التحقق من صحة توقيع الأمر الوارد
  static Future<bool> verifyCommand(IncomingRemoteCommand command, {String? expectedLicenseId}) async {
    // إذا لم يكن الأمر يحمل توقيعاً رقمياً، يُرفض فوراً طبقاً لمعيار FIX-P0-3
    if (command.signature == null || command.signature!.isEmpty) {
      return false;
    }

    try {
      var publicKeyPem = await _storage.read(key: LicensingConstants.keyPublicKey);
      if (publicKeyPem == null || publicKeyPem.isEmpty) {
        publicKeyPem = LicensingConstants.embeddedPublicKey;
      }

      final normalizedKey = publicKeyPem.replaceAll('\r\n', '\n').trim();
      final rsaKey = RSAPublicKey(normalizedKey);

      // فك تشفير وتوثيق التوقيع الرقمي للأمر
      final jwt = JWT.verify(command.signature!, rsaKey, checkHeaderType: false);
      final payload = jwt.payload as Map<String, dynamic>;

      // التحقق من مطابقة معرّف الأمر (cid)
      if (payload['cid'] != command.id) {
        return false;
      }

      // التحقق من مطابقة نوع الأمر
      if (payload['command'] != command.command.name) {
        return false;
      }

      // التحقق من مطابقة معرّف الترخيص في حال توفره
      if (expectedLicenseId != null && payload['licenseId'] != null) {
        if (payload['licenseId'] != expectedLicenseId) {
          return false;
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
