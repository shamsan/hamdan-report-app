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

  /// التحقق من رقم هاتف يمني بسيط
  static String? yemeniPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.trim().replaceAll(' ', '').replaceAll('-', '');
    if (cleaned.length < 9) return 'رقم الهاتف يبدو قصيراً جداً';
    return null;
  }
}
