/**
 * ══════════════════════════════════════════════════════════════
 *  Licensing Riverpod Provider & State Notifier
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  إدارة حالة الترخيص والتحكم بحصانة التطبيق والربط المباشر مع واجهات المستخدم
 */

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/licensing/engine/license_models.dart';
import '../core/licensing/engine/license_guard.dart';
import '../core/licensing/network/license_sync_service.dart';
import '../core/licensing/commands/command_event_bus.dart';
import '../services/storage_service.dart';

class LicenseException implements Exception {
  final String message;
  const LicenseException(this.message);
  @override
  String toString() => message;
}

class LicenseStateNotifier extends StateNotifier<LicenseInfo> {
  final StorageService _storageService = StorageService();
  bool _isInitialized = false;

  LicenseStateNotifier()
      : super(const LicenseInfo(
          status: LicenseStatus.activeTrial,
          lockReason: LicenseLockReason.none,
          tier: 'TRIAL',
          daysLeft: 60,
          totalTrialDays: 60,
          reportsUsed: 0,
          reportsLeft: 15,
          maxReports: 15,
          isUnlimitedReports: false,
          message: 'جاري التحقق من الترخيص...',
        )) {
    initialize();
  }

  /// التهيئة الأولية عند تشغيل التطبيق
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. تقييم الترخيص محلياً
    await refresh();

    // 2. إذا كان التطبيق غير مسجل نهائياً، أو مقفلاً بسبب بصمة هاتف سابق
    if (state.lockReason == LicenseLockReason.notRegistered ||
        state.lockReason == LicenseLockReason.hwidMismatch) {
      // أ) أولاً: فحص هل الخادم يمتلك ترخيصاً نشطاً لهذا الهاتف
      bool restored = false;
      try {
        restored = await LicenseSyncService.checkLicenseRestore();
      } catch (_) {}

      if (restored) {
        await refresh();
      } else {
        // ب) ثانياً: طلب نسخة تجريبية جديدة لهذا الجهاز تلقائياً
        final trialResult = await LicenseSyncService.requestTrial();
        if (trialResult.success) {
          await refresh();
        }
      }
    }

    // 3. مزامنة التوقيت مع الخادم المرجعي في الخلفية
    LicenseSyncService.syncServerTime().catchError((_) {});

    // 4. تشغيل مؤقت النبض الخفيف (Ping Timer كل 5 دقائق)
    LicenseSyncService.startPingTimer(
      onKillSwitch: (reason) async {
        await refresh();
      },
    );

    // 5. إذا كان الترخيص مقفلاً، تشغيل Restore Poller بهدوء في الخلفية
    if (state.isLocked) {
      LicenseSyncService.startRestorePolling(
        onRestored: () async {
          await refresh();
        },
      );
    }
  }

  /// إعادة تقييم حالة الترخيص وتحديث الـ State
  Future<void> refresh([int? explicitReportsCount]) async {
    int reportsCount = explicitReportsCount ?? 0;
    if (explicitReportsCount == null) {
      try {
        final reports = await _storageService.loadReports();
        reportsCount = reports.length;
      } catch (_) {
        reportsCount = 0;
      }
    }

    final newInfo = await LicenseGuard.evaluateLicense(reportsCount);
    state = newInfo;

    // إدارة الـ Restore Poller تلقائياً حسب حالة القفل
    if (newInfo.isLocked) {
      LicenseSyncService.startRestorePolling(
        onRestored: () async {
          await refresh();
        },
      );
    } else {
      LicenseSyncService.stopRestorePolling();
    }
  }

  /// تفعيل رخصة برقم المفتاح
  Future<SyncServiceResponse> activate(String licenseKey) async {
    final res = await LicenseSyncService.activateLicense(licenseKey);
    if (res.success) {
      await refresh();
    }
    return res;
  }

  /// طلب تفعيل الفترة التجريبية يدوياً
  Future<SyncServiceResponse> requestTrial() async {
    // محاولة الاستعادة أولاً إن كان مسجلاً بالفعل
    final restored = await LicenseSyncService.checkLicenseRestore();
    if (restored) {
      await refresh();
      return const SyncServiceResponse(success: true, message: 'تم استعادة ترخيص هذا الهاتف بنجاح!');
    }

    final res = await LicenseSyncService.requestTrial();
    if (res.success) {
      await refresh();
    }
    return res;
  }

  /// التحقق من حالة ترخيص هذا الهاتف أونلاين
  Future<SyncServiceResponse> checkOnlineStatus() async {
    final restored = await LicenseSyncService.checkLicenseRestore();
    if (restored) {
      await refresh();
      return const SyncServiceResponse(success: true, message: 'تم تفعيل الترخيص بنجاح!');
    }
    final trialRes = await LicenseSyncService.requestTrial();
    if (trialRes.success) {
      await refresh();
      return trialRes;
    }
    return trialRes;
  }

  /// المزامنة الفورية مع الخادم
  Future<SyncServiceResponse> syncNow() async {
    final res = await LicenseSyncService.performFullSync(
      onLicenseUpdated: () async {
        await refresh();
      },
      onKillSwitch: (reason) async {
        await refresh();
      },
    );
    await refresh();
    return res;
  }

  /// تقديم طلب ترخيص جديد من واجهة القفل
  Future<SyncServiceResponse> submitRequest({
    required String type,
    required String companyName,
    required String contactName,
    String? contactEmail,
    String? contactPhone,
    String? siteName,
    required String message,
    String? requestedTier,
    int? requestedDays,
  }) async {
    final res = await LicenseSyncService.submitRequest(
      type: type,
      companyName: companyName,
      contactName: contactName,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      siteName: siteName,
      message: message,
      requestedTier: requestedTier,
      requestedDays: requestedDays,
    );

    if (res.success) {
      // تشغيل Restore Poller لمراقبة موافقة الإدارة التلقائية
      LicenseSyncService.startRestorePolling(
        onRestored: () async {
          await refresh();
        },
      );
    }
    return res;
  }

  @override
  void dispose() {
    LicenseSyncService.stopPingTimer();
    LicenseSyncService.stopRestorePolling();
    super.dispose();
  }
}

/// Provider لحالة الترخيص الشاملة
final licensingProvider = StateNotifierProvider<LicenseStateNotifier, LicenseInfo>((ref) {
  return LicenseStateNotifier();
});

/// Provider لاستقبال أحداث الأوامر الفورية (مثل عرض رسائل مركزية أو صيانة)
final licensingUIEventsProvider = StreamProvider<LicensingUIEvent>((ref) {
  return CommandEventBus().stream;
});
