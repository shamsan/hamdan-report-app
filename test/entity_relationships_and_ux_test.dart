import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:report_craft/models/site.dart';
import 'package:report_craft/models/report.dart';
import 'package:report_craft/state/sites_provider.dart';
import 'package:report_craft/state/reports_provider.dart';
import 'package:report_craft/services/storage_service.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/core/utils/breadcrumb_widget.dart';

class _FakeReportsNotifier extends ReportsNotifier {
  _FakeReportsNotifier(List<Report> initial) : super(StorageService.forTesting()) {
    state = initial;
  }

  @override
  Future<void> load() async {}
}

class _FakeSitesNotifier extends SitesNotifier {
  _FakeSitesNotifier(List<Site> initial) : super(StorageService.forTesting()) {
    state = initial;
  }

  @override
  Future<void> load() async {}
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Report Model Relational Integrity Tests', () {
    test('Report model enforces non-nullable clientId and siteId with default empty strings', () {
      final report = DefaultTemplates.sampleDialysisReport;
      final defaultRelational = report.copyWith(clientId: '', siteId: '');
      expect(defaultRelational.clientId, '');
      expect(defaultRelational.siteId, '');

      final populated = report.copyWith(
        clientId: 'client_101',
        siteId: 'site_202',
      );
      expect(populated.clientId, 'client_101');
      expect(populated.siteId, 'site_202');
    });

    test('Report serialization and deserialization preserves clientId and siteId', () {
      final report = DefaultTemplates.sampleDialysisReport.copyWith(
        id: 'rep_1',
        clientId: 'client_alpha',
        siteId: 'site_beta',
        visitNumber: '3',
      );

      final json = report.toJson();
      expect(json['clientId'], 'client_alpha');
      expect(json['siteId'], 'site_beta');

      final reconstructed = Report.fromJson(json);
      expect(reconstructed.clientId, 'client_alpha');
      expect(reconstructed.siteId, 'site_beta');
    });

    test('Report.fromJson safely defaults missing clientId and siteId to empty string', () {
      final legacyJson = DefaultTemplates.sampleDialysisReport.toJson();
      legacyJson.remove('clientId');
      legacyJson.remove('siteId');

      final report = Report.fromJson(legacyJson);
      expect(report.clientId, '');
      expect(report.siteId, '');
    });
  });

  group('Derived Relational Providers Tests', () {
    final siteA1 = Site(
      id: 's_a1',
      clientId: 'c_a',
      nameAr: 'مركز عبس الطبي',
      governorate: 'حجة',
      directorate: 'عبس',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final siteA2 = Site(
      id: 's_a2',
      clientId: 'c_a',
      nameAr: 'مستشفى حجة العام',
      governorate: 'حجة',
      directorate: 'المدينة',
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    );

    final report1 = DefaultTemplates.sampleDialysisReport.copyWith(
      id: 'r_1',
      clientId: 'c_a',
      siteId: 's_a1',
      visitNumber: '1',
      visitDate: '2026/02/01',
      status: ReportStatus.completed,
      updatedAt: DateTime(2026, 2, 1),
      facilityInfo: const FacilityInfo(facilityName: 'مركز عبس الطبي', visitDate: '2026/02/01'),
    );

    final report2 = DefaultTemplates.sampleDialysisReport.copyWith(
      id: 'r_2',
      clientId: 'c_a',
      siteId: 's_a1',
      visitNumber: '2',
      visitDate: '2026/02/10',
      status: ReportStatus.draft,
      updatedAt: DateTime(2026, 2, 10),
      facilityInfo: const FacilityInfo(facilityName: 'مركز عبس الطبي', visitDate: '2026/02/10'),
    );

    test('reportsForClientProvider returns only reports belonging to the client', () {
      final container = ProviderContainer(
        overrides: [
          reportsProvider.overrideWith((ref) => _FakeReportsNotifier([report1, report2])),
        ],
      );

      final reports = container.read(reportsForClientProvider('c_a'));
      expect(reports.length, 2);

      final emptyReports = container.read(reportsForClientProvider('non_existent'));
      expect(emptyReports.isEmpty, true);
    });

    test('visitsForSiteProvider sorts visits by visitNumber descending', () {
      final container = ProviderContainer(
        overrides: [
          reportsProvider.overrideWith((ref) => _FakeReportsNotifier([report1, report2])),
        ],
      );

      final visits = container.read(visitsForSiteProvider('s_a1'));
      expect(visits.length, 2);
      expect(visits.first.visitNumber, '2');
      expect(visits.last.visitNumber, '1');
    });

    test('nextVisitNumberProvider automatically calculates the next sequence number', () {
      final container = ProviderContainer(
        overrides: [
          reportsProvider.overrideWith((ref) => _FakeReportsNotifier([report1, report2])),
        ],
      );

      final nextNum = container.read(nextVisitNumberProvider('s_a1'));
      expect(nextNum, 3);

      final brandNewSiteNextNum = container.read(nextVisitNumberProvider('s_new'));
      expect(brandNewSiteNextNum, 1);
    });

    test('clientStatsProvider computes accurate counts for sites, reports, and drafts', () {
      final container = ProviderContainer(
        overrides: [
          sitesProvider.overrideWith((ref) => _FakeSitesNotifier([siteA1, siteA2])),
          reportsProvider.overrideWith((ref) => _FakeReportsNotifier([report1, report2])),
        ],
      );

      final stats = container.read(clientStatsProvider('c_a'));
      expect(stats.sitesCount, 2);
      expect(stats.reportsCount, 2);
      expect(stats.completedReports, 1);
      expect(stats.draftReports, 1);
      expect(stats.lastVisitDate, '2026/02/10');
    });

    test('sitesGroupedByGovernorateProvider groups sites correctly by governorate', () {
      final container = ProviderContainer(
        overrides: [
          sitesProvider.overrideWith((ref) => _FakeSitesNotifier([siteA1, siteA2])),
        ],
      );

      final grouped = container.read(sitesGroupedByGovernorateProvider);
      expect(grouped.containsKey('حجة'), true);
      expect(grouped['حجة']!.length, 2);
    });
  });

  group('Breadcrumb & EmptyStateGuide UI Widget Tests', () {
    testWidgets('BreadcrumbBar renders navigation items and responds to taps', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(
              items: [
                BreadcrumbItem(
                  label: 'العملاء',
                  onTap: () {
                    tapped = true;
                  },
                ),
                const BreadcrumbItem(label: 'وزارة الصحة'),
                const BreadcrumbItem(label: 'مركز عبس'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('العملاء'), findsOneWidget);
      expect(find.text('وزارة الصحة'), findsOneWidget);
      expect(find.text('مركز عبس'), findsOneWidget);

      await tester.tap(find.text('العملاء'));
      expect(tapped, true);
    });

    testWidgets('EmptyStateGuide renders icon, title, description, and action button', (WidgetTester tester) async {
      bool actionClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateGuide(
              icon: Icons.domain_disabled_rounded,
              title: 'لا توجد مواقع مسجلة',
              description: 'قم بإضافة المنشأة أو المركز الميداني لبدء الزيارات',
              actionLabel: 'إضافة موقع جديد',
              onAction: () {
                actionClicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('لا توجد مواقع مسجلة'), findsOneWidget);
      expect(find.text('قم بإضافة المنشأة أو المركز الميداني لبدء الزيارات'), findsOneWidget);
      expect(find.text('إضافة موقع جديد'), findsOneWidget);

      await tester.tap(find.text('إضافة موقع جديد'));
      expect(actionClicked, true);
    });
  });
}
