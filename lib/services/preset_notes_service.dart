import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing preset inspection notes for maintenance sessions and checklist items.
/// Provides contextual out-of-the-box professional notes per item/group,
/// and allows engineers to persist custom preset notes in advance.
class PresetNotesService {
  static const String _keyPrefix = 'preset_inspection_notes_v1_';

  // ─────────────────────────────────────────────────────────────────────────
  // Built-in Contextual Default Notes Database
  // ─────────────────────────────────────────────────────────────────────────

  /// Global common notes that apply across all questions
  static const List<String> globalCommonNotes = [
    'سليم 100%',
    'تم الفحص والمعاينة الميدانية',
    'لا توجد أي ملاحظات أو مشاكل',
    'تمت الصيانة الوقائية بالكامل',
    'يحتاج متابعة في الزيارة القادمة',
    'يحتاج استبدال فوري',
    'غير متوفر بالموقع (غير منطبق)',
  ];

  /// Contextual default notes tailored specifically to question types or groups
  static final Map<String, List<String>> _defaultNotesByPattern = {
    // 1. مصفوفة الألواح وقواعد التثبيت (PV Array)
    'كسور': [
      'سليمة 100% وخالية من أي كسور أو شروخ',
      'يوجد كسر سطحي في الزجاج لا يؤثر على الإنتاجية',
      'كسر كامل في الزجاج العلوي - يحتاج استبدال اللوح',
      'شروخ دقيقة ناتجة عن إجهاد حراري',
    ],
    'نظافة': [
      'تم التنظيف بالماء المقطر وأدوات مخصصة',
      'نظيفة وبحالة ممتازة',
      'تراكم أتربة خفيف - تم التنظيف أثناء الزيارة',
      'ترسبات طينية وأوساخ طيور مستعصية تم إزالتها',
      'تحتاج إلى تنظيف دوري مستمر',
    ],
    'تثبيت': [
      'مثبتة بإحكام بالبراغي المجلفنة',
      'تمت إعادة شد وإحكام براغي التثبيت بالكامل',
      'يوجد ارتخاء في بعض المرابط وتم شدها',
      'قواعد التثبيت مهترئة تحتاج تدعيم',
    ],
    'الوان': [
      'الخلايا سليمة واللون متجانس 100%',
      'لا يوجد أي تغير في ألوان الخلايا',
      'تغير طفيف في لون بعض الخلايا دون تأثير كبير',
      'وجود علامات حروق وتغير لون (Hot-Spots) على الخلايا',
    ],
    'الباك شيت': [
      'الباك شيت سليم وخالٍ من الخدوش والفقاعات',
      'لا يوجد أي تقشر أو انتفاخ في الطبقة الخلفية',
      'تآكل طفيف في العازل الخلفي لا يعرض للرطوبة',
      'تشققات في الباك شيت تستدعي عزل إضافي أو استبدال',
    ],
    'صندوق الربط': [
      'محكم الإغلاق ودرجة الحماية IP65 ممتازة',
      'الدايودات سليمة ولا توجد علامات تفحم',
      'تم فحص دايودات التمرير Bypass Diodes - تعمل بكفاءة',
      'الغطاء مكسور أو غير محكم ويحتاج تغيير',
    ],
    'MC4': [
      'معزولة ومحكمة الإغلاق ومحمية من الرطوبة',
      'تم فحص التوصيلات والتأكد من القفل الذاتي',
      'وجود تفحم أو ذوبان في موصل MC4 تم استبداله',
      'الموصلات غير أصلية ينصح باستبدالها بموصلات معتمدة',
    ],
    'ظل': [
      'المصفوفة خالية تماماً من أي تظليل طوال ساعات الذروة',
      'تظليل جزئي ناتج عن أشجار قريبة - تم إشعار الإدارة بتقليمها',
      'تظليل من مبنى مجاور في فترات الصباح الباكر فقط',
      'خالية من التظليل المباشر',
    ],
    'قواعد': [
      'هيكل حديدي مجلفن ممتاز ومقاوم للرياح',
      'مثبتة بالبراغي الخرسانية بإحكام',
      'خالية من الصدأ والتآكل',
      'ظهور صدأ سطحي خفيف - تم طلاؤه بمادة مانعة للصدأ',
      'الهيكل بحاجة إلى صيانة وطلاء وقائي',
    ],

    // 2. مسارات الكابلات وحواملها (Cables & Trays)
    'كابل تري': [
      'الكابل تري سليم ومحكم الإغلاق والأغطية مثبتة',
      'مثبت بالحوامل المعدنية بشكل صلب',
      'خالٍ من الصدأ والتآكل',
      'أغطية الكابل تري مفقودة في بعض الأجزاء - تم توثيقها',
      'تمت إعادة تثبيت وتربيط الكابل تري',
    ],
    'الكابلات': [
      'العوازل ممتازة ولا توجد تشققات أو اهتراء',
      'مرتبة ومنظمة ومربوطة برباطات مقاومة للشمس UV',
      'معزولة بالكامل ولا توجد أي كابلات مكشوفة',
      'لا يوجد أي تمديد عشوائي أو مستحدث',
      'تم عزل الكابلات المكشوفة بشريط عازل عالي الجودة',
    ],
    'جلاندات': [
      'الجلاندات مطاطية وسليمة ومحكمة العزل',
      'مانعة لتسرب المياه والغبار IP65',
      'تم شد الجلاندات وإحكام منافذ الدخول والخروج',
      'بعض الجلاندات تالفة وتحتاج استبدال بحجم مناسب',
    ],

    // 3. صناديق التجميع والقواطع (Combiner Boxes & Protection)
    'صناديق تجميع': [
      'مثبتة بجدار المبنى بثبات ممتاز ومحكمة الإغلاق',
      'نظيفة من الداخل وخالية من الغبار والحشرات والرطوبة',
      'اللاصق التحذيري وملصقات الجهد العالي موجودة وواضحة',
      'الصندوق مغلق ومقفل لحماية الأجهزة',
    ],
    'فيوزات': [
      'فيوزات التيار المستمر DC سليمة ومطابقة للقدرة المقننة',
      'قواعد الفيوزات معزولة وسليمة بدون أي آثار حرارة',
      'تم استبدال فيوز تالف بفيوز أصلي من نفس السعة',
      'جهد الفيوزات متوازن عبر جميع السلاسل',
    ],
    'حرارة القواطع': [
      'حرارة القواطع طبيعية (بين 24°C - 30°C) بكاشف حراري',
      'لا يوجد أي ارتفاع غير طبيعي في درجات الحرارة',
      'ارتفاع ملحوظ في حرارة القاطع (تجاوز 55°C) - تم فحص الحمل والشد',
      'الحرارة مستقرة ومتناسبة مع الحمل الفعلي',
    ],
    'ربط الكابلات': [
      'مربوطة بإحكام بعزم الشد الموصى به (Torque Tightened)',
      'تمت إعادة شد جميع المسامير ونقاط التوصيل',
      'لا يوجد أي ارتخاء في نقاط الربط',
      'تم وضع علامات الشد على مسامير القواطع',
    ],
    'البزبار': [
      'البزبار النحاسي سليم ومعزول بالكامل',
      'نقاط التوصيل نظيفة وخالية من الأكسدة',
      'العزل الحراري والكهربائي للبزبار ممتاز',
    ],
    'مانع الصواعق': [
      'مانع الصواعق SPD سليم (المؤشر أخضر)',
      'توصيل التأريض لمانع الصواعق متصل ومحكم',
      'مانع الصواعق محترق (المؤشر أحمر) ويحتاج تغيير فوري',
    ],

    // 4. محطة العواكس (Inverters)
    'العواكس': [
      'العاكس يعمل بكفاءة وشاشات القراءة تعمل بوضوح',
      'صوت مراوح التبريد طبيعي وخالٍ من الضوضاء',
      'تم تنظيف فلاتر الهواء ومداخل التهوية',
      'لا توجد رسائل خطأ أو تحذيرات في سجل الأعطال',
      'تم تسجيل قراءات الفولتية والتيار والقدرة ومطابقتها',
      'العاكس مفصول بسبب عطل - تم فحصه وتوثيقه',
    ],

    // 5. منظمات الشحن (Charge Controllers)
    'منظمات الشحن': [
      'جهد وتيار الشحن ضمن الحدود التصميمية للمنظومة',
      'إضاءات الحالة (LEDs) وشاشة القراءة تعمل بصورة ممتازة',
      'مرحلة الشحن الحالية (Bulk / Absorption / Float) طبيعية',
      'تم فحص التوصيلات وتنظيف مشتت الحرارة الخارجي',
    ],

    // 6. بنك البطاريات (Battery Bank)
    'البطاريات': [
      'جهد الخلايا متطابق ومستقر عبر السلاسل',
      'سوائل الخلايا عند المستوى المطلوب بين Min و Max',
      'تم تنظيف الأقطاب والتشحيم بفازلين صناعي مانع للتملح',
      'خالية من أي انتفاخ أو تسريب أو تشوه في الهيكل',
      'تم فحص الكثافة النوعية للإلكتروليت - ممتازة',
      'وجود ترسبات ملحية على الأقطاب - تم تنظيفها وإعادة الشد',
      'حرارة بنك البطاريات ممتازة (25°C)',
    ],
    'تكييف': [
      'مكيف غرفة البطاريات يعمل بكفاءة ودرجة الحرارة مضبوطة 25°C',
      'تم تنظيف فلاتر المكيف وفحص تصريف المياه',
      'المكيف متوقف أو به عطل - يلزم صيانة فورية لحماية البطاريات',
    ],

    // 7. التأريض والحماية (Earthing)
    'التأريض': [
      'مقاومة التأريض ممتازة وأقل من 5 أوم',
      'كابل التأريض الرئيسي متصل بإحكام ومربوط بالبارة',
      'مانعة الصواعق الهوائية سليمة ومثبتة في أعلى نقطة',
      'تم فحص استمرارية التوصيل الأرضي لجميع الهياكل والمعدات',
      'نقطة التأريض تحتاج تزويد بأملاح وفحم لتحسين التوصيل',
    ],

    // 8. البيئة المحيطة والغرفة (Environment & Room)
    'الغرفة': [
      'غرفة الطاقة نظيفة ومرتبة ومحكمة ضد القوارض والغبار',
      'التهوية طبيعية وممتازة',
      'طفايات الحريق (CO2) متوفرة وسارية الصلاحية',
      'إنارة الغرفة تعمل بشكل سليم',
      'لوحة تعليمات السلامة وخطة الطوارئ معلقة وواضحة',
    ],
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Normalizes a question key (uses ID or description)
  static String normalizeKey(String questionId, {String? description}) {
    final cleanId = questionId.trim();
    if (cleanId.isNotEmpty) return cleanId;
    return (description ?? '').trim();
  }

  /// Retrieves combined preset notes for a given question item:
  /// 1. Custom notes added by the user/engineer for this question.
  /// 2. Contextual default notes matching this question's topic.
  /// 3. General global notes.
  /// Returned list is unique, trimmed, and ordered (custom first).
  static Future<List<String>> getNotesForQuestion(
    String questionId, {
    String? subcategory,
    String? description,
  }) async {
    final customNotes = await getCustomNotes(questionId, description: description);
    final contextualDefaults = getContextualDefaults(
      questionId: questionId,
      subcategory: subcategory,
      description: description,
    );

    final result = <String>[];
    final seen = <String>{};

    void addNote(String n) {
      final trimmed = n.trim();
      if (trimmed.isNotEmpty && !seen.contains(trimmed)) {
        seen.add(trimmed);
        result.add(trimmed);
      }
    }

    // 1. Custom notes added by the engineer come first
    for (final note in customNotes) {
      addNote(note);
    }

    // 2. Specific contextual notes for this item
    for (final note in contextualDefaults) {
      addNote(note);
    }

    // 3. Fallback generic notes
    for (final note in globalCommonNotes) {
      addNote(note);
    }

    return result;
  }

  /// Returns contextual default notes derived from question metadata without user modifications
  static List<String> getContextualDefaults({
    String? questionId,
    String? subcategory,
    String? description,
  }) {
    final textToSearch = '${questionId ?? ''} ${subcategory ?? ''} ${description ?? ''}'.toLowerCase();
    final matchedNotes = <String>[];
    final seen = <String>{};

    for (final entry in _defaultNotesByPattern.entries) {
      final keyword = entry.key.toLowerCase();
      if (textToSearch.contains(keyword)) {
        for (final note in entry.value) {
          if (!seen.contains(note)) {
            seen.add(note);
            matchedNotes.add(note);
          }
        }
      }
    }

    return matchedNotes;
  }

  /// Loads custom notes added by the engineer for this question
  static Future<List<String>> getCustomNotes(
    String questionId, {
    String? description,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${normalizeKey(questionId, description: description)}';
      final jsonStr = prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Adds a custom preset note for a question
  static Future<bool> addCustomNote(
    String questionId,
    String note, {
    String? description,
  }) async {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${normalizeKey(questionId, description: description)}';
      final existing = await getCustomNotes(questionId, description: description);

      if (existing.contains(cleanNote)) return true; // already exists

      final updated = [cleanNote, ...existing];
      await prefs.setString(key, jsonEncode(updated));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes a custom preset note for a question
  static Future<bool> removeCustomNote(
    String questionId,
    String note, {
    String? description,
  }) async {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${normalizeKey(questionId, description: description)}';
      final existing = await getCustomNotes(questionId, description: description);

      existing.removeWhere((e) => e.trim() == cleanNote);
      await prefs.setString(key, jsonEncode(existing));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if a note was added as a custom note by the engineer
  static Future<bool> isCustomNote(
    String questionId,
    String note, {
    String? description,
  }) async {
    final customList = await getCustomNotes(questionId, description: description);
    return customList.contains(note.trim());
  }

  /// Clears all custom notes for a given question
  static Future<void> resetQuestionNotes(
    String questionId, {
    String? description,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${normalizeKey(questionId, description: description)}';
      await prefs.remove(key);
    } catch (_) {}
  }
}
