import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:report_craft/services/preset_notes_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PresetNotesService - Built-in Contextual Defaults', () {
    test('Returns global common notes across questions', () {
      expect(PresetNotesService.globalCommonNotes, isNotEmpty);
      expect(PresetNotesService.globalCommonNotes.contains('سليم 100%'), isTrue);
      expect(PresetNotesService.globalCommonNotes.contains('يحتاج استبدال فوري'), isTrue);
    });

    test('Retrieves contextual notes matching PV panels and cleaning', () {
      final cleaningNotes = PresetNotesService.getContextualDefaults(
        questionId: 'pv_clean_01',
        description: 'فحص نظافة الألواح وخلوها من الأتربة',
      );
      expect(cleaningNotes, isNotEmpty);
      expect(cleaningNotes.any((n) => n.contains('تنظيف')), isTrue);

      final crackNotes = PresetNotesService.getContextualDefaults(
        questionId: 'pv_crack_01',
        description: 'فحص خلو الزجاج من أي كسور أو شروخ',
      );
      expect(crackNotes, isNotEmpty);
      expect(crackNotes.any((n) => n.contains('كسور')), isTrue);
    });

    test('Retrieves contextual notes for cables and trays', () {
      final cableNotes = PresetNotesService.getContextualDefaults(
        questionId: 'cable_01',
        description: 'حالة مسارات الكابلات والعوازل',
      );
      expect(cableNotes, isNotEmpty);
      expect(cableNotes.any((n) => n.contains('العوازل') || n.contains('كابل')), isTrue);
    });

    test('Combines contextual defaults and global notes in getNotesForQuestion', () async {
      final notes = await PresetNotesService.getNotesForQuestion(
        'pv_1',
        description: 'فحص الألواح',
      );
      expect(notes.contains('سليم 100%'), isTrue);
      expect(notes.isNotEmpty, isTrue);
    });
  });

  group('PresetNotesService - Custom User Preset Notes & Persistence', () {
    test('Allows engineer to add custom preset note and retrieve it', () async {
      const qId = 'item_pv_01';
      const customNote = 'تم فحص الموديل ومطابقة الكود الشريطي 550W بنجاح';

      // Initially no custom notes
      final initialCustom = await PresetNotesService.getCustomNotes(qId);
      expect(initialCustom, isEmpty);

      // Add custom note
      final added = await PresetNotesService.addCustomNote(qId, customNote);
      expect(added, isTrue);

      // Check custom notes
      final afterAdd = await PresetNotesService.getCustomNotes(qId);
      expect(afterAdd.length, 1);
      expect(afterAdd.first, customNote);
      expect(await PresetNotesService.isCustomNote(qId, customNote), isTrue);

      // Full question notes should contain custom note as the FIRST element
      final allNotes = await PresetNotesService.getNotesForQuestion(qId);
      expect(allNotes.first, customNote);
    });

    test('Prevents duplicate custom notes', () async {
      const qId = 'item_pv_02';
      const note = 'فحص العوازل بالأشعة الحرارية';

      await PresetNotesService.addCustomNote(qId, note);
      await PresetNotesService.addCustomNote(qId, note);

      final customNotes = await PresetNotesService.getCustomNotes(qId);
      expect(customNotes.length, 1);
    });

    test('Removes custom note cleanly', () async {
      const qId = 'item_inv_01';
      const note = 'مروحة التبريد تصدر صوتاً غير طبيعي';

      await PresetNotesService.addCustomNote(qId, note);
      expect(await PresetNotesService.isCustomNote(qId, note), isTrue);

      final removed = await PresetNotesService.removeCustomNote(qId, note);
      expect(removed, isTrue);
      expect(await PresetNotesService.isCustomNote(qId, note), isFalse);

      final remaining = await PresetNotesService.getCustomNotes(qId);
      expect(remaining.contains(note), isFalse);
    });

    test('Resets all custom notes for a question', () async {
      const qId = 'item_batt_01';
      await PresetNotesService.addCustomNote(qId, 'ملاحظة 1');
      await PresetNotesService.addCustomNote(qId, 'ملاحظة 2');

      expect((await PresetNotesService.getCustomNotes(qId)).length, 2);

      await PresetNotesService.resetQuestionNotes(qId);
      expect(await PresetNotesService.getCustomNotes(qId), isEmpty);
    });
  });
}
