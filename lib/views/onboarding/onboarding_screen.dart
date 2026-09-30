import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/yemen_locations.dart';
import '../../models/client.dart';
import '../../models/site.dart';
import '../../models/report.dart';
import '../../services/default_templates.dart';
import '../../state/branding_provider.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../state/reports_provider.dart';
import '../main_navigation_shell.dart';
import '../session/maintenance_session_screen.dart';
import '../editor/report_editor_screen.dart';
import '../../core/widgets/yemeni_phone_field.dart';

/// شاشة تهيئة التجربة الأولى للمستخدم (FTUE / Onboarding)
/// توفر تجربة سلسة متعددة المسارات:
/// 1. مسار سريع: استكشاف تقرير تجريبي 11 صفحة بضغطة زر واحدة (Aha! Moment).
/// 2. مسار مخصص: معالج ذكي من 3 خطوات متماسكة (الهوية والشعار، العميل والمنشأة معاً، وجاهزية الانطلاق).
/// 3. مسار الدخول المباشر: تخطي إلى لوحة التحكم مع توجيه إرشادي.
class OnboardingScreen extends ConsumerStatefulWidget {
  final bool isFromSettings;

  const OnboardingScreen({super.key, this.isFromSettings = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // حالة التحميل
  bool _isLoadingDemo = false;
  bool _isSubmitting = false;

  // بيانات الخطوة 1: الهوية والشعار
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companySubTitleController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _customLogoBase64;

  // بيانات الخطوة 2: العميل والمنشأة المتكاملة
  final GlobalKey<FormState> _integratedFormKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController();
  String _clientType = 'جهة حكومية / وزارة';
  final TextEditingController _clientContactController = TextEditingController();

  final TextEditingController _siteNameController = TextEditingController();
  String? _selectedGov = 'أمانة العاصمة';
  String? _selectedDir = 'السبعين';
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _systemTypeController = TextEditingController(text: 'منفصلة عن الشبكة (Off-Grid)');

  // الكائنات المنشأة في المعالج
  Client? _createdClient;
  Site? _createdSite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(brandingProvider);
      _companyNameController.text = profile.name.isNotEmpty
          ? profile.name
          : 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة';
      _companySubTitleController.text = profile.subTitle.isNotEmpty
          ? profile.subTitle
          : 'للخدمات الهندسية وحلول الطاقة';
      _phoneController.text = profile.contactPhone;
      _emailController.text = profile.contactEmail;
      _customLogoBase64 = profile.contractorLogoBase64;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _companyNameController.dispose();
    _companySubTitleController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _clientNameController.dispose();
    _clientContactController.dispose();
    _siteNameController.dispose();
    _capacityController.dispose();
    _systemTypeController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  void _goToStep(int step) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  // ─── المسار 1: تحميل التقرير التجريبي المتكامل فوراً ─────────────────────────────
  Future<void> _loadDemoReport() async {
    if (_isLoadingDemo) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoadingDemo = true);

    try {
      // 1. إنشاء العميل التجريبي إذا لم يكن موجوداً
      final client = await ref.read(clientsProvider.notifier).addClient(
        nameAr: 'وزارة الصحة العامة والسكان',
        nameEn: 'Ministry of Public Health & Population',
        clientType: 'جهة حكومية / وزارة',
        contactPerson: 'د. عبد الله أحمد - ممثل المرفق',
        phone: '777 123 456',
        notes: 'عميل افتراضي للتقرير التجريبي النموذجي',
      );

      // 2. إنشاء المنشأة التجريبية
      final site = await ref.read(sitesProvider.notifier).addSite(
        clientId: client.id,
        nameAr: 'مستشفى الثورة العام - مركز الغسيل الكلوي',
        nameEn: 'Al-Thawra General Hospital - Dialysis Center',
        governorate: 'صنعاء',
        directorate: 'السبعين',
        facilityType: 'مستشفى / مركز صحي',
        category: 'CAT 8',
        projectName: 'توريد وتركيب وصيانة 21 منظومة طاقة شمسية منفصلة عن الشبكة',
        contactPerson: 'د. عبد الله أحمد',
        phone: '777 123 456',
        systemSpecs: const SystemSpecs(
          systemType: 'منظومة طاقة شمسية منفصلة عن الشبكة Off-Grid',
          capacityKw: '57.6 kW',
          panelsCountAndWatt: '96 x 600Wp',
          invertersCapacity: '10KVA',
          invertersCount: '6',
          chargeControllersCapacity: '100 A (150-250) Vdc',
          chargeControllersCount: '13',
          batteryUnitsCapacity: '2500Ah',
          batteryUnitsCount: '96 x 2V',
          otherAppliances: 'مكيف هواء 1 طن عدد 2',
        ),
      );

      // 3. ربط التقرير النموذجي بالعميل والمنشأة
      final sampleReport = DefaultTemplates.sampleDialysisReport.copyWith(
        clientId: client.id,
        siteId: site.id,
        updatedAt: DateTime.now(),
      );
      await ref.read(reportsProvider.notifier).addReport(sampleReport);

      // 4. وضع علامة إتمام البداية
      await _markOnboardingComplete();

      if (!mounted) return;

      // 5. التوجيه المباشر لاستعراض التقرير
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportEditorScreen(reportId: sampleReport.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل التقرير التجريبي: $e'),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDemo = false);
    }
  }

  // ─── المسار 3: التخطي المباشر إلى لوحة التحكم ──────────────────────────────────
  Future<void> _skipToDashboard() async {
    HapticFeedback.lightImpact();
    await _markOnboardingComplete();
    if (!mounted) return;
    if (widget.isFromSettings) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    }
  }

  // ─── رفع الشعار ─────────────────────────────────────────────────────────────
  Future<void> _pickLogo() async {
    HapticFeedback.selectionClick();
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
        final b64 = base64Encode(res.files.first.bytes!);
        setState(() => _customLogoBase64 = b64);
        final cur = ref.read(brandingProvider);
        await ref.read(brandingProvider.notifier).updateProfile(
          cur.copyWith(contractorLogoBase64: b64),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحميل الشعار بنجاح ✅')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الشعار: $e')),
        );
      }
    }
  }

  // ─── حفظ بيانات الخطوة 1 ────────────────────────────────────────────────────
  Future<void> _saveStep1Company() async {
    final cur = ref.read(brandingProvider);
    await ref.read(brandingProvider.notifier).updateProfile(
      cur.copyWith(
        name: _companyNameController.text.trim().isNotEmpty
            ? _companyNameController.text.trim()
            : null,
        subTitle: _companySubTitleController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        contactEmail: _emailController.text.trim(),
        contractorLogoBase64: _customLogoBase64,
      ),
    );
    _goToStep(2);
  }

  // ─── حفظ بيانات الخطوة 2 (العميل والمنشأة معاً) ───────────────────────────────
  Future<void> _saveStep2ClientAndSite() async {
    final hasClientName = _clientNameController.text.trim().isNotEmpty;
    final hasSiteName = _siteNameController.text.trim().isNotEmpty;

    // إذا ملأ المستخدم أحدهما أو كلاهما، نتحقق من صحة النموذج
    if (hasClientName || hasSiteName) {
      if (!(_integratedFormKey.currentState?.validate() ?? false)) {
        return;
      }

      setState(() => _isSubmitting = true);
      try {
        // إنشاء العميل
        _createdClient = await ref.read(clientsProvider.notifier).addClient(
          nameAr: _clientNameController.text.trim(),
          clientType: _clientType,
          contactPerson: _clientContactController.text.trim(),
        );

        // إنشاء المنشأة وربطها بالعميل مباشرة
        _createdSite = await ref.read(sitesProvider.notifier).addSite(
          clientId: _createdClient!.id,
          nameAr: _siteNameController.text.trim(),
          governorate: _selectedGov ?? '',
          directorate: _selectedDir ?? '',
          systemSpecs: SystemSpecs(
            capacityKw: _capacityController.text.trim().isNotEmpty
                ? _capacityController.text.trim()
                : '15 kW',
            systemType: _systemTypeController.text.trim().isNotEmpty
                ? _systemTypeController.text.trim()
                : 'منفصلة عن الشبكة (Off-Grid)',
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء حفظ البيانات: $e')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }

    _goToStep(3);
  }

  // ─── بدء أول زيارة صيانة ميدانية ─────────────────────────────────────────────
  Future<void> _startFirstInspection() async {
    if (_createdClient == null || _createdSite == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      await _markOnboardingComplete();

      final newReport = await ref.read(reportsProvider.notifier).createReportForSite(
        site: _createdSite!,
        client: _createdClient!,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MaintenanceSessionScreen(reportId: newReport.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء جلسة الفحص: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isFromSettings || _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep > 0) {
          _goToStep(_currentStep - 1);
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(),
          body: SafeArea(
            child: Column(
              children: [
                // مؤشر الخطوات التفاعلي
                if (_currentStep > 0) _buildStepIndicator(),
                // محتوى الصفحات
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) => setState(() => _currentStep = idx),
                    children: [
                      _buildStep0HeroAndPathways(),
                      _buildStep1CompanyIdentity(),
                      _buildStep2IntegratedClientSite(),
                      _buildStep3ReadyLaunch(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: widget.isFromSettings
          ? IconButton(
              icon: const Icon(Icons.close_rounded, color: AppTheme.textDark),
              onPressed: () => Navigator.pop(context),
            )
          : (_currentStep > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.textDark),
                  onPressed: () => _goToStep(_currentStep - 1),
                  tooltip: 'رجوع',
                )
              : null),
      actions: [
        if (_currentStep == 0)
          TextButton.icon(
            onPressed: _skipToDashboard,
            icon: const Icon(Icons.dashboard_outlined, size: 16, color: AppTheme.textMuted),
            label: const Text(
              'الدخول المباشر',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
            ),
          )
        else if (_currentStep < 3)
          TextButton(
            onPressed: () => _goToStep(3),
            child: const Text(
              'تخطي الإعداد',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStepIndicator() {
    const totalWizardSteps = 3; // الخطوات 1، 2، 3
    final stepIndex = _currentStep - 1; // 0, 1, 2
    final stepTitles = ['الهوية والشعار', 'العميل والمنشأة', 'جاهزية الانطلاق'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalWizardSteps, (idx) {
              final isSelected = idx == stepIndex;
              final isPast = idx < stepIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSelected ? 32 : 10,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isSelected
                      ? AppTheme.primaryNavy
                      : (isPast ? AppTheme.solarGold : AppTheme.borderSubtle),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'الخطوة $_currentStep من 3: ${stepTitles[stepIndex.clamp(0, 2)]}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // الصفحة 0: الواجهة الترحيبية واختيار المسار (Hero & Pathways)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildStep0HeroAndPathways() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // الشعار والعنوان
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.solarGold.withValues(alpha: 0.15),
                  AppTheme.primaryNavy.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppTheme.solarGold.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.solarGold.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.solar_power_rounded,
              size: 46,
              color: AppTheme.solarGold,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'مرحباً بك في ReportCraft',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryNavy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'المنظومة الاحترافية لإدارة وتوثيق صيانة محطات الطاقة الشمسية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // شبكة المزايا الـ 4 الأساسية
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                _buildFeatureRow(
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFD32F2F),
                  title: 'تقارير مؤسسية معتمدة (11 صفحة)',
                  subtitle: 'مطابقة 1:1 لمعايير UNOPS ووزارة الصحة العامة',
                ),
                const Divider(height: 16, thickness: 0.6),
                _buildFeatureRow(
                  icon: Icons.offline_bolt_rounded,
                  color: AppTheme.solarGold,
                  title: 'فحص ميداني تفاعلي بدون إنترنت',
                  subtitle: 'توثيق فوري للقراءات والملاحظات والاحتياجات أوفلاين 100%',
                ),
                const Divider(height: 16, thickness: 0.6),
                _buildFeatureRow(
                  icon: Icons.battery_charging_full_rounded,
                  color: AppTheme.brandCyan,
                  title: 'مصفوفات قياس رقمية متقدمة',
                  subtitle: 'فحص تماثل خلايا البطاريات والمقاومة وقراءات الإنفرترات',
                ),
                const Divider(height: 16, thickness: 0.6),
                _buildFeatureRow(
                  icon: Icons.verified_user_rounded,
                  color: AppTheme.primaryNavy,
                  title: 'تصدير رسمي فوري مع الهوية والتواقيع',
                  subtitle: 'جاهز للمشاركة الفورية مع مدراء المشاريع والجهات الداعمة',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // خيارات المسار (Action Pathways)
          // 1. المسار السريع: استكشاف التقرير التجريبي (Hero Action)
          InkWell(
            onTap: _isLoadingDemo ? null : _loadDemoReport,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryNavy, Color(0xFF1E3C72)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.solarGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isLoadingDemo
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          )
                        : const Icon(Icons.rocket_launch_rounded, color: AppTheme.primaryNavy, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'تقرير تجريبي',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.solarGold,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'موصى به',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'نموذج مركز الغسيل الكلوي (11 صفحة مع الـ PDF)',
                          style: TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. المسار المخصص: معالج الإعداد
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryNavy,
              side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.tune_rounded, size: 20),
            label: const Text(
              'معالج الإعداد المخصص (3 خطوات)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _goToStep(1);
            },
          ),
          const SizedBox(height: 8),

          // 3. مسار التخطي المباشر
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _skipToDashboard();
            },
            child: const Text(
              'تخطي والدخول المباشر إلى لوحة التحكم',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // الخطوة 1: هوية المكتب الهندسي والشعار
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildStep1CompanyIdentity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'هوية المكتب الهندسي / المقاول',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'هذه البيانات وشعارك ستظهر رسمياً في ترويسة التقارير وصفحات التصدير',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // بطاقة الشعار التفاعلية
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.solarGold, width: 2),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _customLogoBase64 != null
                            ? Image.memory(
                                base64Decode(_customLogoBase64!),
                                fit: BoxFit.contain,
                              )
                            : Image.asset(
                                'assets/logos/logo_contractor.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.business_rounded,
                                  size: 48,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                      ),
                    ),
                    InkWell(
                      onTap: _pickLogo,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(
                    _customLogoBase64 != null ? 'تغيير صورة الشعار' : 'رفع شعار المكتب (PNG / JPG)',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // الحقول
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'اسم المكتب / الشركة *',
              hintText: 'مثال: مكتب الأتقان الهندسي للخدمات وحلول الطاقة',
              prefixIcon: Icon(Icons.business_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _companySubTitleController,
            decoration: const InputDecoration(
              labelText: 'المسمى الفرعي (اختياري)',
              hintText: 'مثال: للخدمات الهندسية وحلول الطاقة',
              prefixIcon: Icon(Icons.subtitles_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          YemeniPhoneField(
            controller: _phoneController,
            label: 'رقم هاتف التواصل المعتمد',
            hint: '777 123 456',
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني / العنوان',
              hintText: 'مثال: info@company.ye',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // أزرار التنقل
          Row(
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.borderSubtle),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _goToStep(0);
                },
                child: const Text('السابق', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'التالي: إضافة أول منشأة',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _saveStep1Company();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // الخطوة 2: العميل والمنشأة المتكاملة
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildStep2IntegratedClientSite() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Form(
        key: _integratedFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أضف أول عميل ومنشأة تخدمها',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ندمج إدخال العميل والمنشأة لضمان ترابط البيانات التام دون أي تعارض',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 18),

            // 1. بطاقة العميل / المالك
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.3)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_rounded, color: AppTheme.brandCyan, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '1. بيانات العميل / الجهة المالكة',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _clientNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الجهة أو الوزارة *',
                      hintText: 'مثال: وزارة الصحة العامة والسكان',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (_siteNameController.text.trim().isNotEmpty && (val == null || val.trim().isEmpty)) {
                        return 'يرجى إدخال اسم العميل لربطه بالمنشأة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _clientType,
                    items: ['جهة حكومية / وزارة', 'منظمة دولية', 'مؤسسة محلية', 'قطاع خاص']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _clientType = val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'نوع الجهة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clientContactController,
                    decoration: const InputDecoration(
                      labelText: 'شخص التواصل بالجهة (اختياري)',
                      hintText: 'مثال: د. عبد الله أحمد',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. بطاقة المنشأة / الموقع التابع
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.solarGold.withValues(alpha: 0.4)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: AppTheme.solarGold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '2. بيانات المنشأة / الموقع التابع',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _siteNameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنشأة أو المرفق *',
                      hintText: 'مثال: مستشفى الثورة العام - مركز الغسيل الكلوي',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (_clientNameController.text.trim().isNotEmpty && (val == null || val.trim().isEmpty)) {
                        return 'يرجى إدخال اسم المنشأة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedGov,
                          items: YemenLocations.governorates
                              .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedGov = val;
                              final dists = YemenLocations.getDistrictsFor(val);
                              _selectedDir = dists.isNotEmpty ? dists.first : null;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'المحافظة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDir,
                          items: YemenLocations.getDistrictsFor(_selectedGov)
                              .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedDir = val),
                          decoration: const InputDecoration(
                            labelText: 'المديرية',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _capacityController,
                          decoration: const InputDecoration(
                            labelText: 'القدرة (kW)',
                            hintText: 'مثال: 57.6 kW',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _systemTypeController,
                          decoration: const InputDecoration(
                            labelText: 'نوع المنظومة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // أزرار التنقل
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _goToStep(1);
                  },
                  child: const Text('السابق', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'جاري الحفظ...' : 'التالي: تأكيد الجاهزية',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _saveStep2ClientAndSite();
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // الخطوة 3: الجاهزية والانطلاق (Ready & Launch)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildStep3ReadyLaunch() {
    final hasEntity = _createdClient != null && _createdSite != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.statusGood.withValues(alpha: 0.12),
              border: Border.all(color: AppTheme.statusGood.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.celebration_rounded, color: AppTheme.statusGood, size: 42),
          ),
          const SizedBox(height: 16),
          const Text(
            'أنت جاهز تماماً للانطلاق! 🎉',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'تم إعداد بياناتك بنجاح، ويمكنك الآن البدء في تسجيل وتوثيق زيارات الصيانة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 24),

          // بطاقات الملخص
          _buildSummaryCard(
            title: 'هوية المكتب الهندسي',
            value: _companyNameController.text.trim().isNotEmpty
                ? _companyNameController.text.trim()
                : 'مكتب الأتقان الهندسي للخدمات الهندسية',
            icon: Icons.business_rounded,
            badge: _customLogoBase64 != null ? 'الشعار مرفوع ✅' : 'الشعار الافتراضي',
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            title: 'العميل والمنشأة الميدانية',
            value: hasEntity
                ? '${_createdSite!.nameAr} (${_createdClient!.nameAr})'
                : 'لم يتم الإضافة (يمكن إضافتها لاحقاً)',
            icon: Icons.location_on_rounded,
            badge: hasEntity ? '$_selectedGov - $_selectedDir' : null,
            isSkipped: !hasEntity,
          ),
          const SizedBox(height: 28),

          // أزرار الانطلاق
          if (hasEntity) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                _isSubmitting ? 'جاري التحضير...' : 'بدء أول زيارة صيانة ميدانية الآن 🚀',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _startFirstInspection();
                    },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryNavy,
                side: const BorderSide(color: AppTheme.primaryNavy),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text(
                'الانتقال إلى لوحة التحكم',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _skipToDashboard();
              },
            ),
          ] else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.dashboard_rounded, size: 20),
              label: const Text(
                'الدخول إلى لوحة التحكم 🚀',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                _skipToDashboard();
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryNavy,
                side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.rocket_launch_rounded, size: 18, color: AppTheme.solarGold),
              label: const Text(
                'أو استكشاف تقرير تجريبي جاهز (11 صفحة)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              onPressed: _isLoadingDemo
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      _loadDemoReport();
                    },
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    String? badge,
    bool isSkipped = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSkipped ? Colors.grey.shade50 : AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSkipped ? Colors.grey.shade300 : AppTheme.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSkipped
                  ? Colors.grey.shade200
                  : AppTheme.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isSkipped ? Colors.grey : AppTheme.primaryNavy,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSkipped ? Colors.grey : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isSkipped ? Colors.grey.shade600 : AppTheme.primaryNavy,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.solarGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            isSkipped ? Icons.skip_next_rounded : Icons.check_circle_rounded,
            color: isSkipped ? Colors.grey : AppTheme.statusGood,
          ),
        ],
      ),
    );
  }
}
