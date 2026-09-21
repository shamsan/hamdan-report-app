import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/yemen_locations.dart';
import '../../state/branding_provider.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../state/reports_provider.dart';
import '../../models/client.dart';
import '../../models/site.dart';
import '../../models/report.dart'; // For SystemSpecs
import '../main_navigation_shell.dart';
import '../session/maintenance_session_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final bool isFromSettings;

  const OnboardingScreen({super.key, this.isFromSettings = false});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Step 2 Data
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companySubTitleController = TextEditingController();

  // Step 3 Data
  final GlobalKey<FormState> _clientFormKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController();
  String _clientType = 'جهة حكومية / وزارة';
  final TextEditingController _clientContactController = TextEditingController();
  Client? _createdClient;

  // Step 4 Data
  final GlobalKey<FormState> _siteFormKey = GlobalKey<FormState>();
  final TextEditingController _siteNameController = TextEditingController();
  String? _selectedGov;
  String? _selectedDir;
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _systemTypeController = TextEditingController();
  Site? _createdSite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(brandingProvider);
      _companyNameController.text = profile.name;
      _companySubTitleController.text = profile.subTitle;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _companyNameController.dispose();
    _companySubTitleController.dispose();
    _clientNameController.dispose();
    _clientContactController.dispose();
    _siteNameController.dispose();
    _capacityController.dispose();
    _systemTypeController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

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

  void _nextPage() async {
    if (_currentPage == 1) {
      // Save company identity
      final profile = ref.read(brandingProvider);
      ref.read(brandingProvider.notifier).updateProfile(
        profile.copyWith(
          name: _companyNameController.text.isNotEmpty ? _companyNameController.text : null,
          subTitle: _companySubTitleController.text,
        ),
      );
    } else if (_currentPage == 2) {
      // Save client
      if (_clientNameController.text.isNotEmpty) {
        if (_clientFormKey.currentState?.validate() ?? false) {
          _createdClient = await ref.read(clientsProvider.notifier).addClient(
            nameAr: _clientNameController.text,
            clientType: _clientType,
            contactPerson: _clientContactController.text,
          );
        } else {
          return; // Validation failed
        }
      }
    } else if (_currentPage == 3) {
      // Save site
      if (_siteNameController.text.isNotEmpty && _createdClient != null) {
        if (_siteFormKey.currentState?.validate() ?? false) {
          _createdSite = await ref.read(sitesProvider.notifier).addSite(
            clientId: _createdClient!.id,
            nameAr: _siteNameController.text,
            governorate: _selectedGov ?? '',
            directorate: _selectedDir ?? '',
            systemSpecs: SystemSpecs(
              capacityKw: _capacityController.text,
              systemType: _systemTypeController.text,
            ),
          );
        } else {
          return; // Validation failed
        }
      }
    }

    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isFromSettings || _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentPage > 0) {
          _previousPage();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isFromSettings
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textDark),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (_currentPage > 0 && _currentPage < 4)
            TextButton(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                );
              },
              child: const Text(
                'تخطي — سأعد لاحقاً',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (idx) {
                  final isSelected = idx == _currentPage;
                  final isPast = idx < _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isSelected ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isSelected
                          ? AppTheme.primaryNavy
                          : (isPast ? AppTheme.primaryNavy.withValues(alpha: 0.5) : AppTheme.borderSubtle),
                    ),
                  );
                }),
              ),
            ),
            
            // PageView Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildStep1Welcome(),
                  _buildStep2Company(),
                  _buildStep3Client(),
                  _buildStep4Site(),
                  _buildStep5Summary(),
                ],
              ),
            ),

            // Navigation Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  if (_currentPage > 0) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.borderSubtle),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _previousPage,
                      child: const Text('السابق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage == 4 ? AppTheme.solarGold : AppTheme.primaryNavy,
                        foregroundColor: _currentPage == 4 ? AppTheme.textDark : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: _currentPage == 4 ? 3 : 1,
                      ),
                      icon: Icon(
                        _currentPage == 4 ? Icons.check_circle_outline_rounded : Icons.arrow_back_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _currentPage == 0 ? 'ابدأ الإعداد' : (_currentPage == 4 ? 'ادخل إلى التطبيق' : 'التالي'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: _nextPage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStep1Welcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.solarGold.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.solarGold.withValues(alpha: 0.25),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.solarGold.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.solar_power_rounded,
              size: 52,
              color: AppTheme.solarGold,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'مرحباً بك في ReportCraft',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryNavy,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'تطبيقك المتكامل لإدارة تقارير صيانة منظومات الطاقة الشمسية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'سنساعدك في إعداد بياناتك خلال دقائق معدودة لتبدأ عملك الميداني فوراً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.textMuted,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Company() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'هوية الشركة / المكتب الهندسي',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 8),
          const Text(
            'هذه البيانات ستظهر في كل تقرير تُصدره',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'اسم المكتب / الشركة',
              prefixIcon: Icon(Icons.business_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companySubTitleController,
            decoration: const InputDecoration(
              labelText: 'المسمى الفرعي (اختياري)',
              prefixIcon: Icon(Icons.subtitles_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryNavy, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يمكنك تعديل هذه البيانات لاحقاً من إعدادات الهوية',
                    style: TextStyle(fontSize: 12, color: AppTheme.primaryNavy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Client() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _clientFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أضف أول عميل / جهة مالكة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 8),
            const Text(
              'الجهة المالكة للمواقع التي تخدمها',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _clientNameController,
              decoration: const InputDecoration(
                labelText: 'اسم الجهة بالعربي *',
                prefixIcon: Icon(Icons.account_balance_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'يرجى إدخال اسم الجهة';
                return null;
              },
            ),
            const SizedBox(height: 16),
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
                prefixIcon: Icon(Icons.category_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientContactController,
              decoration: const InputDecoration(
                labelText: 'شخص التواصل (اختياري)',
                prefixIcon: Icon(Icons.person_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Site() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _siteFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أضف أول موقع / منشأة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 8),
            Text(
              _createdClient != null 
                  ? 'الموقع التابع لـ ${_createdClient!.nameAr}'
                  : 'أضف منشأة أو موقعاً ميدانياً',
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            if (_createdClient == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.solarGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.solarGold.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.solarGold, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تنبيه: تخطيت خطوة العميل. يمكنك إضافة الموقع لكن يفضل ربطه بعميل أولاً لضمان ترابط البيانات.',
                        style: TextStyle(fontSize: 12, color: AppTheme.primaryNavy),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextFormField(
              controller: _siteNameController,
              decoration: const InputDecoration(
                labelText: 'اسم المنشأة بالعربي *',
                prefixIcon: Icon(Icons.location_on_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (_createdClient == null) return null;
                if (val == null || val.trim().isEmpty) return 'يرجى إدخال اسم المنشأة';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedGov,
              items: YemenLocations.governorates
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: _createdClient == null ? null : (val) {
                setState(() {
                  _selectedGov = val;
                  _selectedDir = null; // Reset
                });
              },
              decoration: const InputDecoration(
                labelText: 'المحافظة',
                prefixIcon: Icon(Icons.map_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedDir,
              items: YemenLocations.getDistrictsFor(_selectedGov)
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: _createdClient == null ? null : (val) {
                setState(() => _selectedDir = val);
              },
              decoration: const InputDecoration(
                labelText: 'المديرية',
                prefixIcon: Icon(Icons.place_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(
                labelText: 'القدرة الإجمالية (kW)',
                hintText: 'مثال: 15.5 kW',
                prefixIcon: Icon(Icons.bolt_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _systemTypeController,
              decoration: const InputDecoration(
                labelText: 'نوع المنظومة',
                hintText: 'مثال: هجينة منفصلة عن الشبكة (Off-Grid)',
                prefixIcon: Icon(Icons.solar_power_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep5Summary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.statusGood.withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.celebration_rounded, color: AppTheme.statusGood, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'أنت جاهز تماماً! 🎉',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 8),
          const Text(
            'تم إعداد البيانات الأولية بنجاح، ويمكنك الآن البدء في إنشاء وإدارة تقاريرك',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(
            title: 'هوية الشركة / المكتب',
            value: _companyNameController.text.trim().isEmpty ? 'الاسم الافتراضي' : _companyNameController.text.trim(),
            icon: Icons.business_rounded,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            title: 'العميل الأول',
            value: _createdClient?.nameAr ?? 'تم التخطي',
            icon: Icons.account_balance_rounded,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            title: 'الموقع الأول',
            value: _createdSite?.nameAr ?? 'تم التخطي',
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 32),
          if (_createdClient != null && _createdSite != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandCyan,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text(
                'أو ابدأ أول زيارة صيانة الآن',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('has_seen_onboarding', true);
                if (!mounted) return;
                
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
                    builder: (_) => MaintenanceSessionScreen(
                      reportId: newReport.id,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required IconData icon}) {
    final isSkipped = value.contains('تخطي');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSkipped ? Colors.grey.shade50 : AppTheme.solarGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSkipped ? Colors.grey.shade300 : AppTheme.solarGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSkipped ? Icons.skip_next_rounded : Icons.check_circle_rounded,
            color: isSkipped ? Colors.grey : AppTheme.solarGold,
          ),
          const SizedBox(width: 12),
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSkipped ? Colors.grey : AppTheme.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: isSkipped ? Colors.grey.shade400 : AppTheme.primaryNavy.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}
