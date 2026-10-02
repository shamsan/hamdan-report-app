import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'services/storage_service.dart';
import 'state/branding_provider.dart';
import 'views/main_navigation_shell.dart';
import 'views/onboarding/onboarding_screen.dart';
import 'state/licensing_provider.dart';
import 'views/licensing/license_lock_screen.dart';
import 'views/licensing/command_ui_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // معالج أخطاء Flutter Framework العام
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    stderr.writeln('[ReportCraft] Framework Error: ${details.exception}\n${details.stack}');
  };

  // معالج الأخطاء غير المتزامنة
  PlatformDispatcher.instance.onError = (error, stack) {
    stderr.writeln('[ReportCraft] Async Runtime Error: $error\n$stack');
    return true;
  };

  // Widget خطأ آمن يمنع شاشة الخطأ الحمراء
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
              const SizedBox(height: 12),
              const Text(
                'حدث تنبيه أثناء عرض هذا الجزء',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                details.exceptionAsString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  };

  bool hasSeenOnboarding = false;
  try {
    await StorageService().init();
    final prefs = await SharedPreferences.getInstance();
    hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  } catch (e) {
    debugPrint('[ReportCraft] Storage init exception: $e');
  }

  runApp(
    ProviderScope(
      child: ReportCraftApp(hasSeenOnboarding: hasSeenOnboarding),
    ),
  );
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class ReportCraftApp extends ConsumerWidget {
  final bool hasSeenOnboarding;

  const ReportCraftApp({super.key, this.hasSeenOnboarding = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);
    final license = ref.watch(licensingProvider);
    final licenseReady = ref.watch(licenseReadyProvider);

    Widget homeWidget;
    // إذا كان التطبيق في مرحلة الفحص/التهيئة الأولية (1-2 ثانية عند أول تشغيل)
    // نعرض شاشة تهيئة هادئة موحدة لمنع وميض أو قفز الشاشات
    if (licenseReady.isLoading) {
      homeWidget = const ReportCraftSplashScreen();
    } else if (license.isLocked) {
      homeWidget = const LicenseLockScreen();
    } else {
      homeWidget = hasSeenOnboarding ? const MainNavigationShell() : const OnboardingScreen();
    }

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'منشئ التقارير الاحترافية - ReportCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(
        primaryColor:   branding.primaryColor,
        secondaryColor: branding.secondaryColor,
      ),
      themeMode: ThemeMode.light,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final locale = Localizations.maybeLocaleOf(context) ?? const Locale('ar');
        final isRtl = locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: LicensingCommandEventListener(
            child: child ?? const SizedBox(),
          ),
        );
      },
      home: homeWidget,
    );
  }
}

/// شاشة بداية وتهيئة هادئة واحترافية تمنع وميض الشاشات عند أول إقلاع
class ReportCraftSplashScreen extends StatelessWidget {
  const ReportCraftSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // خلفية ناعمة بتدرج خفيف جداً
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFF8FAFC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // الشعار المؤسسي المتطور مع ظلال ناعمة
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B3A60), Color(0xFF06223A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B3A60).withValues(alpha: 0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: AppTheme.solarGold.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.solarGold.withValues(alpha: 0.12),
                          ),
                        ),
                        const Icon(
                          Icons.solar_power_rounded,
                          size: 46,
                          color: AppTheme.solarGold,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // اسم التطبيق
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ReportCraft',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryNavy,
                          letterSpacing: 0.5,
                          fontFamily: 'Almarai',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.solarGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⚡',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // الشعار الوصفي داخل بادج أنيق
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'المنظومة الاحترافية لإدارة وتوثيق صيانة محطات الطاقة الشمسية',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        fontFamily: 'Almarai',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 42),
                  // مؤشر التحميل المتطور
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryNavy),
                      backgroundColor: Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.solarGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'جاري تهيئة بيئة العمل الميدانية...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Almarai',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // تذييل الصفحة الرسمي
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'ReportCraft Enterprise • الإصدار الميداني المعتمد',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

