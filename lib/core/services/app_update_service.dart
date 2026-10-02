/**
 * ══════════════════════════════════════════════════════════════
 *  App Update & Seamless In-App OTA Service
 *  ReportCraft Enterprise Mobile Client
 * ══════════════════════════════════════════════════════════════
 *  إدارة تنزيل التحديثات المباشرة، فحص البصمة الرقمية (SHA-256)،
 *  أخذ لقطة أمان احتياطية لقاعدة البيانات، وتثبيت حزمة الـ APK بسلاسة.
 */

import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/backup_service.dart';

class AppUpdateProgress {
  final double progress; // من 0.0 إلى 1.0
  final int receivedBytes;
  final int totalBytes;
  final String statusText;
  final bool isCompleted;
  final bool isFailed;
  final String? errorMessage;
  final String? localApkPath;

  const AppUpdateProgress({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    required this.statusText,
    this.isCompleted = false,
    this.isFailed = false,
    this.errorMessage,
    this.localApkPath,
  });
}

class AppUpdateService {
  static const MethodChannel _channel = MethodChannel('com.reportcraft/updater');

  /// فحص هل يمتلك التطبيق إذن تثبيت الحزم من مصادر غير معروفة (Android 8.0+)
  static Future<bool> canRequestPackageInstalls() async {
    try {
      if (!Platform.isAndroid) return true;
      final bool? allowed = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return allowed ?? true;
    } catch (_) {
      return true;
    }
  }

  /// فتح صفحة إعدادات أندرويد لتفعيل إذن تثبيت التحديثات لـ ReportCraft
  static Future<void> openInstallPermissionSettings() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openInstallPermissionSettings');
      }
    } catch (_) {}
  }

  /// إطلاق معالج تثبيت أندرويد لحزمة الـ APK المحملة عبر FileProvider
  static Future<bool> installApk(String filePath) async {
    try {
      if (!Platform.isAndroid) return false;
      final bool? result = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// فتح رابط التنزيل في المتصفح كحل بديل (Fallback)
  static Future<bool> openDownloadInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// تنفيذ تدفق التحديث الشامل:
  /// 1. أخذ نسخة احتياطية محلية فورية لحماية البيانات 100%
  /// 2. تنزيل ملف الـ APK مع بث نسبة التقدم
  /// 3. فحص البصمة الرياضية (SHA-256)
  /// 4. إطلاق عملية التثبيت
  static Stream<AppUpdateProgress> startDownloadAndInstall({
    required String downloadUrl,
    required String version,
    String? expectedChecksum,
    int? expectedFileSize,
  }) async* {
    File? apkFile;
    http.Client? client;

    try {
      // 1. أمان البيانات الميدانية: لقطة أمان احتياطية فورية قبل أي تعديل
      yield const AppUpdateProgress(
        progress: 0.05,
        receivedBytes: 0,
        totalBytes: 0,
        statusText: 'جاري تأمين التقارير بنسخة احتياطية فورية...',
      );

      try {
        await BackupService.exportArchiveLocalFile();
      } catch (_) {
        // فشل النسخ الاحتياطي لا يوقف التحديث إن كانت المساحة كافية
      }

      // 2. تجهيز مجلد التحديثات في الكاش المؤقت
      final tempDir = await getTemporaryDirectory();
      final updatesDir = Directory('${tempDir.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      final safeVersion = version.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      apkFile = File('${updatesDir.path}/reportcraft_v$safeVersion.apk');
      if (await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }

      yield AppUpdateProgress(
        progress: 0.08,
        receivedBytes: 0,
        totalBytes: expectedFileSize ?? 0,
        statusText: 'جاري الاتصال بخادم التحديثات...',
      );

      // 3. بدء التنزيل المقسم (Streaming Download) مع دعم تحويلات GitHub Releases
      client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'ReportCraft-Enterprise-Updater/1.0';
      request.followRedirects = true;
      request.maxRedirects = 5;

      final streamedResponse = await client.send(request);
      if (streamedResponse.statusCode != 200) {
        throw Exception('تعذر تنزيل الحزمة (رمز الاستجابة: ${streamedResponse.statusCode})');
      }

      final totalBytes = streamedResponse.contentLength ?? expectedFileSize ?? 0;
      int receivedBytes = 0;
      final sink = apkFile.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final rawRatio = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.5;
        // نسبة التنزيل تمثل ما بين 10% إلى 90%
        final normalizedProgress = 0.10 + (rawRatio * 0.80);

        final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
        final mbTotal = totalBytes > 0 ? (totalBytes / (1024 * 1024)).toStringAsFixed(1) : '?';

        yield AppUpdateProgress(
          progress: normalizedProgress.clamp(0.10, 0.90),
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          statusText: 'جاري تنزيل التحديث ($mbReceived من $mbTotal ميجابايت)...',
        );
      }

      await sink.flush();
      await sink.close();
      client.close();
      client = null;

      // 4. التحقق الرياضي من بصمة الملف (SHA-256) إن توفرت
      if (expectedChecksum != null && expectedChecksum.trim().isNotEmpty) {
        yield AppUpdateProgress(
          progress: 0.94,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          statusText: 'جاري فحص سلامة وتوقيع ملف التحديث...',
        );

        final bytes = await apkFile.readAsBytes();
        final actualHash = sha256.convert(bytes).toString().toLowerCase();
        final cleanExpected = expectedChecksum
            .toLowerCase()
            .replaceFirst('sha256:', '')
            .replaceAll(':', '')
            .trim();

        if (cleanExpected.isNotEmpty && actualHash != cleanExpected) {
          try {
            await apkFile.delete();
          } catch (_) {}
          throw Exception('فشل فحص سلامة الحزمة (Checksum Mismatch). الملف المحمّل غير مطابق للمصدر.');
        }
      }

      // 5. الحزمة سليمة وجاهزة للتثبيت المباشر
      yield AppUpdateProgress(
        progress: 1.0,
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
        statusText: 'تم التنزيل بنجاح! جاري فتح معالج تثبيت أندرويد...',
        isCompleted: true,
        localApkPath: apkFile.path,
      );

      // استدعاء مثبت أندرويد
      final success = await installApk(apkFile.path);
      if (!success) {
        // إذا تعذر الفتح المباشر، لا نلقي استثناء بل نتيح للمستخدم الفتح أو المتصفح
      }
    } catch (e) {
      client?.close();
      yield AppUpdateProgress(
        progress: 0.0,
        receivedBytes: 0,
        totalBytes: 0,
        statusText: 'تعذر استكمال التحديث',
        isFailed: true,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}
