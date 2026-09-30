/**
 * ══════════════════════════════════════════════════════════════
 *  SHOW_MESSAGE Command Handler
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 */

import '../command_types.dart';
import '../command_event_bus.dart';

class ShowMessageHandler implements BaseCommandHandler {
  @override
  RemoteCommandType get commandType => RemoteCommandType.SHOW_MESSAGE;

  @override
  Future<CommandExecutionResult> execute(String commandId, Map<String, dynamic> payload) async {
    final title = (payload['title'] ?? payload['header']) as String? ?? 'إشعار من الإدارة المركزية';
    final message = (payload['message'] ?? payload['text'] ?? payload['msg'] ?? payload['body']) as String? ?? '';
    final type = (payload['severity'] ?? payload['type'] ?? 'info') as String;
    final isDismissible = payload['dismissible'] as bool? ?? true;

    CommandEventBus().emit(ShowMessageUIEvent(
      title: title,
      message: message,
      type: type,
      isDismissible: isDismissible,
    ));

    return CommandExecutionResult(
      commandId: commandId,
      success: true,
      message: 'تم عرض الرسالة للمستخدم بنجاح',
      executedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }
}
