import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/core/theme/app_theme.dart';
import 'package:report_craft/models/inspection_item.dart';
import 'package:report_craft/views/editor/widgets/inspection_table_widget.dart';

void main() {
  testWidgets('InspectionTableWidget renders all chips and items cleanly without errors', (tester) async {
    final group = InspectionGroup(
      id: 'group_test_1',
      groupNumber: 1,
      title: 'نموذج فحص الألواح الشمسية والقواعد الحديدية',
      items: [
        InspectionItem(
          id: 'item_1',
          serialNo: 1,
          description: 'فحص الهيكل الحامل وتثبيت القواعد',
          status: InspectionStatus.good,
          notes: 'سليم 100%',
        ),
        InspectionItem(
          id: 'item_2',
          serialNo: 2,
          description: 'فحص الأسلاك وتأريض الألواح',
          status: InspectionStatus.needsFollowup,
          notes: 'يحتاج متابعة',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: InspectionTableWidget(
              group: group,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify group title and items are rendered
    expect(find.text('نموذج فحص الألواح الشمسية والقواعد الحديدية'), findsOneWidget);
    expect(find.text('فحص الهيكل الحامل وتثبيت القواعد'), findsOneWidget);
    expect(find.text('صف شرائح الجمل السريعة للجدول:'), findsOneWidget);
  });
}
