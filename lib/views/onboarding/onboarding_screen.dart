import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../main_navigation_shell.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isFromSettings;

  const OnboardingScreen({super.key, this.isFromSettings = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingStep> _steps = const [
    OnboardingStep(
      title: 'منظومة إدارة تقارير الصيانة الفنية',
      subtitle: 'النموذج المعتمد رسمياً (UNOPS / MOH - 11 صفحة)',
      description: 'أهلاً بك في ReportCraft! تطبيقك المتكامل لتعبئة واعتماد وتصدير تقارير الصيانة الدورية الميدانية لمنظومات الطاقة الشمسية بمطابقة 100% للوثائق الرسمية وبدون إنترنت.',
      icon: Icons.solar_power_rounded,
      accentColor: AppTheme.solarGold,
      badgeText: 'النموذج المؤسسي المعتمد',
    ),
    OnboardingStep(
      title: 'تخصيص مواصفات المنظومة بدقة',
      subtitle: 'مجموعات البطاريات وصناديق التجميع الميدانية',
      description: 'حدد بدقة عدد مجموعات البطاريات (من 1 إلى 4 مجموعات) وصناديق التجميع المرتبطة بالمنظمات بحسب الواقع الفعلي للموقع، لتنعكس فقط الجداول النشطة في التقرير النهائي.',
      icon: Icons.tune_rounded,
      accentColor: AppTheme.brandCyan,
      badgeText: 'مرونة هندسية كاملة',
    ),
    OnboardingStep(
      title: 'جلسات الفحص التفاعلية الذكية',
      subtitle: 'قياسات تفصيلية وتوجيه خطوة بخطوة',
      description: 'استمتع بجلسة فحص ترشدك بنداً ببند مع تقييمات الجودة، تدوين قياسات الفولتية والمقاومة الداخلية، إدراج الملاحظات الطويلة مع التفاف تلقائي لأسفل، والتوقيع الرقمي المعتمد.',
      icon: Icons.fact_check_rounded,
      accentColor: Color(0xFF10B981),
      badgeText: 'حفظ فوري تلقائي',
    ),
    OnboardingStep(
      title: 'استنساخ التقارير والأمان الاحتياطي',
      subtitle: 'سرعة في الزيارات الدورية ونسخ احتياطي متعدد',
      description: 'أنشئ تقريراً جديداً بنقرة واحدة استناداً لتقرير سابق دون إعادة إدخال المواصفات، وصدّر نسخاً احتياطية مشفرة محلياً أو شاركها عبر WhatsApp وGoogle Drive لحماية تامة.',
      icon: Icons.cloud_sync_rounded,
      accentColor: AppTheme.primaryNavy,
      badgeText: 'أعلى معايير الأمان',
    ),
  ];

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

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _steps.length - 1;

    return Scaffold(
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
          if (!isLastPage)
            TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                'تخطي',
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
            // PageView Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Decorative Icon Badge
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: step.accentColor.withValues(alpha: 0.1),
                            border: Border.all(
                              color: step.accentColor.withValues(alpha: 0.25),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: step.accentColor.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            step.icon,
                            size: 52,
                            color: step.accentColor,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Badge Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: step.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            step.badgeText,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: step.accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryNavy,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          step.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textMuted,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots & Navigation Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Smooth Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (idx) {
                      final isSelected = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isSelected
                              ? AppTheme.primaryNavy
                              : AppTheme.borderSubtle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Action Buttons
                  Row(
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
                            backgroundColor: isLastPage ? AppTheme.solarGold : AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: isLastPage ? 3 : 1,
                          ),
                          icon: Icon(
                            isLastPage ? Icons.check_circle_outline_rounded : Icons.arrow_back_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isLastPage ? 'ابدأ استخدام التطبيق' : 'التالي',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String badgeText;

  const OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
  });
}
