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

        // 4. نموذج طلب التحديث الإجباري
        if (_activeUpdate != null)
          _buildUpdateModalOverlay(_activeUpdate!),
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
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
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

  // ══════════════════════════════════════════════════════════════
  // نافذة التحديث الإجباري (FORCE_UPDATE Modal Overlay)
  // ══════════════════════════════════════════════════════════════
  Widget _buildUpdateModalOverlay(ForceUpdateUIEvent event) {
    return PopScope(
      canPop: !event.isMandatory,
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
                          color: AppTheme.statusAcceptableBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.system_update_rounded, color: AppTheme.brandCyan, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'تحديث هام متاح (${event.version})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.releaseNotes ?? 'يتوفر إصدار جديد يتضمن ترقيات وإصلاحات أمنية معتمدة.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (!event.isMandatory) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _activeUpdate = null);
                                },
                                child: const Text('لاحقاً'),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                              onPressed: () {
                                setState(() => _activeUpdate = null);
                              },
                              child: const Text('حسناً', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
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
