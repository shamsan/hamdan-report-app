/**
 * ══════════════════════════════════════════════════════════════
 *  License WhatsApp Helper
 *  ReportCraft Enterprise Mobile Client
 * ══════════════════════════════════════════════════════════════
 *  تسهيل إرسال ومشاركة بصمة العتاد وبيانات الترخيص مع إدارة النظام عبر واتساب
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/licensing_constants.dart';
import '../security/hardware_fingerprint.dart';

class LicenseWhatsAppHelper {
  /// إنشاء نص الطلب ومشاركته عبر واتساب بنقرة واحدة
  static Future<void> shareViaWhatsApp(
    BuildContext context, {
    required String hwid,
    String? currentTier,
    String? currentKey,
    String? customNote,
  }) async {
    String deviceModel = 'هاتف ذكي';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceModel = '${android.brand.toUpperCase()} ${android.model} (Android ${android.version.release})';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceModel = '${ios.model} (${ios.systemName} ${ios.systemVersion})';
      }
    } catch (_) {}

    final buffer = StringBuffer();
    buffer.writeln('السلام عليكم ورحمة الله،');
    buffer.writeln('أود تفعيل / ترقية ترخيص تطبيق *ReportCraft* الهندسي لهذا الهاتف:');
    buffer.writeln('');
    buffer.writeln('📱 *بصمة الجهاز (HWID):*');
    buffer.writeln('`$hwid`');
    buffer.writeln('');
    buffer.writeln('🔹 *طراز الجهاز:* $deviceModel');
    if (currentTier != null && currentTier.isNotEmpty) {
      buffer.writeln('🔹 *الحالة الحالية:* $currentTier');
    }
    if (currentKey != null && currentKey.isNotEmpty) {
      buffer.writeln('🔑 *المفتاح السابق:* `$currentKey`');
    }
    if (customNote != null && customNote.isNotEmpty) {
      buffer.writeln('📝 *ملاحظات:* $customNote');
    }
    buffer.writeln('');
    buffer.writeln('أرجو التكرم بالاعتماد وتفعيل الترخيص.');

    final messageText = buffer.toString();
    final phone = LicensingConstants.supportWhatsAppNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final uriString = phone.isNotEmpty
        ? 'https://wa.me/$phone?text=${Uri.encodeComponent(messageText)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(messageText)}';

    final uri = Uri.parse(uriString);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw 'تعذر فتح تطبيق واتساب مباشرة';
      }
    } catch (_) {
      // في حال عدم توفر واتساب، نسخ النص إلى الحافظة
      await Clipboard.setData(ClipboardData(text: messageText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.content_copy_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('تم نسخ بيانات الترخيص والبصمة إلى الحافظة لمشاركتها يدوياً.'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF0B2545),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// فتح محادثة دعم واتساب مباشرة مع موضوع محدد وبصمة الجهاز تلقائياً
  static Future<void> openWhatsAppForSupport({
    required BuildContext context,
    String? subject,
  }) async {
    final hwid = await HardwareFingerprint.getCompositeHwid();
    if (context.mounted) {
      await shareViaWhatsApp(
        context,
        hwid: hwid,
        customNote: subject,
      );
    }
  }
}
