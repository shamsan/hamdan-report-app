/**
 * ══════════════════════════════════════════════════════════════
 *  License Lock Screen (Full Barrier & Enhanced UX)
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  شاشة القفل الصارم للتطبيق مع دعم اللصق، مسح الـ QR، والمشاركة عبر واتساب، ومتابعة الطلبات
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/licensing/security/hardware_fingerprint.dart';
import '../../core/licensing/utils/license_whatsapp_helper.dart';
import '../../core/licensing/engine/license_models.dart';
import '../../core/theme/app_theme.dart';
import '../../state/licensing_provider.dart';
import 'license_request_sheet.dart';
import 'pending_request_banner.dart';
import 'qr_license_scanner_sheet.dart';

class LicenseLockScreen extends ConsumerStatefulWidget {
  const LicenseLockScreen({super.key});

  @override
  ConsumerState<LicenseLockScreen> createState() => _LicenseLockScreenState();
}

class _LicenseLockScreenState extends ConsumerState<LicenseLockScreen> {
  final _keyController = TextEditingController();
  bool _isActivating = false;
  bool _isSyncing = false;
  bool _isRequestingTrial = false;
  String? _errorMessage;
  String? _hwid;

  @override
  void initState() {
    super.initState();
    _loadHwid();
  }

  Future<void> _loadHwid() async {
    final id = await HardwareFingerprint.getCompositeHwid();
    if (mounted) setState(() => _hwid = id);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() {
        _keyController.text = text;
        _errorMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم لصق المفتاح من الحافظة'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _handleScanQr() async {
    final scannedKey = await QrLicenseScannerSheet.scan(context);
    if (scannedKey != null && scannedKey.trim().isNotEmpty) {
      setState(() {
        _keyController.text = scannedKey.trim();
        _errorMessage = null;
      });
      await _handleActivate();
    }
  }

  Future<void> _handleRequestTrial() async {
    setState(() {
      _isRequestingTrial = true;
      _errorMessage = null;
    });

    final res = await ref.read(licensingProvider.notifier).requestTrial();

    if (mounted) {
      setState(() => _isRequestingTrial = false);
      if (!res.success) {
        setState(() => _errorMessage = res.message ?? 'فشل طلب النسخة التجريبية. يرجى التأكد من توفر اتصال بالإنترنت.');
      }
    }
  }

  Future<void> _handleActivate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال مفتاح الترخيص أو مسح رمز QR.');
      return;
    }

    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    final res = await ref.read(licensingProvider.notifier).activate(key);

    if (mounted) {
      setState(() => _isActivating = false);
      if (!res.success) {
        setState(() => _errorMessage = res.message ?? 'فشل تفعيل الترخيص.');
      }
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final res = await ref.read(licensingProvider.notifier).syncNow();
    if (mounted) {
      setState(() => _isSyncing = false);
      if (res.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licensingProvider);

    // تفاصيل القفل حسب السبب
    IconData lockIcon = Icons.lock_outline_rounded;
    Color lockColor = AppTheme.statusRejected;
    String lockTitle = 'التطبيق مقفل ويطلب ترخيصاً';
    String lockDesc = license.message ?? 'يرجى تفعيل ترخيص صالح لمتابعة استخدام النظام.';

    switch (license.lockReason) {
      case LicenseLockReason.trialQuotaExceeded:
        lockIcon = Icons.inventory_2_outlined;
        lockColor = const Color(0xFFD97706);
        lockTitle = 'استنفاد حصة التقارير التجريبية (${license.maxReports} تقريراً)';
        lockDesc =
            'لقد أنجزت ${license.reportsUsed} تقريراً بنجاح في الفترة التجريبية. لمتابعة إنشاء وتصدير التقارير الهندسية بلا حدود، يرجى الترقية إلى النسخة الاحترافية (PRO).';
        break;
      case LicenseLockReason.trialTimeExpired:
        lockIcon = Icons.timer_off_outlined;
        lockColor = AppTheme.statusRejected;
        lockTitle = 'انتهت مهلة النسخة التجريبية';
        lockDesc =
            'انتهت فترة التجربة المتاحة على هذا الهاتف. يرجى تفعيل مفتاح ترخيص مدفوع لمتابعة العمل وتصدير التقارير.';
        break;
      case LicenseLockReason.paidExpired:
        lockIcon = Icons.event_busy_outlined;
        lockColor = AppTheme.statusRejected;
        lockTitle = 'انتهت صلاحية اشتراك الترخيص';
        lockDesc =
            'انتهت فترة اشتراكك الحالي. يرجى التواصل مع الإدارة للتجديد وإعادة التفعيل.';
        break;
      case LicenseLockReason.revoked:
        lockIcon = Icons.block_flipped;
        lockColor = AppTheme.statusRejected;
        lockTitle = 'تم إيقاف الترخيص مركزياً';
        lockDesc = license.suspensionReason != null && license.suspensionReason!.isNotEmpty
            ? license.suspensionReason!
            : 'تم إلغاء صلاحية هذا الترخيص من قبل إدارة النظام المركزية.';
        break;
      case LicenseLockReason.timeTampered:
        lockIcon = Icons.history_toggle_off_rounded;
        lockColor = AppTheme.statusRejected;
        lockTitle = 'كشف تلاعب بساعة وتاريخ النظام';
        lockDesc =
            'تم اكتشاف تأخير في ساعة الهاتف عن التوقيت المرجعي المعتمد. يرجى ضبط الساعة على الوضع التلقائي.';
        break;
      case LicenseLockReason.hwidMismatch:
        lockIcon = Icons.phonelink_erase_rounded;
        lockColor = const Color(0xFFD97706);
        lockTitle = 'الترخيص غير مسجل لهذا الهاتف';
        lockDesc =
            'تم اكتشاف ترخيص مخصص لجهاز سابق أو نسخة احتياطية. يمكنك تفعيل ترخيص جديد أو طلب نقل ترخيصك السابق لهذا الهاتف.';
        break;
      case LicenseLockReason.notRegistered:
        lockIcon = Icons.rocket_launch_rounded;
        lockColor = AppTheme.brandCyan;
        lockTitle = 'مرحباً بك في ReportCraft';
        lockDesc =
            'لم يتم تفعيل النسخة التجريبية بعد على هذا الهاتف. اضغط على زر بدء التجربة أدناه للحصول على التجربة المجانية والبدء فوراً.';
        break;
      default:
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF061A2B),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── 0. شريط متابعة الطلب المعلق إن وُجد ───
                  const PendingRequestBanner(isDark: true),

                  // ─── 1. أيقونة القفل ───
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: lockColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: lockColor.withValues(alpha: 0.4), width: 2),
                      ),
                      child: Icon(lockIcon, color: lockColor, size: 38),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── عنوان القفل ───
                  Text(
                    lockTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ─── نص التوضيح ───
                  Text(
                    lockDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ─── بطاقة التفعيل الرئيسية ───
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // أ) زر بدء التجربة / التحقق التلقائي
                        if (license.lockReason == LicenseLockReason.notRegistered ||
                            license.lockReason == LicenseLockReason.hwidMismatch) ...[
                          ElevatedButton.icon(
                            onPressed: _isRequestingTrial ? null : _handleRequestTrial,
                            icon: _isRequestingTrial
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.rocket_launch_rounded, size: 18),
                            label: Text(
                              _isRequestingTrial
                                  ? 'جاري التحقق والتفعيل...'
                                  : (license.lockReason == LicenseLockReason.hwidMismatch
                                      ? 'التحقق وتفعيل ترخيص هذا الهاتف الآن'
                                      : 'بدء الفترة التجريبية المجانية الآن'),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('أو تفعيل مفتاح ترخيص', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],

                        const Text(
                          'تفعيل مفتاح ترخيص',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // خطأ التفعيل إن وُجد
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // حقل إدخال المفتاح مع اللصق ومسح الـ QR
                        TextField(
                          controller: _keyController,
                          decoration: InputDecoration(
                            labelText: 'مفتاح الترخيص',
                            hintText: 'RC-XXXX-XXXX-XXXX-XXXX',
                            prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppTheme.primaryNavy, size: 20),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.content_paste_rounded, color: AppTheme.brandCyan, size: 20),
                                  tooltip: 'لصق من الحافظة',
                                  onPressed: _handlePaste,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryNavy, size: 22),
                                  tooltip: 'مسح رمز QR',
                                  onPressed: _handleScanQr,
                                ),
                              ],
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 12),

                        // زر التفعيل
                        ElevatedButton.icon(
                          onPressed: _isActivating ? null : _handleActivate,
                          icon: _isActivating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: Text(
                            _isActivating ? 'جاري التحقق من المفتاح...' : 'تفعيل الترخيص',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // زر طلب ترخيص جديد للإدارة
                        OutlinedButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (ctx) => const LicenseRequestSheet(),
                            );
                          },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('تقديم طلب ترخيص جديد للإدارة'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryNavy,
                            side: const BorderSide(color: AppTheme.primaryNavy),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),

                        // إذا كان السبب hwidMismatch: إضافة زر مخصص لنقل الترخيص السابق
                        if (license.lockReason == LicenseLockReason.hwidMismatch) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (ctx) => const LicenseRequestSheet(initialType: 'SERVICE_REQUEST'),
                              );
                            },
                            icon: const Icon(Icons.phonelink_setup_rounded, size: 16, color: Color(0xFFD97706)),
                            label: const Text(
                              'طلب نقل ترخيص سابق إلى هذا الهاتف',
                              style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD97706)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── بطاقة البصمة ومشاركة واتساب ───
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fingerprint, color: AppTheme.brandCyan, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'معرف هذا الجهاز (HWID):',
                                style: TextStyle(fontSize: 11.5, color: Colors.white70),
                              ),
                            ),
                            InkWell(
                              onTap: _hwid != null
                                  ? () {
                                      Clipboard.setData(ClipboardData(text: _hwid!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تم نسخ بصمة الجهاز'), duration: Duration(seconds: 1)),
                                      );
                                    }
                                  : null,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_rounded, color: AppTheme.brandCyan, size: 13),
                                    SizedBox(width: 4),
                                    Text('نسخ', style: TextStyle(color: AppTheme.brandCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _hwid ?? 'جاري القراءة...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // زر مشاركة عبر واتساب
                        ElevatedButton.icon(
                          onPressed: _hwid != null
                              ? () => LicenseWhatsAppHelper.shareViaWhatsApp(
                                    context,
                                    hwid: _hwid!,
                                    currentTier: license.tier,
                                    currentKey: license.licenseKey,
                                  )
                              : null,
                          icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                          label: const Text(
                            'مراسلة الإدارة ومشاركة البصمة عبر واتساب',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── زر المزامنة والفحص الفوري ───
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: _isSyncing ? null : _handleSync,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                            )
                          : const Icon(Icons.sync_rounded, color: Colors.white70, size: 16),
                      label: const Text(
                        'إعادة فحص حالة الترخيص مع الخادم',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
