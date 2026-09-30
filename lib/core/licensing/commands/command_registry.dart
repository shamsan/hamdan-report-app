/**
 * ══════════════════════════════════════════════════════════════
 *  Command Registry & Dispatcher
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  تسجيل معالجات الأوامر وفحص التواقيع وتوزيع التنفيذ بأمان مطلق
 */

import 'command_types.dart';
import 'command_verifier.dart';
import 'command_result_store.dart';
import 'handlers/show_message_handler.dart';
import 'handlers/clear_cache_handler.dart';
import 'handlers/kill_switch_handler.dart';
import 'handlers/maintenance_handler.dart';
import 'handlers/update_and_backup_handlers.dart';

class CommandRegistry {
  static final CommandRegistry _instance = CommandRegistry._internal();
  factory CommandRegistry() => _instance;

  final Map<RemoteCommandType, BaseCommandHandler> _handlers = {};

  CommandRegistry._internal() {
    // تسجيل المعالجات القياسية
    registerHandler(ShowMessageHandler());
    registerHandler(ClearCacheHandler());
    registerHandler(KillSwitchHandler());
    registerHandler(MaintenanceHandler());
    registerHandler(ForceUpdateHandler());
    registerHandler(BackupNowHandler());
  }

  void registerHandler(BaseCommandHandler handler) {
    _handlers[handler.commandType] = handler;
  }

  /// استلام قائمة الأوامر من الخادم والتحقق منها وتنفيذها
  Future<void> dispatchCommands(
    List<IncomingRemoteCommand> commands, {
    String? expectedLicenseId,
  }) async {
    for (final cmd in commands) {
      // 1. فحص عدم التكرار (Idempotency)
      final alreadyExecuted = await CommandResultStore.isCommandAlreadyExecuted(cmd.id);
      if (alreadyExecuted) {
        continue;
      }

      // 2. التحقق من التوقيع الرقمي الصارم (RS256 Signature Verification)
      final isSignatureValid = await CommandVerifier.verifyCommand(
        cmd,
        expectedLicenseId: expectedLicenseId,
      );

      if (!isSignatureValid) {
        // رفض الأمر غير الموقّع وتسجيل اختراق أمني
        final breachResult = CommandExecutionResult(
          commandId: cmd.id,
          success: false,
          message: 'Security Alert: Command rejected due to invalid RS256 signature.',
          executedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await CommandResultStore.recordExecution(breachResult);
        continue;
      }

      // 3. البحث عن المعالج المناسب للأمر
      final handler = _handlers[cmd.command];
      if (handler == null) {
        final unhandledResult = CommandExecutionResult(
          commandId: cmd.id,
          success: false,
          message: 'Unsupported command type: ${cmd.command.name}',
          executedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await CommandResultStore.recordExecution(unhandledResult);
        continue;
      }

      // 4. تنفيذ الأمر وحفظ النتيجة
      try {
        final result = await handler.execute(cmd.id, cmd.payload);
        await CommandResultStore.recordExecution(result);
      } catch (err) {
        final errResult = CommandExecutionResult(
          commandId: cmd.id,
          success: false,
          message: 'Handler exception: $err',
          executedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await CommandResultStore.recordExecution(errResult);
      }
    }
  }
}
