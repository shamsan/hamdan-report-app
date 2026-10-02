import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:report_craft/main.dart';
import 'package:report_craft/views/onboarding/onboarding_screen.dart';
import 'package:report_craft/views/main_navigation_shell.dart';
import 'package:report_craft/state/licensing_provider.dart';

void main() {
  testWidgets('App launches OnboardingScreen on first launch', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licenseReadyProvider.overrideWith((ref) => Future.value()),
        ],
        child: const ReportCraftApp(hasSeenOnboarding: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('مرحباً بك في ReportCraft'), findsOneWidget);
  });

  testWidgets('App launches MainNavigationShell when onboarding has been seen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          licenseReadyProvider.overrideWith((ref) => Future.value()),
        ],
        child: const ReportCraftApp(hasSeenOnboarding: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MainNavigationShell), findsOneWidget);
  });
}
