/**
 * ══════════════════════════════════════════════════════════════
 *  License Barrier & Onboarding Handshake Screen
 *  ReportCraft Enterprise Mobile Security & FTUE
 * ══════════════════════════════════════════════════════════════
 *  شاشة تنشيط وإدارة الترخيص الميداني المتوافقة بنسبة 100% مع:
 *  - الوضع الفاتح عالي التباين تحت الشمس (Sunlight High Contrast)
 *  - شبكة الـ 8 بكسل وأهداف اللمس الميدانية (48x48dp)
 *  - تراتبية أزرار Material 3 الصارمة (Single FilledButton)
 *  - تجربة أول تشغيل استثنائية (First-Time User Experience)
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isRequestingTrial = false;
  bool _showKeyInputForNewUser = false; // كشف حقل المفتاح للمستخدمين الذين يملكون رخصة مسبقاً
  String? _errorMessage;

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
          const SnackBar(
            content: Text('تم لصق المفتاح من الحافظة بنجاح'),
            duration: Duration(seconds: 1),
          ),
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

  String _humanizeErrorMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'تعذر الاتصال بخادم التراخيص نظراً لعدم توفر اتصال بالإنترنت في الهاتف.\nيرجى التأكد من تشغيل الواي فاي أو بيانات الهاتف لبضع ثوانٍ وإعادة المحاولة.';
    }

    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection closed') ||
        lower.contains('connection reset') ||
        lower.contains('handshakeexception') ||
        lower.contains('os error') ||
        lower.contains('errno') ||
        lower.contains('httpexception') ||
        raw.contains('خطأ في الاتصال بالخادم')) {
      return 'تعذر الاتصال بخادم التراخيص نظراً لعدم توفر اتصال بالإنترنت في الهاتف.\nيرجى تشغيل الواي فاي أو بيانات الهاتف لبضع ثوانٍ لإتمام التفعيل، وبعدها سيعمل التطبيق في الميدان أوفلاين 100% دون إنترنت.';
    }

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'استغرق الاتصال بالخادم وقتاً أطول من المتوقع. يرجى التحقق من جودة الاتصال بالإنترنت والمحاولة مجدداً.';
    }

    return raw;
  }

  Future<void> _handleRequestTrial() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRequestingTrial = true;
      _errorMessage = null;
    });

    final res = await ref.read(licensingProvider.notifier).requestTrial();

    if (mounted) {
      setState(() => _isRequestingTrial = false);
      if (!res.success) {
        setState(() {
          _errorMessage = _humanizeErrorMessage(res.message);
        });
      }
    }
  }

  Future<void> _handleActivate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال مفتاح الترخيص أو مسح رمز QR.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    final res = await ref.read(licensingProvider.notifier).activate(key);

    if (mounted) {
      setState(() => _isActivating = false);
      if (!res.success) {
        setState(() => _errorMessage = _humanizeErrorMessage(res.message));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licensingProvider);
    final isFirstRun = license.lockReason == LicenseLockReason.notRegistered;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── 0. شريط متابعة الطلب المعلق إن وُجد ───
                  const PendingRequestBanner(isDark: false),
                  const SizedBox(height: 8),

                  // ─── 1. التبديل بين واجهة أول تشغيل وواجهة القفل الأخرى ───
                  if (isFirstRun)
                    _buildFirstRunWelcomeCard(license)
                  else
                    _buildStandardLockCard(license),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // واجهة أول تشغيل: استقبال شفاف، ذكي ومرحب (First Run FTUE)
  // ══════════════════════════════════════════════════════════════
  Widget _buildFirstRunWelcomeCard(LicenseInfo license) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // أيقونة شمسية مؤسسية مرحبة
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.solarGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.solarGold.withValues(alpha: 0.4), width: 2),
              ),
              child: const Icon(Icons.solar_power_rounded, color: AppTheme.solarGold, size: 36),
            ),
          ),
          const SizedBox(height: 16),

          // شارة النسخة التجريبية المعتمدة
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.statusGoodBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: Color(0xFF065F46)),
                  SizedBox(width: 6),
                  Text(
                    'فترة تجريبية معتمدة • 60 يوماً / 15 تقريراً',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                      fontFamily: 'Almarai',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // العنوان الرئيسي عالي التباين تحت الشمس
          const Text(
            'مرحباً بك في ReportCraft',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'المنظومة الاحترافية لإدارة وتوثيق صيانة محطات الطاقة الشمسية الميدانية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(height: 20),

          // بطاقة تفاصيل وضمانات الفترة التجريبية
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                _buildTrialFeatureItem(
                  icon: Icons.timer_outlined,
                  color: AppTheme.brandCyan,
                  title: 'مهلة تجريبية كاملة لمدة 60 يوماً',
                  desc: 'حرية كاملة لتقييم المنظومة في زياراتك الميدانية دون التزام مالي',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                _buildTrialFeatureItem(
                  icon: Icons.picture_as_pdf_outlined,
                  color: AppTheme.solarGold,
                  title: 'سقف 15 تقريراً هندسياً متكاملاً',
                  desc: 'تقارير رسمية شاملة (11 صفحة) مطابقة لمعايير المنظمات والمشاريع',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                _buildTrialFeatureItem(
                  icon: Icons.offline_bolt_outlined,
                  color: const Color(0xFF10B981),
                  title: 'جاهزية ميدانية أوفلاين 100%',
                  desc: 'كافة الفحوصات والقياسات والـ PDF تعمل في المواقع النائية بدون إنترنت',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // تنبيه الخطأ أو التوضيح إن وُجد (مثل غياب الإنترنت عند أول فتح)
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusFollowupBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: AppTheme.statusFollowup, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'يلزم الاتصال بالإنترنت لبضع ثوانٍ للتنشيط الأولي',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                            fontFamily: 'Almarai',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.45,
                            fontFamily: 'Almarai',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── زر التفعيل الرئيسي الوحيد (قاعدة زر الـ FilledButton الواحد) ───
          FilledButton.icon(
            onPressed: _isRequestingTrial ? null : _handleRequestTrial,
            icon: _isRequestingTrial
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.rocket_launch_rounded, size: 20),
            label: Text(
              _isRequestingTrial
                  ? 'جاري تنشيط النسخة التجريبية...'
                  : 'بدء الفترة التجريبية المجانية الآن',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai',
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          // ─── زر التبديل لمن يمتلك مفتاحاً مدفوعاً مسبقاً (Enterprise Direct) ───
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _showKeyInputForNewUser = !_showKeyInputForNewUser;
              });
            },
            icon: Icon(
              _showKeyInputForNewUser ? Icons.keyboard_arrow_up_rounded : Icons.vpn_key_outlined,
              size: 18,
            ),
            label: Text(
              _showKeyInputForNewUser
                  ? 'إخفاء خيار إدخال المفتاح'
                  : 'لديك مفتاح ترخيص مدفوع مسبقاً (PRO)؟',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai',
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryNavy,
              side: const BorderSide(color: AppTheme.borderMedium),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          // حقل إدخال المفتاح للمستخدم المباشر
          if (_showKeyInputForNewUser) ...[
            const SizedBox(height: 16),
            _buildKeyInputSection(),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // واجهة حالات القفل الأخرى (انتهاء الصلاحية / تعليق / تلاعب)
  // ══════════════════════════════════════════════════════════════
  Widget _buildStandardLockCard(LicenseInfo license) {
    IconData lockIcon = Icons.lock_outline_rounded;
    Color lockColor = AppTheme.statusRejected;
    Color lockBgColor = AppTheme.statusRejectedBg;
    String lockTitle = 'التطبيق مقفل ويطلب ترخيصاً';
    String lockDesc = license.message ?? 'يرجى تفعيل ترخيص صالح لمتابعة استخدام النظام.';

    switch (license.lockReason) {
      case LicenseLockReason.trialQuotaExceeded:
        lockIcon = Icons.inventory_2_outlined;
        lockColor = AppTheme.statusFollowup;
        lockBgColor = AppTheme.statusFollowupBg;
        lockTitle = 'استنفاد حصة التقارير التجريبية (${license.maxReports} تقريراً)';
        lockDesc =
            'لقد أنجزت ${license.reportsUsed} تقريراً بنجاح في الفترة التجريبية! كافة تقاريرك السابقة ومسوداتك محفوظة بأمان على جهازك. لمتابعة إنشاء وتصدير تقارير جديدة بلا حدود، يرجى الترقية إلى النسخة الاحترافية (PRO).';
        break;
      case LicenseLockReason.trialTimeExpired:
        lockIcon = Icons.timer_off_outlined;
        lockColor = AppTheme.statusRejected;
        lockBgColor = AppTheme.statusRejectedBg;
        lockTitle = 'انتهت مهلة النسخة التجريبية (${license.totalTrialDays} يوماً)';
        lockDesc =
            'انتهت فترة التجربة المتاحة على هذا الهاتف. بياناتك ومشاريعك السابقة محفوظة بأمان. يرجى تفعيل مفتاح ترخيص مدفوع لمتابعة إنشاء التقارير وتصديرها.';
        break;
      case LicenseLockReason.paidExpired:
        lockIcon = Icons.event_busy_outlined;
        lockColor = AppTheme.statusRejected;
        lockBgColor = AppTheme.statusRejectedBg;
        lockTitle = 'انتهت صلاحية اشتراك الترخيص';
        lockDesc =
            'انتهت فترة اشتراكك الحالي. يرجى التواصل مع الإدارة للتجديد ومواصلة العمل دون انقطاع.';
        break;
      case LicenseLockReason.revoked:
        lockIcon = Icons.block_flipped;
        lockColor = AppTheme.statusRejected;
        lockBgColor = AppTheme.statusRejectedBg;
        lockTitle = 'تم إيقاف الترخيص مركزياً';
        lockDesc = license.suspensionReason != null && license.suspensionReason!.isNotEmpty
            ? license.suspensionReason!
            : 'تم إلغاء صلاحية هذا الترخيص من قبل إدارة النظام المركزية.';
        break;
      case LicenseLockReason.timeTampered:
        lockIcon = Icons.history_toggle_off_rounded;
        lockColor = AppTheme.statusRejected;
        lockBgColor = AppTheme.statusRejectedBg;
        lockTitle = 'كشف تراجع في ساعة وتاريخ الهاتف';
        lockDesc =
            'تم اكتشاف تأخير في ساعة الهاتف عن التوقيت المرجعي المعتمد. يرجى ضبط الساعة على الوضع التلقائي (شبكة الاتصال) لمواصلة العمل.';
        break;
      case LicenseLockReason.hwidMismatch:
        lockIcon = Icons.phonelink_erase_rounded;
        lockColor = AppTheme.statusFollowup;
        lockBgColor = AppTheme.statusFollowupBg;
        lockTitle = 'الترخيص غير مسجل لهذا الهاتف';
        lockDesc =
            'تم اكتشاف ترخيص مخصص لجهاز سابق أو نسخة احتياطية. يمكنك تفعيل ترخيص جديد أو طلب نقل ترخيصك السابق إلى هذا الهاتف الجديد.';
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس شارة القفل
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: lockBgColor,
                shape: BoxShape.circle,
                border: Border.all(color: lockColor.withValues(alpha: 0.35), width: 2),
              ),
              child: Icon(lockIcon, color: lockColor, size: 34),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            lockTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textDark,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(height: 8),

          Text(
            lockDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppTheme.textSecondary,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(height: 24),

          // خطأ التفعيل إن وُجد
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.statusRejectedBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.statusRejected, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                        fontFamily: 'Almarai',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ─── حقل إدخال المفتاح والتفعيل ───
          _buildKeyInputSection(),

          const SizedBox(height: 12),

          // ─── زر تقديم طلب ترخيص جديد للإدارة ───
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
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
            label: const Text(
              'تقديم طلب ترخيص جديد للإدارة المركزية',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryNavy,
              side: const BorderSide(color: AppTheme.borderMedium),
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          // إذا كان السبب نقل جهاز (hwidMismatch)
          if (license.lockReason == LicenseLockReason.hwidMismatch) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
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
                style: TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Almarai',
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF59E0B)),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // مكون إدخال المفتاح المشترك مع اللصق ومسح الـ QR
  // ══════════════════════════════════════════════════════════════
  Widget _buildKeyInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
            ),
            filled: true,
            fillColor: AppTheme.surfaceLight,
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),

        // زر تفعيل المفتاح الممتلئ
        FilledButton.icon(
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Almarai',
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryNavy,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }



  Widget _buildTrialFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                  fontFamily: 'Almarai',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                  fontFamily: 'Almarai',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
