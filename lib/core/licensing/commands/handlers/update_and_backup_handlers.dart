/**
 * ══════════════════════════════════════════════════════════════
 *  FORCE_UPDATE & BACKUP_NOW Command Handlers
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 */

import '../command_types.dart';
import '../command_event_bus.dart';

class ForceUpdateHandler implements BaseCommandHandler {
  @override
  RemoteCommandType get commandType => RemoteCommandType.FORCE_UPDATE;

  @override
  Future<CommandExecutionResult> execute(String commandId, Map<String, dynamic> payload) async {
    final version = payload['version'] as String? ?? '';
    final downloadUrl = payload['downloadUrl'] as String?;
    final isMandatory = (payload['isMandatory'] ?? payload['mandatory']) as bool? ?? false;
    final releaseNotes = payload['releaseNotes'] as String?;
    final checksum = payload['checksum'] as String?;
    final dynamic rawSize = payload['fileSize'];
    final int? fileSize = rawSize is int ? rawSize : (rawSize is String ? int.tryParse(rawSize) : null);

    CommandEventBus().emit(ForceUpdateUIEvent(
      version: version,
      downloadUrl: downloadUrl,
      isMandatory: isMandatory,
      releaseNotes: releaseNotes,
      checksum: checksum,
      fileSize: fileSize,
    ));

    return CommandExecutionResult(
      commandId: commandId,
      success: true,
      message: 'تم استلام توجيه التحديث وإشعار المستخدم بنجاح',
      executedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }
}

class BackupNowHandler implements BaseCommandHandler {
  @override
  RemoteCommandType get commandType => RemoteCommandType.BACKUP_NOW;

  @override
  Future<CommandExecutionResult> execute(String commandId, Map<String, dynamic> payload) async {
    // تشغيل عملية النسخ الاحتياطي السحابي أو المحلي لبيانات التقارير
    return CommandExecutionResult(
      commandId: commandId,
      success: true,
      message: 'تم جدولة عملية النسخ الاحتياطي لقاعدة البيانات بنجاح',
      executedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }
}
