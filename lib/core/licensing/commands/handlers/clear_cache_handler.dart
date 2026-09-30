/**
 * ══════════════════════════════════════════════════════════════
 *  CLEAR_CACHE Command Handler
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 */

import 'dart:io';
import 'package:flutter/painting.dart';
import '../command_types.dart';

class ClearCacheHandler implements BaseCommandHandler {
  @override
  RemoteCommandType get commandType => RemoteCommandType.CLEAR_CACHE;

  @override
  Future<CommandExecutionResult> execute(String commandId, Map<String, dynamic> payload) async {
    try {
      // 1. تنظيف كاش الصور في فلاتر
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // 2. تنظيف الملفات المؤقتة في مجلد التخزين المؤقت للنظام
      final tempDir = Directory.systemTemp;
      if (await tempDir.exists()) {
        final entities = tempDir.listSync(followLinks: false);
        for (final entity in entities) {
          try {
            if (entity is File && entity.path.contains('report_craft_temp')) {
              await entity.delete();
            }
          } catch (_) {}
        }
      }

      return CommandExecutionResult(
        commandId: commandId,
        success: true,
        message: 'تم تفريغ الذاكرة المؤقتة بنجاح',
        executedAt: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      return CommandExecutionResult(
        commandId: commandId,
        success: false,
        message: 'فشل تفريغ الذاكرة المؤقتة: $e',
        executedAt: DateTime.now().toUtc().toIso8601String(),
      );
    }
  }
}
