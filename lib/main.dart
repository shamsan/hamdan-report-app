import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'services/storage_service.dart';
import 'state/branding_provider.dart';
import 'state/theme_provider.dart';
import 'views/main_navigation_shell.dart';
import 'views/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // معالج أخطاء Flutter Framework العام
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[ReportCraft] Framework Error: ${details.exceptionAsString()}');
  };

  // معالج الأخطاء غير المتزامنة
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[ReportCraft] Async Runtime Error: $error');
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

class ReportCraftApp extends ConsumerWidget {
  final bool hasSeenOnboarding;

  const ReportCraftApp({super.key, this.hasSeenOnboarding = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding   = ref.watch(brandingProvider);
    final themeMode  = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'منشئ التقارير الاحترافية - ReportCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(
        primaryColor:   branding.primaryColor,
        secondaryColor: branding.secondaryColor,
      ),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
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
          child: child ?? const SizedBox(),
        );
      },
      home: hasSeenOnboarding ? const MainNavigationShell() : const OnboardingScreen(),
    );
  }
}
