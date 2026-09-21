import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/core/utils/arabic_reshaper.dart';

void main() {
  group('ArabicReshaper Tests', () {
    test('Empty string returns empty', () {
      expect(ArabicReshaper.reshape(''), '');
    });

    test('Reshapes standard Arabic word', () {
      final reshaped = ArabicReshaper.reshape('تقرير');
      expect(reshaped.isNotEmpty, true);
      // Ensure it transformed the initial Teh (0x062A -> 0xFE97)
      expect(reshaped.codeUnitAt(0), 0xFE97);
    });

    test('Handles Lam-Alef ligature', () {
      final reshaped = ArabicReshaper.reshape('لا');
      expect(reshaped.length, 1);
      expect(reshaped.codeUnitAt(0), 0xFEFB);
    });

    test('Visual ordering for bidi', () {
      final visual = ArabicReshaper.shapeAndBidi('تقرير 2025');
      expect(visual.isNotEmpty, true);
    });

    test('Strips tatweels and connects letters properly', () {
      final reshapedWithTatweel = ArabicReshaper.reshape('مكيـــــــــف');
      final reshapedNormal = ArabicReshaper.reshape('مكيف');
      expect(reshapedWithTatweel, reshapedNormal);

      final bidiWithTatweel = ArabicReshaper.shapeAndBidi('الفئـــــــــة');
      final bidiNormal = ArabicReshaper.shapeAndBidi('الفئة');
      expect(bidiWithTatweel, bidiNormal);
    });

    test('Preserves explicit newlines order downwards (Line 1 on top, Line 2 on bottom)', () {
      const line1 = 'السطر الأول من الملاحظة';
      const line2 = 'السطر الثاني من الملاحظة';
      final result = ArabicReshaper.shapeAndBidi('$line1\n$line2');
      final parts = result.split('\n');
      expect(parts.length, 2);
      // Line 1 must be first (top), Line 2 must be second (bottom)
      expect(parts[0], ArabicReshaper.shapeAndBidi(line1));
      expect(parts[1], ArabicReshaper.shapeAndBidi(line2));
    });

    test('Wraps long notes downwards by words without inverting lines', () {
      const longNote = 'تم فحص القاطع والتأكد من سلامة الكابلات وتم استبدال الفيوز التالف وإعادة التشغيل';
      final wrapped = ArabicReshaper.shapeAndBidi(longNote, maxCharsPerLine: 26);
      final lines = wrapped.split('\n');
      expect(lines.length > 1, true);

      // Verify that the first line contains the START of the sentence, not the end!
      final firstLineDecoded = lines[0];
      final expectedFirstWordShaped = ArabicReshaper.shapeAndBidi('تم');
      expect(firstLineDecoded.contains(expectedFirstWordShaped), true);

      // Verify that the last line contains the END of the sentence
      final lastLineDecoded = lines.last;
      final expectedLastWordShaped = ArabicReshaper.shapeAndBidi('التشغيل');
      expect(lastLineDecoded.contains(expectedLastWordShaped), true);
    });
  });
}
