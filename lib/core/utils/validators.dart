/// مكتبة validators موحدة لحقول النماذج في التطبيق
class Validators {
  /// التحقق من عدم الفراغ
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName مطلوب';
    }
    return null;
  }

  /// التحقق من صيغة التاريخ YYYY/MM/DD
  static String? dateFormat(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'أدخل تاريخ الزيارة';
    }
    final regex = RegExp(r'^\d{4}/\d{2}/\d{2}$');
    if (!regex.hasMatch(value.trim())) {
      return 'صيغة التاريخ: YYYY/MM/DD';
    }
    return null;
  }

  /// التحقق من أن القيمة رقم موجب اختياري
  static String? numericPositiveOptional(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;
    final d = double.tryParse(value.trim());
    if (d == null || d < 0) {
      return '$fieldName يجب أن يكون رقماً موجباً';
    }
    return null;
  }

  /// التحقق من أن القيمة رقم صحيح موجب اختياري
  static String? intPositiveOptional(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;
    final i = int.tryParse(value.trim());
    if (i == null || i < 0) {
      return '$fieldName يجب أن يكون رقماً صحيحاً موجباً';
    }
    return null;
  }

  /// التحقق من أن القيمة ضمن نطاق مقبول
  static String? inRange(String? value, String fieldName, double min, double max) {
    if (value == null || value.trim().isEmpty) return null;
    final d = double.tryParse(value.trim());
    if (d == null) return '$fieldName يجب أن يكون رقماً';
    if (d < min || d > max) return '$fieldName يجب أن يكون بين $min و $max';
    return null;
  }

  /// تنظيف وتوحيد رقم الهاتف اليمني واستخراج الأرقام الأساسية
  static String cleanYemeniPhone(String raw) {
    var s = raw.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (s.startsWith('+967')) {
      s = s.substring(4);
    } else if (s.startsWith('00967')) {
      s = s.substring(5);
    } else if (s.startsWith('967')) {
      s = s.substring(3);
    }
    if (s.startsWith('0') && s.length >= 7) {
      s = s.substring(1);
    }
    return s;
  }

  /// التعرف على مشغل شبكة الهاتف اليمني
  static String? getYemeniCarrier(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = cleanYemeniPhone(value);
    if (cleaned.startsWith('77') || cleaned.startsWith('78')) return 'يمن موبايل';
    if (cleaned.startsWith('73')) return 'يو (YOU)';
    if (cleaned.startsWith('71')) return 'سبأفون';
    if (cleaned.startsWith('70')) return 'واي (Y)';
    if (cleaned.startsWith('1')) return 'ثابت - صنعاء';
    if (cleaned.startsWith('2')) return 'ثابت - عدن/لحج';
    if (cleaned.startsWith('3')) return 'ثابت - الحديدة';
    if (cleaned.startsWith('4')) return 'ثابت - تعز/إب';
    if (cleaned.startsWith('5')) return 'ثابت - حضرموت/المهرة';
    if (cleaned.startsWith('6')) return 'ثابت - ذمار/البيضاء/مأرب';
    if (cleaned.startsWith('7') && cleaned.length <= 7) return 'ثابت - حجة/صعدة';
    return null;
  }

  /// تنسيق الرقم اليمني للعرض (مثال: 777 123 456)
  static String formatYemeniPhone(String raw) {
    final cleaned = cleanYemeniPhone(raw);
    if (cleaned.length == 9 && (cleaned.startsWith('7'))) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
    }
    return raw;
  }

  /// التحقق الدقيق من صحة رقم الهاتف اليمني (محمول أو ثابت)
  static String? yemeniPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // اختياري
    final cleaned = cleanYemeniPhone(value);
    // المحمول اليمني: 9 أرقام تبدأ بـ 70 أو 71 أو 73 أو 77 أو 78
    if (RegExp(r'^7[01378]\d{7}$').hasMatch(cleaned)) {
      return null;
    }
    // الثابت اليمني: مفتاح المحافظة (1-7) يليه 6 أرقام (إجمالي 7 أرقام)
    if (RegExp(r'^[1-7]\d{6}$').hasMatch(cleaned)) {
      return null;
    }
    return 'يرجى إدخال رقم يمني صحيح (يبدأ بـ 77، 78، 73، 71، 70 أو رقم ثابت)';
  }
}
