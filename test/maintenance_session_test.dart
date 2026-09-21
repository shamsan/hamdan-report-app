import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/models/inspection_item.dart';
import 'package:report_craft/models/report.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/views/session/models/session_question.dart';

void main() {
  group('Maintenance Session Models & Logic Tests', () {
    late Report testReport;

    setUp(() {
      testReport = DefaultTemplates.sampleDialysisReport;
    });

    test('buildList flattens all inspection items across all groups', () {
      final questions = SessionQuestion.buildList(testReport, {});
      final expectedTotal = testReport.inspectionGroups.fold<int>(
        0,
        (sum, g) => sum + g.items.length,
      );

      expect(questions.length, equals(expectedTotal));
      expect(questions.length, greaterThanOrEqualTo(100)); // ~123 items
      expect(questions.first.globalIndex, equals(0));
      expect(questions.last.globalIndex, equals(expectedTotal - 1));
    });

    test('Skip tracking correctly flags skipped questions as uninspected', () {
      final skipped = {0, 5, 12};
      final questions = SessionQuestion.buildList(testReport, skipped);

      expect(questions[0].isSkipped, isTrue);
      expect(questions[0].isInspected, isFalse);

      expect(questions[1].isSkipped, isFalse);

      expect(questions[5].isSkipped, isTrue);
      expect(questions[5].isInspected, isFalse);

      expect(questions[12].isSkipped, isTrue);
      expect(questions[12].isInspected, isFalse);
    });

    test('Strict completion requirement: incomplete if any item is uninspected or skipped', () {
      // Create a report where all items are uninspected
      final uninspectedGroups = testReport.inspectionGroups.map((group) {
        return group.copyWith(
          items: group.items.map((item) => item.copyWith(status: InspectionStatus.uninspected)).toList(),
        );
      }).toList();
      final freshReport = testReport.copyWith(inspectionGroups: uninspectedGroups);

      final initialQuestions = SessionQuestion.buildList(freshReport, {});
      final remainingInitial = initialQuestions.where((q) => !q.isInspected).toList();
      expect(remainingInitial.length, equals(initialQuestions.length));

      // Mark all items as good except 1
      final almostDoneGroups = testReport.inspectionGroups.map((group) {
        return group.copyWith(
          items: group.items.map((item) => item.copyWith(status: InspectionStatus.good)).toList(),
        );
      }).toList();

      final almostDoneReport = testReport.copyWith(inspectionGroups: almostDoneGroups);

      // Now all are marked good, but suppose index 3 was skipped
      final questionsWithSkip = SessionQuestion.buildList(almostDoneReport, {3});
      final remainingWithSkip = questionsWithSkip.where((q) => !q.isInspected).toList();
      expect(remainingWithSkip.length, equals(1));
      expect(remainingWithSkip.first.globalIndex, equals(3));

      // When skip is removed, all items are inspected (100% complete)
      final allDoneQuestions = SessionQuestion.buildList(almostDoneReport, {});
      final remainingDone = allDoneQuestions.where((q) => !q.isInspected).toList();
      expect(remainingDone.isEmpty, isTrue);

      final completedReport = almostDoneReport.copyWith(status: ReportStatus.completed);
      expect(completedReport.status, equals(ReportStatus.completed));
    });

    test('Evaluation statuses (good, acceptable, needsFollowup, rejected, notApplicable) are considered inspected', () {
      const sampleGroup = InspectionGroup(
        id: 'g_test',
        groupNumber: 1,
        title: 'مجموعة تجريبية',
        items: [
          InspectionItem(id: 'i1', serialNo: 1, description: 'بند 1', status: InspectionStatus.good),
          InspectionItem(id: 'i2', serialNo: 2, description: 'بند 2', status: InspectionStatus.acceptable),
          InspectionItem(id: 'i3', serialNo: 3, description: 'بند 3', status: InspectionStatus.needsFollowup),
          InspectionItem(id: 'i4', serialNo: 4, description: 'بند 4', status: InspectionStatus.rejected),
          InspectionItem(id: 'i5', serialNo: 5, description: 'بند 5', status: InspectionStatus.notApplicable),
          InspectionItem(id: 'i6', serialNo: 6, description: 'بند 6', status: InspectionStatus.uninspected),
        ],
      );

      final reportWithSample = testReport.copyWith(inspectionGroups: [sampleGroup]);
      final questions = SessionQuestion.buildList(reportWithSample, {});

      expect(questions[0].isInspected, isTrue); // good
      expect(questions[1].isInspected, isTrue); // acceptable
      expect(questions[2].isInspected, isTrue); // needsFollowup
      expect(questions[3].isInspected, isTrue); // rejected
      expect(questions[4].isInspected, isTrue); // notApplicable
      expect(questions[5].isInspected, isFalse); // uninspected
    });

    test('Group 4 and Group 7 have authentic subcategories for all items', () {
      final g4 = testReport.inspectionGroups.firstWhere((g) => g.groupNumber == 4);
      expect(g4.items.length, equals(42));
      for (final item in g4.items) {
        expect(item.subcategory, isNotNull);
        expect(item.subcategory!.trim().isNotEmpty, isTrue);
      }

      // Check the 6 distinct boxes in Group 4
      final g4Subcategories = g4.items.map((i) => i.subcategory).toSet();
      expect(g4Subcategories.length, equals(6));
      expect(g4Subcategories, contains('صندوق قواطع البطاريات "تيار مستمر"'));
      expect(g4Subcategories, contains('صندوق قواطع العاكس "تيار مستمر"'));
      expect(g4Subcategories, contains('صندوق تجميع كابلات التيار المستمر'));
      expect(g4Subcategories, contains('صندوق دمج وقواطع حماية التيار المتردد'));
      expect(g4Subcategories, contains('لوحة التوزيع الرئيسية'));
      expect(g4Subcategories, contains('مفتاح تبديل يدوي لمصدر الطاقة'));

      // Check the 3 systems in Group 7
      final g7 = testReport.inspectionGroups.firstWhere((g) => g.groupNumber == 7);
      expect(g7.items.length, equals(13));
      for (final item in g7.items) {
        expect(item.subcategory, isNotNull);
        expect(item.subcategory!.trim().isNotEmpty, isTrue);
      }
      final g7Subcategories = g7.items.map((i) => i.subcategory).toSet();
      expect(g7Subcategories.length, equals(3));
      expect(g7Subcategories, contains('نظام التهوية وتكييف الغرفة'));
      expect(g7Subcategories, contains('نظام إنذار ومكافحة الحرائق والسلامة'));
      expect(g7Subcategories, contains('نظام المراقبة والمتابعة'));
    });

    test('InspectionItem backward compatibility automatically resolves subcategories for legacy JSON', () {
      // Legacy JSON without 'subcategory' field
      final legacyJson = {
        'id': 'g4_10',
        'serialNo': 10,
        'description': 'ربط الكابلات داخل الصندوق',
        'status': 'good',
        'notes': 'مربوطة',
      };

      final item = InspectionItem.fromJson(legacyJson);
      expect(item.subcategory, equals('صندوق قواطع العاكس "تيار مستمر"'));

      // Group 7 legacy JSON
      final legacyJson7 = {
        'id': 'g7_5',
        'serialNo': 5,
        'description': 'مصدر الطاقة لحساس الدخان',
        'status': 'good',
        'notes': 'مشحونة',
      };
      final item7 = InspectionItem.fromJson(legacyJson7);
      expect(item7.subcategory, equals('نظام إنذار ومكافحة الحرائق والسلامة'));
    });

    test('Smart Skipped Navigation: jumping from question #5 directly to #20 then #30', () {
      // Build full question list
      final questions = SessionQuestion.buildList(testReport, {});
      final total = questions.length;
      expect(total, greaterThanOrEqualTo(100));

      // Scenario: Engineer skips scattered items: #5 (index 4), #20 (index 19), #30 (index 29)
      final skippedIndices = {4, 19, 29};
      final sessionQuestions = SessionQuestion.buildList(testReport, skippedIndices);

      // Helper simulating the smart next algorithm in MaintenanceSessionScreen
      int findNextTarget(int currentIndex, List<SessionQuestion> qs) {
        for (int i = currentIndex + 1; i < qs.length; i++) {
          if (!qs[i].isInspected) return i;
        }
        for (int i = 0; i < currentIndex; i++) {
          if (!qs[i].isInspected) return i;
        }
        return -1;
      }

      // 1. When at question #5 (index 4):
      // Question 6 (index 5) is already inspected!
      expect(sessionQuestions[5].isInspected, isTrue);

      // Finding next uninspected after index 4 must jump directly to #20 (index 19)!
      final nextFrom5 = findNextTarget(4, sessionQuestions);
      expect(nextFrom5, equals(19)); // Jumps straight to question #20!

      // 2. When at question #20 (index 19):
      // Questions 21..29 are already inspected!
      expect(sessionQuestions[20].isInspected, isTrue);

      // Finding next uninspected after index 19 must jump directly to #30 (index 29)!
      final nextFrom20 = findNextTarget(19, sessionQuestions);
      expect(nextFrom20, equals(29)); // Jumps straight to question #30!

      // 3. When question #30 (index 29) is completed:
      // Now all questions are completed!
      final allDone = SessionQuestion.buildList(testReport, {});
      final nextFrom30 = findNextTarget(29, allDone);
      expect(nextFrom30, equals(-1)); // Signals session completion dialog!
    });
  });
}
