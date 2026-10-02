/**
 * ══════════════════════════════════════════════════════════════
 *  Global Command UI Event Listener & Robust Modal Dialogs
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  التقاط أوامر الإدارة المركزية وعرضها بنماذج منبثقة أنيقة ومحصنة
 *  لا تختفي من الشاشة إلا بنقر المستخدم الصريح على زر التأكيد.
 */

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/licensing/commands/command_event_bus.dart';
import '../../core/licensing/network/license_sync_service.dart';
import '../../core/services/app_update_service.dart';
import '../../core/theme/app_theme.dart';

/// ويدجت تغليف عامة على مستوى التطبيق بالكامل تستمع لأحداث الأوامر
/// وتضمن ظهور النوافذ المنبثقة بشكل فوري فوق أي شاشة دون الاعتماد على مسار Navigator
class LicensingCommandEventListener extends StatefulWidget {
  final Widget child;

  const LicensingCommandEventListener({super.key, required this.child});

  @override
  State<LicensingCommandEventListener> createState() => _LicensingCommandEventListenerState();
}

class _LicensingCommandEventListenerState extends State<LicensingCommandEventListener>
    with WidgetsBindingObserver {
  StreamSubscription<LicensingUIEvent>? _subscription;

  // الحالات النشطة للأوامر المعروضة
  ShowMessageUIEvent? _activeMessage;
  MaintenanceModeUIEvent? _activeMaintenance;
  ForceUpdateUIEvent? _activeUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // الاستماع لقناة أحداث الأوامر اللحظية
    _subscription = CommandEventBus().stream.listen((event) {
      if (!mounted) return;
      _handleIncomingEvent(event);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // فحص الأوامر فور عودة التطبيق للواجهة الأمامية
    if (state == AppLifecycleState.resumed) {
      LicenseSyncService.sendPing();
    }
  }

  void _handleIncomingEvent(LicensingUIEvent event) {
    setState(() {
      if (event is ShowMessageUIEvent) {
        _activeMessage = event;
        HapticFeedback.heavyImpact();
      } else if (event is MaintenanceModeUIEvent) {
        _activeMaintenance = event;
      } else if (event is ForceUpdateUIEvent) {
        _activeUpdate = event;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. المحتوى الأساسي لكامل شاشات التطبيق
        widget.child,

        // 2. نموذج رسالة الإدارة المنبثق الأنيق (المحصن)
        if (_activeMessage != null)
          _buildMessageModalOverlay(_activeMessage!),

        // 3. نموذج وضع الصيانة (إذا كان مفعلاً)
        if (_activeMaintenance != null && _activeMaintenance!.isEnabled)
          _buildMaintenanceModalOverlay(_activeMaintenance!),

        // 4. نموذج طلب التحديث المباشر
        if (_activeUpdate != null)
          _ForceUpdateModalOverlay(
            event: _activeUpdate!,
            onDismiss: () => setState(() => _activeUpdate = null),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // نافذة عرض الرسالة المنبثقة (SHOW_MESSAGE Modal Overlay)
  // ══════════════════════════════════════════════════════════════
  Widget _buildMessageModalOverlay(ShowMessageUIEvent event) {
    Color primaryColor;
    Color lightBg;
    IconData iconData;
    String badgeLabel;

    final typeLower = (event.type ?? 'info').toLowerCase();
    switch (typeLower) {
      case 'warning':
        primaryColor = AppTheme.statusFollowup;
        lightBg = AppTheme.statusFollowupBg;
        iconData = Icons.warning_amber_rounded;
        badgeLabel = 'تنبيه إداري هام';
        break;
      case 'critical':
      case 'danger':
      case 'error':
        primaryColor = AppTheme.statusRejected;
        lightBg = AppTheme.statusRejectedBg;
        iconData = Icons.error_outline_rounded;
        badgeLabel = 'إشعار عاجل ومهم';
        break;
      case 'success':
        primaryColor = AppTheme.statusGood;
        lightBg = AppTheme.statusGoodBg;
        iconData = Icons.check_circle_outline_rounded;
        badgeLabel = 'تأكيد من الإدارة';
        break;
      case 'info':
      default:
        primaryColor = AppTheme.brandCyan;
        lightBg = AppTheme.statusAcceptableBg;
        iconData = Icons.campaign_rounded;
        badgeLabel = 'إشعار من الإدارة المركزية';
        break;
    }

    return PopScope(
      canPop: false, // منع الإغلاق بزر الرجوع في الهاتف إطلاقاً
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // خلفية ضبابية معتمة تمنع التفاعل مع الشاشة الخلفية
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),

            // كارت الرسالة المنبثق الأنيق في المنتصف
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // شارة النوع العلوية مع الأيقونة المتناسقة
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: lightBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.35),
                              width: 2.5,
                            ),
                          ),
                          child: Icon(iconData, color: primaryColor, size: 36),
                        ),
                        const SizedBox(height: 14),

                        // شارة التصنيف
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: lightBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              fontFamily: 'Almarai',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // عنوان الإشعار
                        Text(
                          event.title.isNotEmpty ? event.title : 'إشعار من الإدارة المركزية',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                            fontFamily: 'Almarai',
                          ),
                        ),
                        const SizedBox(height: 14),

                        // صندوق محتوى الرسالة
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 280),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              event.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: AppTheme.textSecondary,
                                height: 1.6,
                                fontFamily: 'Almarai',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // زر التأكيد الوحيد الذي يغلق النموذج بنقر المستخدم
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _activeMessage = null; // لا يختفي إلا بالنقر هنا
                              });
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'حسناً، تم الاطلاع والموافقة',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Almarai',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // نافذة وضع الصيانة (MAINTENANCE_MODE Modal Overlay)
  // ══════════════════════════════════════════════════════════════
  Widget _buildMaintenanceModalOverlay(MaintenanceModeUIEvent event) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppTheme.statusFollowupBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.construction_rounded, color: AppTheme.solarGold, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'النظام في وضع الصيانة المجدولة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════
// نافذة التحديث المباشر التفاعلية (FORCE_UPDATE Modal Overlay)
// ══════════════════════════════════════════════════════════════
class _ForceUpdateModalOverlay extends StatefulWidget {
  final ForceUpdateUIEvent event;
  final VoidCallback onDismiss;

  const _ForceUpdateModalOverlay({
    required this.event,
    required this.onDismiss,
  });

  @override
  State<_ForceUpdateModalOverlay> createState() => _ForceUpdateModalOverlayState();
}

class _ForceUpdateModalOverlayState extends State<_ForceUpdateModalOverlay> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;
  bool _isCompleted = false;
  String? _localApkPath;
  StreamSubscription<AppUpdateProgress>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startUpdate() {
    final url = widget.event.downloadUrl;
    if (url == null || url.trim().isEmpty) {
      setState(() {
        _errorMessage = 'رابط التحديث غير متوفر حالياً من الخادم.';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.05;
      _statusText = 'جاري التهيئة...';
    });

    _sub?.cancel();
    _sub = AppUpdateService.startDownloadAndInstall(
      downloadUrl: url.trim(),
      version: widget.event.version,
      expectedChecksum: widget.event.checksum,
      expectedFileSize: widget.event.fileSize,
    ).listen(
      (updateProgress) {
        if (!mounted) return;
        setState(() {
          _progress = updateProgress.progress;
          _statusText = updateProgress.statusText;
          if (updateProgress.isFailed) {
            _isDownloading = false;
            _errorMessage = updateProgress.errorMessage ?? 'تعذر استكمال التحديث.';
          } else if (updateProgress.isCompleted) {
            _isDownloading = false;
            _isCompleted = true;
            _localApkPath = updateProgress.localApkPath;
          }
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _errorMessage = err.toString();
        });
      },
    );
  }

  void _reinstall() {
    if (_localApkPath != null) {
      HapticFeedback.lightImpact();
      AppUpdateService.installApk(_localApkPath!);
    }
  }

  void _openInBrowser() {
    final url = widget.event.downloadUrl;
    if (url != null && url.isNotEmpty) {
      HapticFeedback.lightImpact();
      AppUpdateService.openDownloadInBrowser(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.event.isMandatory;
    final canPop = !isMandatory && !_isDownloading;

    return PopScope(
      canPop: canPop,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withValues(alpha: 0.75)),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // أيقونة الحالة العلوية
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: _errorMessage != null
                                ? AppTheme.statusRejectedBg
                                : (_isCompleted
                                    ? AppTheme.statusGoodBg
                                    : AppTheme.statusAcceptableBg),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _errorMessage != null
                                  ? AppTheme.statusRejected.withValues(alpha: 0.3)
                                  : (_isCompleted
                                      ? AppTheme.statusGood.withValues(alpha: 0.3)
                                      : AppTheme.brandCyan.withValues(alpha: 0.3)),
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            _errorMessage != null
                                ? Icons.error_outline_rounded
                                : (_isCompleted
                                    ? Icons.check_circle_outline_rounded
                                    : (_isDownloading
                                        ? Icons.downloading_rounded
                                        : Icons.system_update_rounded)),
                            color: _errorMessage != null
                                ? AppTheme.statusRejected
                                : (_isCompleted ? AppTheme.statusGood : AppTheme.brandCyan),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // شارات المعلومات (النسخة، إجباري، الحجم)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderSubtle),
                              ),
                              child: Text(
                                'الإصدار ${widget.event.version}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                  fontFamily: 'Almarai',
                                ),
                              ),
                            ),
                            if (widget.event.fileSize != null && widget.event.fileSize! > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: Text(
                                  '${(widget.event.fileSize! / (1024 * 1024)).toStringAsFixed(1)} ميجابايت',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                    fontFamily: 'Almarai',
                                  ),
                                ),
                              ),
                            if (isMandatory)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.statusFollowupBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.statusFollowup.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'تحديث إلزامي',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.statusFollowup,
                                    fontFamily: 'Almarai',
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // العنوان
                        const Text(
                          'تحديث جديد متاح للتطبيق',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                            fontFamily: 'Almarai',
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ملاحظات الإصدار
                        if (widget.event.releaseNotes != null && widget.event.releaseNotes!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 130),
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.event.releaseNotes!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                  fontFamily: 'Almarai',
                                ),
                              ),
                            ),
                          ),

                        // شارة الأمان لحفظ البيانات بنسبة 100%
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.statusGoodBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.statusGood.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 20, color: AppTheme.statusGood),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'أمان البيانات: يتم حفظ نسخة احتياطية لكافة تقاريرك تلقائياً قبل التثبيت.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.statusGood,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Almarai',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // شريط التقدم أثناء التنزيل
                        if (_isDownloading || _progress > 0) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _statusText,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                        fontFamily: 'Almarai',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(_progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryNavy,
                                      fontFamily: 'Almarai',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _progress.clamp(0.0, 1.0),
                                  backgroundColor: AppTheme.borderSubtle,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryNavy),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ],

                        // رسالة الخطأ إن وجدت
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.statusRejectedBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.statusRejected.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: AppTheme.statusRejected, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.statusRejected,
                                      fontFamily: 'Almarai',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // أزرار الإجراءات التفاعلية
                        if (_isCompleted) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.statusGood,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _reinstall,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.open_in_new_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'فتح معالج التثبيت مرة أخرى',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Almarai',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else if (_isDownloading) ...[
                          Container(
                            width: double.infinity,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryNavy),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'جاري التنزيل والتثبيت تلقائياً...',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                    fontFamily: 'Almarai',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_errorMessage != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _openInBrowser,
                                  child: const Text(
                                    'تنزيل يدوي',
                                    style: TextStyle(fontSize: 13.5, fontFamily: 'Almarai'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryNavy,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _startUpdate,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 20),
                                      SizedBox(width: 6),
                                      Text(
                                        'إعادة المحاولة',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Almarai',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              if (!isMandatory) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      widget.onDismiss();
                                    },
                                    child: const Text(
                                      'لاحقاً',
                                      style: TextStyle(fontSize: 14, fontFamily: 'Almarai'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                flex: isMandatory ? 1 : 2,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryNavy,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _startUpdate,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.download_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'تحديث التطبيق الآن',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Almarai',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
