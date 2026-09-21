import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:report_craft/core/utils/arabic_reshaper.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test dynamic width wrapping', () async {
    final fontData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) {
          final pdfFont = ttf.getFont(context);
          const availableWidth = 538.0;
          const fontSize = 9.5;

          // Test with sample report
          final report = DefaultTemplates.sampleDialysisReport;
          final facNameAr = report.facilityInfo.facilityName;
          final contractorAr = 'شركة بندر ناجي ابو زيد و اخوانة';
          final installDateDisplay = '            ';
          final funderSuffixAr = '، والممول من البنك الدولي عبر مكتب الأمم المتحدة لخدمات المشاريع (UNOPS).';
          final fullStatementAr = 'تؤكد إدارة $facNameAr أن مندوب $contractorAr قام بزيارة الموقع للصيانة الوقائية الدورية لمنظومة الطاقة الشمسية المركبة بتاريخ ($installDateDisplay). وخلال هذه الزيارة قاموا بإتمام كافة أعمال الصيانة الوقائية اللازمة لمنظومة الطاقة الشمسية$funderSuffixAr';

          final wrapped = PdfExportService.wrapArabicByWidth(fullStatementAr, availableWidth, fontSize, pdfFont);
          final lines = wrapped.split('\n');
          expect(lines.length, equals(3));
          for (final line in lines) {
            final size = pdfFont.stringMetrics(line).size;
            final widthAtSize = size.x * fontSize;
            expect(widthAtSize, lessThanOrEqualTo(availableWidth));
          }

          // Test with longer facility name (where text previously broke after وأخوانة)
          final longFacName = 'مركز الغسيل الكلوي بهيئة مستشفى الثورة العام بمحافظة الحديدة';
          final statementLong = 'تؤكد إدارة $longFacName أن مندوب $contractorAr قام بزيارة الموقع للصيانة الوقائية الدورية لمنظومة الطاقة الشمسية المركبة بتاريخ ($installDateDisplay). وخلال هذه الزيارة قاموا بإتمام كافة أعمال الصيانة الوقائية اللازمة لمنظومة الطاقة الشمسية$funderSuffixAr';
          final wrappedLong = PdfExportService.wrapArabicByWidth(statementLong, availableWidth, fontSize, pdfFont);
          final linesLong = wrappedLong.split('\n');
          expect(linesLong.length, equals(3));
          for (final line in linesLong) {
            final size = pdfFont.stringMetrics(line).size;
            final widthAtSize = size.x * fontSize;
            expect(widthAtSize, lessThanOrEqualTo(availableWidth));
          }

          return pw.Text('ok');
        },
      ),
    );

    await doc.save();
  });

  test('Test visit number BiDi ordering', () {
    final strB = '( 1 ) : رقم الزيارة';
    final resB = ArabicReshaper.shapeAndBidi(strB);
    expect(resB.startsWith('ﺓﺭﺎﻳﺰﻟﺍ ﻢﻗﺭ'), isTrue);
    expect(resB.endsWith('( 1 )'), isTrue);
  });
}
