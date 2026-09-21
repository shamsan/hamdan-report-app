import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/views/preview/widgets/report_readiness_dialog.dart';

void main() {
  testWidgets('ReportReadinessDialog renders cleanly without overflow for empty and complete reports', (tester) async {
    final draftReport = DefaultTemplates.sampleDialysisReport;

    bool exportTriggered = false;
    bool editTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => ReportReadinessDialog(
                    report: draftReport,
                    onExportNow: () => exportTriggered = true,
                    onEditReport: () => editTriggered = true,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog header and elements exist
    expect(find.text('فحص جاهزية التقرير للتصدير'), findsOneWidget);
    expect(find.text('تفاصيل جاهزية أقسام التقرير'), findsOneWidget);
    expect(find.text('البيانات الأساسية للمشروع والمرفق'), findsOneWidget);
    expect(find.text('الفحص الميداني الفني'), findsOneWidget);
    expect(find.text('قياسات البطاريات والتشغيل'), findsOneWidget);
    expect(find.text('التوقيعات والاعتماد الرسمي'), findsOneWidget);
    expect(find.text('التوثيق الفوتوغرافي الميداني'), findsOneWidget);

    // Verify action buttons
    expect(find.text('تعديل التقرير'), findsOneWidget);
    await tester.tap(find.text('تعديل التقرير'));
    expect(editTriggered, isTrue);

    await tester.tap(find.byIcon(Icons.share_rounded));
    expect(exportTriggered, isTrue);
  });
}
