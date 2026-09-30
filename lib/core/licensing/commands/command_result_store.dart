/**
 * ══════════════════════════════════════════════════════════════
 *  Command Result & ACK Store
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  مستودع النتائج والتأكيدات لضمان تسليم الأوامر ومنع التكرار (Idempotency)
 */

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/licensing_constants.dart';
import 'command_types.dart';

class CommandResultStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// التحقق هل تم تنفيذ هذا الأمر مسبقاً لمنع هجمات إعادة الإرسال (Replay Attacks)
  static Future<bool> isCommandAlreadyExecuted(String commandId) async {
    try {
      final raw = await _storage.read(key: LicensingConstants.keyExecutedCmdIds);
      if (raw == null || raw.isEmpty) return false;
      final List<dynamic> list = jsonDecode(raw);
      return list.contains(commandId);
    } catch (_) {
      return false;
    }
  }

  /// تسجيل نتيجة تنفيذ الأمر وحفظ المعرّف
  static Future<void> recordExecution(CommandExecutionResult result) async {
    try {
      // 1. إضافة المعرّف إلى قائمة الأوامر المنفذة
      final rawExecuted = await _storage.read(key: LicensingConstants.keyExecutedCmdIds);
      List<String> executedIds = [];
      if (rawExecuted != null && rawExecuted.isNotEmpty) {
        executedIds = List<String>.from(jsonDecode(rawExecuted));
      }
      if (!executedIds.contains(result.commandId)) {
        executedIds.add(result.commandId);
        // الاحتفاظ بآخر 100 أمر فقط لتوفير المساحة
        if (executedIds.length > 100) {
          executedIds = executedIds.sublist(executedIds.length - 100);
        }
        await _storage.write(
          key: LicensingConstants.keyExecutedCmdIds,
          value: jsonEncode(executedIds),
        );
      }

      // 2. حفظ النتيجة في قائمة النتائج المعلقة (Pending ACKs) لإرسالها للخادم
      final rawPending = await _storage.read(key: LicensingConstants.keyPendingCmdAcks);
      List<Map<String, dynamic>> pending = [];
      if (rawPending != null && rawPending.isNotEmpty) {
        pending = List<Map<String, dynamic>>.from(jsonDecode(rawPending));
      }

      // استبدال النتيجة إن كانت موجودة مسبقاً لنفس الأمر أو إضافتها
      pending.removeWhere((item) => item['commandId'] == result.commandId);
      pending.add(result.toJson());

      await _storage.write(
        key: LicensingConstants.keyPendingCmdAcks,
        value: jsonEncode(pending),
      );
    } catch (_) {}
  }

  /// استرجاع النتائج المعلقة لإرسالها في المزامنة التالية مع الخادم
  static Future<List<Map<String, dynamic>>> getPendingResults() async {
    try {
      final rawPending = await _storage.read(key: LicensingConstants.keyPendingCmdAcks);
      if (rawPending == null || rawPending.isEmpty) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(rawPending));
    } catch (_) {
      return [];
    }
  }

  /// تنظيف وتأكيد استلام الخادم للنتائج بعد نجاح المزامنة
  static Future<void> clearDeliveredResults(List<String> deliveredCommandIds) async {
    try {
      final rawPending = await _storage.read(key: LicensingConstants.keyPendingCmdAcks);
      if (rawPending == null || rawPending.isEmpty) return;
      List<Map<String, dynamic>> pending = List<Map<String, dynamic>>.from(jsonDecode(rawPending));

      pending.removeWhere((item) => deliveredCommandIds.contains(item['commandId']));

      await _storage.write(
        key: LicensingConstants.keyPendingCmdAcks,
        value: jsonEncode(pending),
      );
    } catch (_) {}
  }
}
