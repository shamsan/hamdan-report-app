/**
 * ══════════════════════════════════════════════════════════════
 *  Public Key Pinning Verifier
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  تثبيت هاش المفتاح العام لمنع استبداله بمفاتيح مقرصنة محلياً
 */

import 'dart:convert';
import 'package:crypto/crypto.dart';

class PublicKeyPinning {
  /// قائمة البصمات المشفرة المعتمدة للمفتاح العام للمنتج (SHA-256)
  /// تدعم مفاتيح متعددة لتسهيل عملية تدوير المفاتيح (Key Rotation)
  static const List<String> pinnedHashes = [
    'sha256:1fa8b997d7c739ca3cd26f37321a37daeea4bc5805c53ba550e63f1d79de892e',
  ];

  /// التحقق من أن المفتاح العام المعطى يطابق البصمات المثبتة
  static bool isAllowed(String publicKeyPem) {
    if (publicKeyPem.isEmpty) return false;

    // توحيد نهايات الأسطر (CRLF -> LF) وإزالة الفراغات
    final normalized = publicKeyPem.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final actualHash = 'sha256:${sha256.convert(utf8.encode(normalized))}';

    // إذا لم تكن هناك بصمات محددة (في مرحلة التطوير فقط)
    if (pinnedHashes.isEmpty) {
      return true; // وضع التطوير
    }

    return pinnedHashes.contains(actualHash);
  }

  /// حساب بصمة أي مفتاح عام للمطابقة والتشخيص
  static String calculateHash(String publicKeyPem) {
    final normalized = publicKeyPem.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    return 'sha256:${sha256.convert(utf8.encode(normalized))}';
  }
}
