import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// مساعدات UI موحدة لاستخدامها في جميع أنحاء التطبيق
class UiHelpers {
  /// فك ترميز آمن لسلسلة base64 مع إزالة data URI والمسافات وإصلاح الـ padding
  static Uint8List? safeDecodeBase64(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.contains(',')) {
      cleaned = cleaned.substring(cleaned.indexOf(',') + 1).trim();
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return null;
    final remainder = cleaned.length % 4;
    if (remainder > 0) {
      cleaned = cleaned.padRight(cleaned.length + (4 - remainder), '=');
    }
    try {
      final bytes = base64Decode(cleaned);
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  /// عرض SnackBar موحد ومتسق
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
    bool floating = true,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 13)),
          backgroundColor: backgroundColor,
          behavior: floating ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
          shape: floating
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              : null,
          margin: floating ? const EdgeInsets.fromLTRB(16, 0, 16, 16) : null,
          action: action,
          duration: duration,
        ),
      );
  }

  /// عرض SnackBar نجاح (أخضر)
  static void showSuccessSnackBar(BuildContext context, String message, {SnackBarAction? action}) {
    showSnackBar(
      context,
      message,
      backgroundColor: AppTheme.statusGood,
      action: action,
    );
  }

  /// عرض SnackBar خطأ (أحمر)
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: AppTheme.statusRejected,
    );
  }

  /// عرض SnackBar تحذير (ذهبي)
  static void showWarningSnackBar(BuildContext context, String message, {SnackBarAction? action}) {
    showSnackBar(
      context,
      message,
      backgroundColor: AppTheme.statusFollowup,
      action: action,
    );
  }

  /// عرض SnackBar حذف مع زر تراجع
  static void showDeleteUndoSnackBar(
    BuildContext context,
    String itemName,
    VoidCallback onUndo,
  ) {
    showSnackBar(
      context,
      'تم حذف "$itemName"',
      backgroundColor: const Color(0xFF334155),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'تراجع',
        textColor: AppTheme.solarGold,
        onPressed: onUndo,
      ),
    );
  }

  /// عرض نافذة تأكيد حذف
  static Future<bool> showDeleteConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmLabel = 'حذف',
    String cancelLabel = 'إلغاء',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(content, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// فتح date picker بتنسيق عربي ويعيد النتيجة كـ String بصيغة YYYY/MM/DD
  static Future<String?> showArabicDatePicker(
    BuildContext context, {
    String? currentValue,
  }) async {
    DateTime initial = DateTime.now();
    if (currentValue != null && currentValue.isNotEmpty) {
      final parsed = DateTime.tryParse(currentValue.replaceAll('/', '-'));
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppTheme.primaryNavy,
          ),
        ),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );

    if (picked == null) return null;
    return '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
  }
}
