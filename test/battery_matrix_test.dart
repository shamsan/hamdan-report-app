import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/models/measurement_data.dart';
import 'package:report_craft/models/report.dart';
import 'package:report_craft/models/signature_data.dart';
import 'package:report_craft/views/editor/widgets/battery_matrix_widget.dart';

void main() {
  group('BatteryMeasurement Model Tests', () {
    test('Model fields, serialization, and deserialization without temperature or internalResistance', () {
      const measurement = BatteryMeasurement(
        cellNumber: 5,
        stringNumber: 1,
        voltage: 2.16,
        boltTorque: 12.5,
        notes: 'سليمة',
      );

      expect(measurement.cellNumber, 5);
      expect(measurement.stringNumber, 1);
      expect(measurement.voltage, 2.16);
      expect(measurement.boltTorque, 12.5);
      expect(measurement.notes, 'سليمة');

      final json = measurement.toJson();
      expect(json.containsKey('temperature'), isFalse);
      expect(json.containsKey('internalResistance'), isFalse);
      expect(json['voltage'], 2.16);
      expect(json['boltTorque'], 12.5);
      expect(json['notes'], 'سليمة');

      final deserialized = BatteryMeasurement.fromJson(json);
      expect(deserialized.cellNumber, 5);
      expect(deserialized.voltage, 2.16);
      expect(deserialized.boltTorque, 12.5);
      expect(deserialized.notes, 'سليمة');
    });

    test('copyWith updates fields cleanly', () {
      const orig = BatteryMeasurement(cellNumber: 1, voltage: 2.10, boltTorque: 10.0);
      final updated = orig.copyWith(voltage: 2.15, boltTorque: 12.0, notes: 'فحص دوري');

      expect(updated.voltage, 2.15);
      expect(updated.boltTorque, 12.0);
      expect(updated.notes, 'فحص دوري');
      expect(updated.cellNumber, 1);
    });
  });

  group('Report Active Groups Completion Ratio Tests', () {
    test('completionRatio accurately respects activeBatteryGroups', () {
      final now = DateTime.now();
      // Report with only Group 1 active (24 cells)
      final report = Report(
        id: 'rep_test',
        templateId: 'tmpl',
        title: 'تقرير فحص',
        reportNumber: 'REP-01',
        contractNumber: 'CNT-01',
        visitDate: '2026/09/24',
        projectInfo: const ProjectInfo(projectName: 'مشروع الطاقة'),
        facilityInfo: const FacilityInfo(facilityName: 'مستشفى الأمل'),
        systemSpecs: const SystemSpecs(),
        inspectionGroups: const [],
        batteryMeasurements: List.generate(96, (i) {
          final isGroup1 = i < 24;
          return BatteryMeasurement(
            cellNumber: i + 1,
            stringNumber: (i ~/ 24) + 1,
            voltage: isGroup1 ? 2.15 : 0.0,
          );
        }),
        operationalData: const [],
        stringMeasurements: const [],
        correctiveActions: const [],
        photos: const [],
        signatures: const [],
        approvalStatement: const ApprovalStatement(),
        attendanceList: const [],
        activeBatteryGroups: const [1], // Only Group 1 is active
        createdAt: now,
        updatedAt: now,
      );

      // Phase 3 incomplete count should be 0 because all 24 cells of active Group 1 have voltage > 0
      expect(report.phase3IncompleteCount, 0);

      // completionRatio should give full earned points for battery measurements (10 points)
      expect(report.completionRatio, greaterThan(0.5));
    });
  });

  group('BatteryMatrixWidget UI & Progressive Disclosure Tests', () {
    testWidgets('Renders progressive disclosure headers and toggles stats', (tester) async {
      final measurements = List.generate(96, (i) => BatteryMeasurement(
        cellNumber: i + 1,
        stringNumber: (i ~/ 24) + 1,
        voltage: i < 12 ? 2.15 : 0.0,
        boltTorque: i < 12 ? 12.0 : 0.0,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BatteryMatrixWidget(
                measurements: measurements,
                activeGroups: const [1, 2],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and progress
      expect(find.text('المجموعة 1'), findsWidgets);
      expect(find.text('12 من 24 خلية تم قياسها'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      // Verify Stats header is present (collapsed by default)
      expect(find.text('ملخص الإحصائيات (12 خلية مقاسة)'), findsOneWidget);

      // Tap to expand stats
      await tester.tap(find.text('ملخص الإحصائيات (12 خلية مقاسة)'));
      await tester.pumpAndSettle();

      // Stats content should now be visible
      expect(find.text('↓ أقل جهد'), findsOneWidget);
      expect(find.text('↑ أعلى جهد'), findsOneWidget);

      // Verify Quick Action bar is present (collapsed by default)
      expect(find.text('تعبئة سريعة — المجموعة 1'), findsOneWidget);

      // Tap to expand quick actions
      await tester.tap(find.text('تعبئة سريعة — المجموعة 1'));
      await tester.pumpAndSettle();

      // Quick chips should now be visible
      expect(find.text('2.15V'), findsWidgets);
      expect(find.text('واقعي (2V) ±0.01'), findsOneWidget);

      // Verify table headers and tabs
      expect(find.text('الجهد (V)'), findsWidgets);
      expect(find.text('العزم (N.m)'), findsWidgets);
      expect(find.text('الملاحظات'), findsWidgets);
    });
  });
}
