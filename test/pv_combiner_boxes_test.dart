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

      // Check header and progress (4 out of 8 completed = 50%)
      expect(find.text('قياسات سلاسل الألواح والصناديق'), findsOneWidget);
      expect(find.text('4 من 8 سلسلة تم قياسها بالكامل'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      // Check Box Selector Chips
      expect(find.text('صندوق #1'), findsOneWidget);
      expect(find.text('صندوق #2'), findsOneWidget);
      expect(find.text('4 / 4 سلاسل'), findsOneWidget);
      expect(find.text('0 / 4 سلاسل'), findsOneWidget);

      // Check Active Box Card for Box 1
      expect(find.text('صندوق التجميع #1'), findsOneWidget);
      expect(find.text('السلاسل: 1 إلى 4'), findsOneWidget);
      expect(find.text('مكتمل'), findsOneWidget);

      // Check strings #1 to #4 rendered
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);

      // Tap on Box #2 chip to switch focus
      await tester.tap(find.text('صندوق #2'));
      await tester.pumpAndSettle();

      // Box 2 card should now be active
      expect(find.text('صندوق التجميع #2'), findsOneWidget);
      expect(find.text('السلاسل: 5 إلى 8'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);
      expect(find.text('#6'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('#8'), findsOneWidget);
    });

    testWidgets('Toggles collapsible Telemetry/KPIs accordion', (tester) async {
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

      // Telemetry header visible
      expect(find.text('ملخص مؤشرات أداء السلاسل'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('ملخص مؤشرات أداء السلاسل'));
      await tester.pumpAndSettle();

      // KPIs now visible in expanded child
      expect(find.text('متوسط Voc'), findsOneWidget);
      expect(find.text('متوسط Isc'), findsOneWidget);
      expect(find.text('السلاسل المكتملة'), findsOneWidget);
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

      // Both Box 1 and Box 2 cards should be visible simultaneously
      expect(find.text('صندوق التجميع #1'), findsOneWidget);
      expect(find.text('صندوق التجميع #2'), findsOneWidget);
    });

    testWidgets('Auto-fills typical values when clicking typical fill button', (tester) async {
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

      // Tap on typical auto-fill icon
      await tester.tap(find.byIcon(Icons.auto_fix_high_rounded));
      await tester.pumpAndSettle();

      expect(updatedReport, isNotNull);
      // All 8 strings should now have Voc and Isc > 0
      final nonZero = updatedReport!.stringMeasurements.where((s) => s.openCircuitVoltageVoc > 0 && s.shortCircuitCurrentIsc > 0).length;
      expect(nonZero, greaterThanOrEqualTo(8));
    });
  });
}
