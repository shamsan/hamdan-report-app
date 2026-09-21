import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/responsive_layout.dart';
import '../models/report.dart';
import '../state/branding_provider.dart';
import '../state/reports_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'reports/reports_list_screen.dart';
import 'clients/clients_list_screen.dart';
import 'branding/branding_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(brandingProvider);
    final reports = ref.watch(reportsProvider);
    final isWideScreen = !ResponsiveLayout.isMobile(context);
    final draftCount = reports.where((r) => r.status == ReportStatus.draft).length;

    final screens = [
      DashboardScreen(onNavigateTab: _onTabTapped),
      const ReportsListScreen(),
      const ClientsListScreen(),
      const BrandingScreen(),
      const SettingsScreen(),
    ];

    final navItems = [
      (Icons.dashboard_outlined, Icons.dashboard, 'لوحة التحكم', 0),
      (Icons.description_outlined, Icons.description, 'التقارير', draftCount),
      (Icons.business_outlined, Icons.business, 'العملاء والمواقع', 0),
      (Icons.verified_user_outlined, Icons.verified_user, 'الهوية والشعارات', 0),
      (Icons.settings_outlined, Icons.settings, 'الإعدادات', 0),
    ];

    if (isWideScreen) {
      // Tablet and Desktop: Side Navigation Rail
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTapped,
              extended: ResponsiveLayout.isDesktop(context),
              minExtendedWidth: 220,
              backgroundColor: AppTheme.secondaryNavy,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.solarGold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.solar_power, color: Colors.white, size: 22),
                    ),
                    if (ResponsiveLayout.isDesktop(context)) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              branding.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'ReportCraft Enterprise',
                              style: TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              destinations: navItems.map((item) {
                final count = item.$4;
                return NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    backgroundColor: AppTheme.solarGold,
                    textColor: Colors.white,
                    label: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    child: Icon(item.$1),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: count > 0,
                    backgroundColor: AppTheme.solarGold,
                    textColor: Colors.white,
                    label: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    child: Icon(item.$2),
                  ),
                  label: Text(item.$3),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppTheme.borderSubtle),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: Bottom Navigation Bar with Android SafeArea & Elevated Container
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: navItems.map((item) {
              final count = item.$4;
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: AppTheme.solarGold,
                  textColor: Colors.white,
                  label: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  child: Icon(item.$1),
                ),
                selectedIcon: Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: AppTheme.solarGold,
                  textColor: Colors.white,
                  label: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  child: Icon(item.$2),
                ),
                label: item.$3,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
