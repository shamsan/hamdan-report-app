/**
 * ══════════════════════════════════════════════════════════════
 *  License Synchronization & Network Service
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  المحرك الشبكي للتواصل مع خادم التراخيص القائم (Zero-Change Server)
 *  يدعم: النبض الخفيف (Ping)، المزامنة الشاملة (Sync)، التفعيل، والتجربة
 */

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/licensing_constants.dart';
import '../security/hardware_fingerprint.dart';
import '../security/time_tamper_engine.dart';
import '../security/public_key_pinning.dart';
import '../commands/command_types.dart';
import '../commands/command_registry.dart';
import '../commands/command_result_store.dart';

class SyncServiceResponse {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  const SyncServiceResponse({required this.success, this.message, this.data});
}

class LicenseSyncService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Timer? _pingTimer;
  static Timer? _restoreTimer;
  static bool _isSyncing = false;

  static Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-api-key': LicensingConstants.defaultApiKey,
    };
  }

  // ══════════════════════════════════════════════════════════════
  // 1. طلب تفعيل النسخة التجريبية (TRIAL)
  // ══════════════════════════════════════════════════════════════
  static Future<SyncServiceResponse> requestTrial() async {
    try {
      final hwid = await HardwareFingerprint.getCompositeHwid();
      final url = Uri.parse('${LicensingConstants.defaultServerUrl}${LicensingConstants.endpointTrial}');

      final response = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode({'hardwareId': hwid}),
          )
          .timeout(LicensingConstants.networkTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['token'] != null) {
        final token = body['token'] as String;
        final publicKey = body['publicKey'] as String;

        // التحقق من تثبيت المفتاح العام
        if (!PublicKeyPinning.isAllowed(publicKey)) {
          return const SyncServiceResponse(
            success: false,
            message: 'فشل التحقق الأمني من المفتاح العام للخادم.',
          );
        }

        // حفظ التوكن والمفتاح العام في التخزين العتادي الآمن
        await _storage.write(key: LicensingConstants.keyJwtToken, value: token);
        await _storage.write(key: LicensingConstants.keyPublicKey, value: publicKey);
        await _storage.delete(key: LicensingConstants.keySuspensionReason);

        // معايرة التوقيت
        await syncServerTime();

        return SyncServiceResponse(
          success: true,
          message: 'تم تفعيل النسخة التجريبية بنجاح.',
          data: body,
        );
      } else {
        final errorMsg = body['error'] as String? ?? 'فشل طلب النسخة التجريبية (${response.statusCode})';
        return SyncServiceResponse(success: false, message: errorMsg);
      }
    } catch (e) {
      return const SyncServiceResponse(
        success: false,
        message: 'تعذر الاتصال بخادم التراخيص نظراً لعدم توفر اتصال بالإنترنت في الهاتف. يرجى التحقق من اتصالك بالإنترنت وإعادة المحاولة.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 2. تفعيل ترخيص مدفوع برقم المفتاح (ACTIVATE)
  // ══════════════════════════════════════════════════════════════
  static Future<SyncServiceResponse> activateLicense(String licenseKey) async {
    try {
      final hwid = await HardwareFingerprint.getCompositeHwid();
      final url = Uri.parse('${LicensingConstants.defaultServerUrl}${LicensingConstants.endpointActivate}');

      final response = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode({
              'licenseKey': licenseKey.trim(),
              'hardwareId': hwid,
            }),
          )
          .timeout(LicensingConstants.networkTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['token'] != null) {
        final token = body['token'] as String;
        final publicKey = body['publicKey'] as String;
        final checksum = body['publicKeyChecksum'] as String?;

        // FIX-22: التحقق من checksum المفتاح العام لحمايته أثناء النقل
        if (checksum != null && checksum.isNotEmpty) {
          final computedHash = 'sha256:${sha256.convert(utf8.encode(publicKey)).toString()}';
          if (computedHash != checksum && !checksum.contains(sha256.convert(utf8.encode(publicKey)).toString())) {
            return const SyncServiceResponse(
              success: false,
              message: 'فشل فحص سلامة المفتاح العام (Checksum Mismatch).',
            );
          }
        }

        // التحقق من تثبيت المفتاح العام
        if (!PublicKeyPinning.isAllowed(publicKey)) {
          return const SyncServiceResponse(
            success: false,
            message: 'المفتاح العام المرجع من الخادم غير معتمد أمنياً.',
          );
        }

        // تخزين التوكن والمفتاح في KeyStore المشفر
        await _storage.write(key: LicensingConstants.keyJwtToken, value: token);
        await _storage.write(key: LicensingConstants.keyPublicKey, value: publicKey);
        await _storage.delete(key: LicensingConstants.keySuspensionReason);

        await syncServerTime();

        return SyncServiceResponse(
          success: true,
          message: 'تم تفعيل الترخيص بنجاح!',
          data: body,
        );
      } else {
        final errorMsg = body['error'] as String? ?? 'فشل تفعيل الترخيص (${response.statusCode})';
        return SyncServiceResponse(success: false, message: errorMsg);
      }
    } catch (e) {
      return const SyncServiceResponse(
        success: false,
        message: 'تعذر الاتصال بخادم التراخيص. يرجى التأكد من توفر اتصال بالإنترنت والمحاولة مجدداً.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 3. النبض الدوري الخفيف Tier-1 (PING)
  // ══════════════════════════════════════════════════════════════
  static Future<void> sendPing({Function(String reason)? onKillSwitch}) async {
    try {
      final hwid = await HardwareFingerprint.getCompositeHwid();
      final url = Uri.parse('${LicensingConstants.defaultServerUrl}${LicensingConstants.endpointPing}');

      final response = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode({'hardwareId': hwid}),
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // إذا رد الخادم بـ KILL (مثل إلغاء الترخيص أو حظر الجهاز)
      if (body['action'] == 'KILL') {
        final reason = body['reason'] as String? ?? 'LICENCE_REVOKED';
        await _handleRemoteKill(reason);
        onKillSwitch?.call(reason);
        return;
      }

      // إذا كان هناك أوامر معلقة أو ترخيص معتمد جديد
      if (body['hasCommands'] == true || body['needsFullSync'] == true) {
        await performFullSync();
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════
  // 4. المزامنة الشاملة Tier-2 (FULL SYNC)
  // ══════════════════════════════════════════════════════════════
  static Future<SyncServiceResponse> performFullSync({
    Function()? onLicenseUpdated,
    Function(String reason)? onKillSwitch,
  }) async {
    if (_isSyncing) {
      return const SyncServiceResponse(success: true, message: 'المزامنة جارية بالفعل');
    }
    _isSyncing = true;

    try {
      final hwid = await HardwareFingerprint.getCompositeHwid();
      final currentToken = await _storage.read(key: LicensingConstants.keyJwtToken);
      if (currentToken == null || currentToken.isEmpty) {
        _isSyncing = false;
        return const SyncServiceResponse(success: false, message: 'لا يوجد ترخيص محلي للمزامنة');
      }

      final pendingResults = await CommandResultStore.getPendingResults();
      final url = Uri.parse('${LicensingConstants.defaultServerUrl}${LicensingConstants.endpointSync}');

      final response = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode({
              'hwid': hwid,
              'currentToken': currentToken,
              'clientVersion': '1.0.0',
              'commandResults': pendingResults,
            }),
          )
          .timeout(LicensingConstants.networkTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      // 1. تنظيف نتائج الأوامر التي تم تسليمها بنجاح للخادم
      if (pendingResults.isNotEmpty) {
        final deliveredIds = pendingResults.map((r) => r['commandId'] as String).toList();
        await CommandResultStore.clearDeliveredResults(deliveredIds);
      }

      // 2. معالجة قرارات الخادم
      final action = body['action'] as String?;

      if (action == 'KILL_SWITCH') {
        final reason = body['reason'] as String? ?? 'REVOKED';
        await _handleRemoteKill(reason);
        onKillSwitch?.call(reason);
        return SyncServiceResponse(success: false, message: 'تم إيقاف الترخيص من الخادم: $reason');
      }

      // تطبيق رخصة جديدة معتمدة تلقائياً (Auto-Apply)
      if (action == 'AUTO_LICENSE_APPLIED' && body['autoApply'] != null) {
        final autoApply = body['autoApply'] as Map<String, dynamic>;
        final newToken = autoApply['newToken'] as String;
        final publicKey = autoApply['publicKey'] as String;

        await _storage.write(key: LicensingConstants.keyJwtToken, value: newToken);
        await _storage.write(key: LicensingConstants.keyPublicKey, value: publicKey);
        await _storage.delete(key: LicensingConstants.keySuspensionReason);

        onLicenseUpdated?.call();
      }

      // تدوير التوكن بعد تجديد الصلاحية أو الميزات
      if (action == 'UPDATE_TOKEN' && body['newToken'] != null) {
        final newToken = body['newToken'] as String;
        await _storage.write(key: LicensingConstants.keyJwtToken, value: newToken);
        onLicenseUpdated?.call();
      }

      // 3. معالجة الأوامر الموقّعة الواردة
      if (body['commands'] != null && body['commands'] is List) {
        final List<dynamic> rawCommands = body['commands'];
        final commands = <IncomingRemoteCommand>[];
        for (final c in rawCommands) {
          if (c is Map) {
            try {
              commands.add(IncomingRemoteCommand.fromJson(Map<String, dynamic>.from(c)));
            } catch (_) {}
          }
        }

        if (commands.isNotEmpty) {
          await CommandRegistry().dispatchCommands(commands);
        }
      }

      return SyncServiceResponse(success: true, message: 'تمت المزامنة بنجاح', data: body);
    } catch (e) {
      return SyncServiceResponse(success: false, message: 'فشل المزامنة: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 5. Restore Poller (استعادة الترخيص بعد إيقافه أو بعد اعتماده)
  // ══════════════════════════════════════════════════════════════
  static void startRestorePolling({required Function() onRestored}) {
    stopRestorePolling();
    // الفحص كل 60 ثانية بهدوء بدون إرهاق الخادم
    _restoreTimer = Timer.periodic(LicensingConstants.restorePollInterval, (timer) async {
      final restored = await checkLicenseRestore();
      if (restored) {
        stopRestorePolling();
        onRestored();
      }
    });
  }

  static void stopRestorePolling() {
    _restoreTimer?.cancel();
    _restoreTimer = null;
  }

  static Future<bool> checkLicenseRestore() async {
    try {
      final hwid = await HardwareFingerprint.getCompositeHwid();
      final url = Uri.parse('${LicensingConstants.defaultServerUrl}${LicensingConstants.endpointStatus}');

      final response = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode({'hardwareId': hwid}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['status'] == 'ACTIVE' && body['newToken'] != null) {
        final newToken = body['newToken'] as String;
        final publicKey = body['publicKey'] as String?;

        if (publicKey != null && publicKey.isNotEmpty) {
          if (!PublicKeyPinning.isAllowed(publicKey)) {
            return false;
          }
          await _storage.write(key: LicensingConstants.keyPublicKey, value: publicKey);
        }

        await _storage.write(key: LicensingConstants.keyJwtToken, value: newToken);
        await _storage.delete(key: LicensingConstants.keySuspensionReason);
        await syncServerTime();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// مسح بيانات الترخيص الحالية محلياً (لإعادة التهيئة إذا حدث تعارض)
  static Future<void> clearStoredLicense() async {
    await _storage.delete(key: LicensingConstants.keyJwtToken);
    await _storage.delete(key: LicensingConstants.keySuspensionReason);
  }

  // ══════════════════════════════════════════════════════════════
  // 6. تقديم طلب ترخيص جديد للإدارة (Submit Request)
  // ══════════════════════════════════════════════════════════════
  static Future<SyncServiceResponse> submitRequest({
    required String type, // 'NEW_LICENSE', 'TIER_UPGRADE', 'RENEWAL'
    required String companyName,
    required String contactName,
    String? contactEmail,
    String? contactPhone,
    String? siteName,
    required String message,
    String? requestedTier,
    int? requestedDays,
  }) async {
    try {
      final hwid = await HardwareFingerprint.getCompositeHwid();
      final url = Uri.parse('${LicensingConstants.defaultServerUrl}${LicensingConstants.endpointRequests}');

      final payload = {
        'type': type,
        'hwid': hwid,
        'companyName': companyName.trim(),
        'contactName': contactName.trim(),
        if (contactEmail != null) 'contactEmail': contactEmail.trim(),
        if (contactPhone != null) 'contactPhone': contactPhone.trim(),
        if (siteName != null) 'siteName': siteName.trim(),
        'message': message.trim(),
        if (requestedTier != null) 'requestedTier': requestedTier,
        if (requestedDays != null) 'requestedDays': requestedDays,
      };

      final response = await http
          .post(
            url,
            headers: _buildHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(LicensingConstants.networkTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['request'] != null && body['request']['id'] != null) {
          await _storage.write(
            key: LicensingConstants.keyLastRequestId,
            value: body['request']['id'].toString(),
          );
        }
        return SyncServiceResponse(
          success: true,
          message: 'تم إرسال طلبك للإدارة بنجاح. سيتم تفعيل ترخيصك تلقائياً بمجرد الموافقة.',
          data: body,
        );
      } else {
        return SyncServiceResponse(
          success: false,
          message: body['error'] as String? ?? 'فشل تقديم الطلب (${response.statusCode})',
        );
      }
    } catch (e) {
      return const SyncServiceResponse(
        success: false,
        message: 'تعذر الاتصال بخادم التراخيص. يرجى التأكد من توفر اتصال بالإنترنت والمحاولة مجدداً.',
      );
    }
  }

  /// استرجاع أحدث طلب ترخيص معلق لهذا الهاتف إن وُجد
  static Future<Map<String, dynamic>?> fetchLatestPendingRequest() async {
    try {
      final hwid = await HardwareFingerprint.getCompositeHwid();
      final url = Uri.parse('${LicensingConstants.defaultServerUrl}${LicensingConstants.endpointRequests}?hwid=$hwid');

      final response = await http
          .get(url, headers: _buildHeaders())
          .timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true && body['requests'] is List) {
        final List<dynamic> requests = body['requests'];
        if (requests.isEmpty) return null;

        // إذا وُجد طلب معتمد، فحص الاستعادة فوراً
        final approved = requests.firstWhere(
          (r) => r['status'] == 'APPROVED',
          orElse: () => null,
        );
        if (approved != null) {
          await checkLicenseRestore();
        }

        final pending = requests.firstWhere(
          (r) => r['status'] == 'PENDING',
          orElse: () => null,
        );

        if (pending != null) {
          return Map<String, dynamic>.from(pending as Map);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 7. مزامنة التوقيت مع الخادم المرجعي
  // ══════════════════════════════════════════════════════════════
  static Future<void> syncServerTime() async {
    try {
      final url = Uri.parse('${LicensingConstants.defaultServerUrl}${LicensingConstants.endpointTime}');
      final response = await http.get(url, headers: _buildHeaders()).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['serverTime'] != null) {
          final serverTimeMs = body['serverTime'] as int;
          await TimeTamperEngine.calibrateFromServer(serverTimeMs);
        }
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════
  // 8. التعامل مع إلغاء الترخيص الفوري
  // ══════════════════════════════════════════════════════════════
  static Future<void> _handleRemoteKill(String reason) async {
    await _storage.write(key: LicensingConstants.keySuspensionReason, value: reason);
    await _storage.delete(key: LicensingConstants.keyJwtToken);
  }

  // ══════════════════════════════════════════════════════════════
  // 9. تشغيل / إيقاف نبضات Tier-1 التلقائية
  // ══════════════════════════════════════════════════════════════
  static void startPingTimer({required Function(String reason) onKillSwitch}) {
    _pingTimer?.cancel();
    // إرسال فحص أولي فوري عند بدء التطبيق دون تأخير 5 دقائق
    sendPing(onKillSwitch: onKillSwitch);
    _pingTimer = Timer.periodic(LicensingConstants.pingInterval, (_) {
      sendPing(onKillSwitch: onKillSwitch);
    });
  }

  static void stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }
}
