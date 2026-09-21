class AppConstants {
  static const String appName = 'ReportCraft';
  static const String appNameAr = 'منشئ التقارير الاحترافية';
  static const String appVersion = '1.0.0';

  // Available dynamic variables for text templates
  static const List<Map<String, String>> templateVariables = [
    {'key': '{{اسم_المشروع}}', 'label': 'اسم المشروع'},
    {'key': '{{اسم_المنشأة}}', 'label': 'اسم المنشأة'},
    {'key': '{{نوع_المنشأة}}', 'label': 'نوع المنشأة'},
    {'key': '{{المحافظة}}', 'label': 'المحافظة'},
    {'key': '{{المديرية}}', 'label': 'المديرية'},
    {'key': '{{رقم_العقد}}', 'label': 'رقم العقد'},
    {'key': '{{الممول}}', 'label': 'الجهة الممولة'},
    {'key': '{{المقاول}}', 'label': 'المقاول المنفذ'},
    {'key': '{{تاريخ_الزيارة}}', 'label': 'تاريخ الزيارة'},
    {'key': '{{مهندس_الصيانة}}', 'label': 'مهندس الصيانة'},
    {'key': '{{قدرة_المنظومة}}', 'label': 'قدرة المنظومة'},
  ];

  static const List<String> defaultRoles = [
    'مهندس الصيانة',
    'ممثل المستفيد',
    'مدير المنشأة',
    'المشرف الفني',
    'رئيس الفريق',
  ];
}
