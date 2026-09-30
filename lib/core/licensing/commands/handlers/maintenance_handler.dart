/**
 * ══════════════════════════════════════════════════════════════
 *  MAINTENANCE_MODE Command Handler
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 */

import '../command_types.dart';
import '../command_event_bus.dart';

class MaintenanceHandler implements BaseCommandHandler {
  @override
  RemoteCommandType get commandType => RemoteCommandType.MAINTENANCE_MODE;

  @override
  Future<CommandExecutionResult> execute(String commandId, Map<String, dynamic> payload) async {
    final enabled = payload['enabled'] as bool? ?? true;
    final message = payload['message'] as String? ?? 'النظام قيد الصيانة المجدولة حالياً، يرجى المحاولة لاحقاً.';

    CommandEventBus().emit(MaintenanceModeUIEvent(
      isEnabled: enabled,
      message: message,
    ));

    return CommandExecutionResult(
      commandId: commandId,
      success: true,
      message: 'تم تحديث حالة الصيانة بنجاح ($enabled)',
      executedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }
}
