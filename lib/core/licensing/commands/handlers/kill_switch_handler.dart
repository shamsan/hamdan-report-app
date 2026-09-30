/**
 * ══════════════════════════════════════════════════════════════
 *  KILL_SWITCH Command Handler
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  التنفيذ الفوري لقفل النظام ومحو توكن الترخيص عند إبطاله عن بُعد
 */

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/licensing_constants.dart';
import '../command_types.dart';
import '../command_event_bus.dart';

class KillSwitchHandler implements BaseCommandHandler {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  RemoteCommandType get commandType => RemoteCommandType.KILL_SWITCH;

  @override
  Future<CommandExecutionResult> execute(String commandId, Map<String, dynamic> payload) async {
    try {
      final reason = payload['reason'] as String? ?? 'تم إيقاف الترخيص عن بُعد من قبل الإدارة المركزية.';
      
      // 1. تسجيل سبب الإيقاف في الذاكرة المشفرة
      await _storage.write(key: LicensingConstants.keySuspensionReason, value: reason);

      // 2. إتلاف توكن الترخيص المحلي
      await _storage.delete(key: LicensingConstants.keyJwtToken);

      // 3. إشعار الواجهات بالقفل الفوري
      CommandEventBus().emit(ShowMessageUIEvent(
        title: 'تنبيه أمني عاجل',
        message: reason,
        type: 'critical',
        isDismissible: false,
      ));

      return CommandExecutionResult(
        commandId: commandId,
        success: true,
        message: 'تم تفعيل Kill Switch بنجاح ومحو الترخيص محلياً',
        executedAt: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      return CommandExecutionResult(
        commandId: commandId,
        success: false,
        message: 'خطأ أثناء تنفيذ Kill Switch: $e',
        executedAt: DateTime.now().toUtc().toIso8601String(),
      );
    }
  }
}
