/**
 * ══════════════════════════════════════════════════════════════
 *  Remote Command Types & Definitions
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 */

import 'dart:convert';

enum RemoteCommandType {
  SHOW_MESSAGE,
  FORCE_UPDATE,
  CLEAR_CACHE,
  COLLECT_DIAGNOSTICS,
  BACKUP_NOW,
  MAINTENANCE_MODE,
  KILL_SWITCH,
  FACTORY_RESET,
  CUSTOM_SCRIPT,
  UNKNOWN,
}

class IncomingRemoteCommand {
  final String id;
  final RemoteCommandType command;
  final Map<String, dynamic> payload;
  final String? signature; // توقيع RS256 من السيرفر

  IncomingRemoteCommand({
    required this.id,
    required this.command,
    required this.payload,
    this.signature,
  });

  factory IncomingRemoteCommand.fromJson(Map<String, dynamic> json) {
    final cmdStr = json['command'] as String? ?? '';
    final cmdType = RemoteCommandType.values.firstWhere(
      (e) => e.name == cmdStr,
      orElse: () => RemoteCommandType.UNKNOWN,
    );

    Map<String, dynamic> safePayload = {};
    final rawPayload = json['payload'];
    if (rawPayload is Map) {
      safePayload = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String && rawPayload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          safePayload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return IncomingRemoteCommand(
      id: json['id'] as String? ?? '',
      command: cmdType,
      payload: safePayload,
      signature: json['sig'] as String?,
    );
  }
}

class CommandExecutionResult {
  final String commandId;
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
  final String executedAt;

  CommandExecutionResult({
    required this.commandId,
    required this.success,
    this.message,
    this.data,
    required this.executedAt,
  });

  Map<String, dynamic> toJson() => {
    'commandId': commandId,
    'success': success,
    if (message != null) 'message': message,
    if (data != null) 'data': data,
    'executedAt': executedAt,
  };
}

abstract class BaseCommandHandler {
  RemoteCommandType get commandType;
  Future<CommandExecutionResult> execute(String commandId, Map<String, dynamic> payload);
}
