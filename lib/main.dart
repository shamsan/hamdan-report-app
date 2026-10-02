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

/// شاشة بداية وتهيئة هادئة تمنع وميض أو تبديل الشاشات عند أول إقلاع
class ReportCraftSplashScreen extends StatelessWidget {
  const ReportCraftSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // الشعار المؤسسي
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFFBEB),
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFFDE68A), width: 2),
                ),
              ),
              child: const Icon(
                Icons.solar_power_rounded,
                size: 42,
                color: AppTheme.solarGold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ReportCraft',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryNavy,
                letterSpacing: 0.5,
                fontFamily: 'Almarai',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'المنظومة الاحترافية لإدارة وتوثيق صيانة محطات الطاقة الشمسية',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                fontFamily: 'Almarai',
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
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
      ),
    );
  }
}

