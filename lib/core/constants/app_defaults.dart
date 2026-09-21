/// ثوابت القيم الافتراضية للتطبيق — يجب تعديلها من شاشة الإعدادات/الهوية البصرية
class AppDefaults {
  /// القدرة الكلية الافتراضية للمنظومة
  static const String defaultCapacityKw = '57.6 kW';

  /// الفئة الافتراضية للمنشأة
  static const String defaultCategory = 'CAT 8';

  /// رقم العقد الافتراضي
  static const String defaultContractNumber = '1010720';

  /// اسم مهندس الصيانة الافتراضي
  static const String defaultEngineerName = 'م. أحمد سعيد العنسي';

  /// وقت الزيارة الافتراضي
  static const String defaultVisitTime = '09:00 ص';

  /// عدد الألواح الافتراضي لكل سلسلة
  static const int defaultPanelsPerString = 24;

  /// Voc النموذجية الافتراضية (للتعبئة النموذجية)
  static const double defaultVoc = 135.2;

  /// Isc النموذجية الافتراضية (للتعبئة النموذجية)
  static const double defaultIsc = 8.4;
}
