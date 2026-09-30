import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/models/measurement_data.dart';
import 'package:report_craft/models/report.dart';
import 'package:report_craft/models/signature_data.dart';
import 'package:report_craft/views/editor/widgets/pv_combiner_boxes_widget.dart';

void main() {
  Report createSampleReport({
    List<int> activeBoxes = const [1, 2],
    List<StringMeasurement>? strings,
  }) {
    final now = DateTime.now();
    return Report(
      id: 'rep_pv_test',
      templateId: 'tmpl',
      title: 'تقرير فحص شمسي',
      reportNumber: 'REP-PV-01',
      contractNumber: 'CNT-PV-01',
      visitDate: '2026/09/24',
      projectInfo: const ProjectInfo(projectName: 'مشروع الطاقة'),
      facilityInfo: const FacilityInfo(facilityName: 'مستشفى السلام'),
      systemSpecs: const SystemSpecs(),
      inspectionGroups: const [],
      batteryMeasurements: const [],
      operationalData: const [],
      stringMeasurements: strings ?? [
        // Box 1 strings (1..4)
        const StringMeasurement(stringNumber: 1, panelCount: 24, openCircuitVoltageVoc: 135.2, shortCircuitCurrentIsc: 8.4),
        const StringMeasurement(stringNumber: 2, panelCount: 24, openCircuitVoltageVoc: 135.5, shortCircuitCurrentIsc: 8.5),
        const StringMeasurement(stringNumber: 3, panelCount: 24, openCircuitVoltageVoc: 135.1, shortCircuitCurrentIsc: 8.3),
        const StringMeasurement(stringNumber: 4, panelCount: 24, openCircuitVoltageVoc: 135.4, shortCircuitCurrentIsc: 8.4),
        // Box 2 strings (5..8) unmeasured
        const StringMeasurement(stringNumber: 5, panelCount: 24, openCircuitVoltageVoc: 0, shortCircuitCurrentIsc: 0),
        const StringMeasurement(stringNumber: 6, panelCount: 24, openCircuitVoltageVoc: 0, shortCircuitCurrentIsc: 0),
        const StringMeasurement(stringNumber: 7, panelCount: 24, openCircuitVoltageVoc: 0, shortCircuitCurrentIsc: 0),
        const StringMeasurement(stringNumber: 8, panelCount: 24, openCircuitVoltageVoc: 0, shortCircuitCurrentIsc: 0),
      ],
      correctiveActions: const [],
      photos: const [],
      signatures: const [],
      approvalStatement: const ApprovalStatement(),
      attendanceList: const [],
      activeCombinerBoxes: activeBoxes,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('PvCombinerBoxesWidget UI & Responsive Tests', () {
    testWidgets('Renders header progress, box selector chips, and strings in Focus Mode', (tester) async {
      final report = createSampleReport();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PvCombinerBoxesWidget(
                report: report,
                onReportUpdated: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and progress
      expect(find.text('قياسات سلاسل وصناديق التجميع'), findsOneWidget);
      expect(find.text('2 صناديق نشطة • 8 سلسلة • 4 مقاسة'), findsOneWidget);

      // Check Box Selector Chips
      expect(find.text('صندوق #1'), findsWidgets);
      expect(find.text('صندوق #2'), findsWidgets);
      expect(find.text('(4/4)'), findsOneWidget);
      expect(find.text('(0/4)'), findsOneWidget);

      // Check strings #1 to #4 rendered
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);

      // Tap on Box #2 chip to switch focus
      await tester.tap(find.text('صندوق #2').first);
      await tester.pumpAndSettle();

      // Box 2 strings should now be active
      expect(find.text('#5'), findsOneWidget);
      expect(find.text('#6'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('#8'), findsOneWidget);
    });

    testWidgets('Switches to Overview Mode rendering all active boxes', (tester) async {
      final report = createSampleReport(activeBoxes: [1, 2]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PvCombinerBoxesWidget(
                report: report,
                onReportUpdated: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on overview mode icon
      await tester.tap(find.byIcon(Icons.view_agenda_outlined));
      await tester.pumpAndSettle();

      // In overview mode, strings of both boxes are rendered
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);
    });

    testWidgets('Auto-fills typical values via popup menu action', (tester) async {
      final report = createSampleReport();
      Report? updatedReport;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PvCombinerBoxesWidget(
                report: report,
                onReportUpdated: (r) => updatedReport = r,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open toolbar PopupMenuButton
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      // Tap fill standard
      await tester.tap(find.text('تعبئة نموذجية: ألواح قياسية 330W-350W'));
      await tester.pumpAndSettle();

      expect(updatedReport, isNotNull);
      // All 8 strings should now have Voc and Isc > 0
      final nonZero = updatedReport!.stringMeasurements.where((s) => s.openCircuitVoltageVoc > 0 && s.shortCircuitCurrentIsc > 0).length;
      expect(nonZero, greaterThanOrEqualTo(8));
    });
  });
}
