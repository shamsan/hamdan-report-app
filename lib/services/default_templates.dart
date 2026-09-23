import '../models/report.dart';
import '../models/report_template.dart';
import '../models/inspection_item.dart';
import '../models/measurement_data.dart';
import '../models/signature_data.dart';
import '../models/maintenance_need.dart';

class DefaultTemplates {
  /// The official 11-page periodic maintenance template
  static ReportTemplate get solarMaintenanceTemplate => inspectionReportTemplate;

  static ReportTemplate get inspectionReportTemplate {
    return ReportTemplate(
      id: 'tmpl_solar_11p',
      title: 'استمارة زيارة صيانة دورية لمنظومة الطاقة الشمسية (11 صفحة)',
      description: 'النموذج المؤسسي المعتمد لصيانة وتشغيل منظومات الطاقة الشمسية بالمرافق الصحية',
      category: 'طاقة شمسية',
      isDefault: true,
      isLocked: true,
      updatedAt: DateTime(2025, 8, 15),
      pages: const [
        TemplatePage(
          pageNumber: 1,
          title: 'بيانات المشروع والمنشأة والمنظومة',
          elements: [
            PageElement(id: 'el_p1_hdr', type: ElementType.header, title: 'الترويسة الرسمية وبيانات التقرير'),
            PageElement(id: 'el_p1_proj', type: ElementType.table, title: 'بيانات المشروع والمنشأة'),
            PageElement(id: 'el_p1_specs', type: ElementType.table, title: 'المواصفات الفنية لمنظومة الطاقة الشمسية'),
          ],
        ),
        TemplatePage(
          pageNumber: 2,
          title: 'فحص الألواح والقواعد وتمديد الكابلات والتجميع',
          elements: [
            PageElement(id: 'el_p2_g1', type: ElementType.inspectionTable, title: '1- فحص الألواح الشمسية والقواعد الحديدية'),
            PageElement(id: 'el_p2_g2', type: ElementType.inspectionTable, title: '2- فحص الكابل تري وتمديد الكابلات'),
            PageElement(id: 'el_p2_g3', type: ElementType.inspectionTable, title: '3- فحص تجميع كابلات الألواح'),
          ],
        ),
        TemplatePage(
          pageNumber: 3,
          title: 'فحص لوحات القواطع ومفاتيح التبديل',
          elements: [
            PageElement(id: 'el_p3_g4', type: ElementType.inspectionTable, title: '4- فحص لوحات قواطع التيار المستمر والمتردد والبس بارات ومفتاح التبديل'),
          ],
        ),
        TemplatePage(
          pageNumber: 4,
          title: 'فحص منظمات الشحن والعواكس والتهوية والحماية',
          elements: [
            PageElement(id: 'el_p4_g5', type: ElementType.inspectionTable, title: '5- فحص منظمات الشحن'),
            PageElement(id: 'el_p4_g6', type: ElementType.inspectionTable, title: '6- فحص عواكس التيار (الإنفرترات)'),
            PageElement(id: 'el_p4_g7', type: ElementType.inspectionTable, title: '7- فحص نظام التهوية والحماية والإنذار والمراقبة'),
          ],
        ),
        TemplatePage(
          pageNumber: 5,
          title: 'فحص الإنارة والتأريض ومصفوفة البطاريات',
          elements: [
            PageElement(id: 'el_p5_g8', type: ElementType.inspectionTable, title: '8- فحص الإضاءة الداخلية والخارجية'),
            PageElement(id: 'el_p5_g9', type: ElementType.inspectionTable, title: '9- فحص التأريض والحماية من الصواعق'),
            PageElement(id: 'el_p5_g10', type: ElementType.inspectionTable, title: '10- فحص مصفوفة تخزين الطاقة (البطاريات)'),
          ],
        ),
        TemplatePage(
          pageNumber: 6,
          title: 'قياسات مصفوفة تخزين الطاقة (البطاريات) - الجزء 1',
          elements: [
            PageElement(id: 'el_p6_b12', type: ElementType.measurementTable, title: '10- نموذج قياسات مصفوفة تخزين الطاقة (البنوك 1 و 2)'),
          ],
        ),
        TemplatePage(
          pageNumber: 7,
          title: 'تابع قياسات مصفوفة تخزين الطاقة (البطاريات) - الجزء 2',
          elements: [
            PageElement(id: 'el_p7_b34', type: ElementType.measurementTable, title: 'تابع نموذج قياسات مصفوفة تخزين الطاقة (البنوك 3 و 4)'),
          ],
        ),
        TemplatePage(
          pageNumber: 8,
          title: 'بيانات تشغيل منظومة الطاقة الشمسية',
          isLandscape: true,
          elements: [
            PageElement(id: 'el_p8_op', type: ElementType.measurementTable, title: '11- نموذج بيانات التشغيل لمنظومة الطاقة الشمسية'),
          ],
        ),
        TemplatePage(
          pageNumber: 9,
          title: 'قياسات أداء الألواح وسلاسل التوليد',
          isLandscape: true,
          elements: [
            PageElement(id: 'el_p9_str', type: ElementType.measurementTable, title: '12- نموذج قياسات أداء الألواح الشمسية'),
          ],
        ),
        TemplatePage(
          pageNumber: 10,
          title: 'إفادة الحضور والاعتماد الرسمي',
          elements: [
            PageElement(id: 'el_p10_state', type: ElementType.approvalStatement, title: 'إفادة حضور واعتماد الصيانة الدورية'),
          ],
        ),
        TemplatePage(
          pageNumber: 11,
          title: 'سجل حضور فريق الصيانة',
          elements: [
            PageElement(id: 'el_p11_att', type: ElementType.table, title: 'سجل حضور المهندسين والفنيين'),
          ],
        ),
      ],
    );
  }

  /// Authentic 10 Inspection Groups matching the reference PDF 1:1
  static List<InspectionGroup> get defaultInspectionGroups {
    return [
      // Model 1 (Page 2) - 11 items
      const InspectionGroup(
        id: 'group_1',
        groupNumber: 1,
        title: 'نموذج فحص الألواح الشمسية و القواعد الحديدية',
        items: [
          InspectionItem(id: 'g1_1', serialNo: 1, description: 'سلامة الالواح من الكسور', status: InspectionStatus.good, notes: 'سليمة 100%'),
          InspectionItem(id: 'g1_2', serialNo: 2, description: 'نظافة الالواح', status: InspectionStatus.good, notes: 'تم التنظيف بالماء المقطر'),
          InspectionItem(id: 'g1_3', serialNo: 3, description: 'سلامة تثبيت الالواح', status: InspectionStatus.good, notes: 'مثبتة بإحكام'),
          InspectionItem(id: 'g1_4', serialNo: 4, description: 'عدم وجود أي تغير في الالوان', status: InspectionStatus.good, notes: 'الخلايا سليمة'),
          InspectionItem(id: 'g1_5', serialNo: 5, description: 'سلامة الباك شيت', status: InspectionStatus.good, notes: 'لا يوجد خدوش'),
          InspectionItem(id: 'g1_6', serialNo: 6, description: 'سلامة صندوق الربط خلف الالواح', status: InspectionStatus.good, notes: 'محكم الإغلاق'),
          InspectionItem(id: 'g1_7', serialNo: 7, description: 'سلامة أطراف التوصيل MC4', status: InspectionStatus.good, notes: 'معزولة ومحكمة'),
          InspectionItem(id: 'g1_8', serialNo: 8, description: 'عدم وجود ظل من أشجار وغيرة', status: InspectionStatus.good, notes: 'خالية من التظليل'),
          InspectionItem(id: 'g1_9', serialNo: 9, description: 'سلامة قواعد الالواح', status: InspectionStatus.good, notes: 'هيكل حديدي مجلفن ممتاز'),
          InspectionItem(id: 'g1_10', serialNo: 10, description: 'عدم وجود صدأ على قواعد الالواح', status: InspectionStatus.good, notes: 'خالية من الصدأ'),
          InspectionItem(id: 'g1_11', serialNo: 11, description: 'ثبات قواعد الالواح', status: InspectionStatus.good, notes: 'مثبتة بالبراغي الخرسانية'),
        ],
      ),
      // Model 2 (Page 2) - 8 items
      const InspectionGroup(
        id: 'group_2',
        groupNumber: 2,
        title: 'نموذج فحص الكابل تري و تمديد الكابلات',
        items: [
          InspectionItem(id: 'g2_1', serialNo: 1, description: 'الكابل تري سليم ومحكم الإغلاق', status: InspectionStatus.good, notes: 'الأغطية مثبتة'),
          InspectionItem(id: 'g2_2', serialNo: 2, description: 'ثبات الكابل تري', status: InspectionStatus.good, notes: 'مثبت بالحوامل المعدنية'),
          InspectionItem(id: 'g2_3', serialNo: 3, description: 'سلامة الكابلات داخل الكابل تري', status: InspectionStatus.good, notes: 'مرتبة وغير متداخلة'),
          InspectionItem(id: 'g2_4', serialNo: 4, description: 'سلامة جلاندات الكابل تري والصناديق', status: InspectionStatus.good, notes: 'مطاطية وسليمة'),
          InspectionItem(id: 'g2_5', serialNo: 5, description: 'عدم وجود شقوق على الكابلات', status: InspectionStatus.good, notes: 'العوازل ممتازة'),
          InspectionItem(id: 'g2_6', serialNo: 6, description: 'عدم وجود كابلات مكشوفة', status: InspectionStatus.good, notes: 'معزولة بالكامل'),
          InspectionItem(id: 'g2_7', serialNo: 7, description: 'عدم وجود تمديد كابلات مستحدثة', status: InspectionStatus.good, notes: 'لا يوجد'),
          InspectionItem(id: 'g2_8', serialNo: 8, description: 'عدم وجود صدأ على طول الكابل تري', status: InspectionStatus.good, notes: 'خالي من الصدأ'),
        ],
      ),
      // Model 3 (Page 2) - 8 items
      const InspectionGroup(
        id: 'group_3',
        groupNumber: 3,
        title: 'نموذج تجميع كابلات الالواح الشمسية',
        items: [
          InspectionItem(id: 'g3_1', serialNo: 1, description: 'ثبات صناديق تجميع كابلات الالواح الشمسية', status: InspectionStatus.good, notes: 'مثبتة بجدار المبنى'),
          InspectionItem(id: 'g3_2', serialNo: 2, description: 'سلامة الفيوزات', status: InspectionStatus.good, notes: 'فيوزات DC سليمة'),
          InspectionItem(id: 'g3_3', serialNo: 3, description: 'نظافة صناديق التجميع من الداخل', status: InspectionStatus.good, notes: 'نظيفة ومحكمة IP65'),
          InspectionItem(id: 'g3_4', serialNo: 4, description: 'حرارة القواطع', status: InspectionStatus.good, notes: 'طبيعية (كاشف حراري)'),
          InspectionItem(id: 'g3_5', serialNo: 5, description: 'ربط الكابلات داخل الصندوق', status: InspectionStatus.good, notes: 'تمت إعادة الشد'),
          InspectionItem(id: 'g3_6', serialNo: 6, description: 'الصندوق محكم الاغلاق', status: InspectionStatus.good, notes: 'مغلق ومحمي'),
          InspectionItem(id: 'g3_7', serialNo: 7, description: 'وجود اللاصق التحذيري', status: InspectionStatus.good, notes: 'ملصق الخطر موجود'),
          InspectionItem(id: 'g3_8', serialNo: 8, description: 'ثبات جلاندات الصندوق', status: InspectionStatus.good, notes: 'محكمة العزل'),
        ],
      ),
      // Model 4 (Page 3) - 42 items in 6 subcategories
      const InspectionGroup(
        id: 'group_4',
        groupNumber: 4,
        title: 'نموذج فحص لوحات قواطع التيار المستمر و المتردد و البزبارات ومفتاح التبديل لمصادر الطاقة',
        items: [
          // Subcategory 1: صندوق قواطع البطاريات "تيار مستمر"
          InspectionItem(id: 'g4_1', serialNo: 1, description: 'ثبات الكابل تري', status: InspectionStatus.good, notes: 'مثبت', subcategory: 'صندوق قواطع البطاريات "تيار مستمر"'),
          InspectionItem(id: 'g4_2', serialNo: 2, description: 'سلامة الكابلات داخل الكابل تري', status: InspectionStatus.good, notes: 'سليمة', subcategory: 'صندوق قواطع البطاريات "تيار مستمر"'),
          InspectionItem(id: 'g4_3', serialNo: 3, description: 'سلامة جلاندات الكابل تري والصناديق', status: InspectionStatus.good, notes: 'سليمة', subcategory: 'صندوق قواطع البطاريات "تيار مستمر"'),
          InspectionItem(id: 'g4_4', serialNo: 4, description: 'عدم وجود شقوق على الكابلات', status: InspectionStatus.good, notes: 'ممتازة', subcategory: 'صندوق قواطع البطاريات "تيار مستمر"'),
          InspectionItem(id: 'g4_5', serialNo: 5, description: 'عدم وجود كابلات مكشوفة', status: InspectionStatus.good, notes: 'معزولة', subcategory: 'صندوق قواطع البطاريات "تيار مستمر"'),
          InspectionItem(id: 'g4_6', serialNo: 6, description: 'عدم وجود تمديد كابلات مستحدثة', status: InspectionStatus.good, notes: 'لا يوجد', subcategory: 'صندوق قواطع البطاريات "تيار مستمر"'),
          InspectionItem(id: 'g4_7', serialNo: 7, description: 'عدم وجود صدأ على طول الكابل تري', status: InspectionStatus.good, notes: 'خالي من الصدأ', subcategory: 'صندوق قواطع البطاريات "تيار مستمر"'),
          // Subcategory 2: صندوق قواطع العاكس "تيار مستمر"
          InspectionItem(id: 'g4_8', serialNo: 8, description: 'ثبات الصندوق', status: InspectionStatus.good, notes: 'مثبت', subcategory: 'صندوق قواطع العاكس "تيار مستمر"'),
          InspectionItem(id: 'g4_9', serialNo: 9, description: 'حرارة القواطع بإستخدام كاشف حراري', status: InspectionStatus.good, notes: 'طبيعية 28°C', subcategory: 'صندوق قواطع العاكس "تيار مستمر"'),
          InspectionItem(id: 'g4_10', serialNo: 10, description: 'ربط الكابلات داخل الصندوق', status: InspectionStatus.good, notes: 'مربوطة بعزم معتمد', subcategory: 'صندوق قواطع العاكس "تيار مستمر"'),
          InspectionItem(id: 'g4_11', serialNo: 11, description: 'الصندوق محكم الاغلاق', status: InspectionStatus.good, notes: 'محكم', subcategory: 'صندوق قواطع العاكس "تيار مستمر"'),
          InspectionItem(id: 'g4_12', serialNo: 12, description: 'وجود اللاصق التحذيري', status: InspectionStatus.good, notes: 'موجود', subcategory: 'صندوق قواطع العاكس "تيار مستمر"'),
          InspectionItem(id: 'g4_13', serialNo: 13, description: 'ثبات جلاندات الصندوق', status: InspectionStatus.good, notes: 'ثابتة', subcategory: 'صندوق قواطع العاكس "تيار مستمر"'),
          InspectionItem(id: 'g4_14', serialNo: 14, description: 'نظافة الصندوق من الداخل', status: InspectionStatus.good, notes: 'نظيف', subcategory: 'صندوق قواطع العاكس "تيار مستمر"'),
          // Subcategory 3: صندوق تجميع كابلات التيار المستمر
          InspectionItem(id: 'g4_15', serialNo: 15, description: 'ثبات الصندوق', status: InspectionStatus.good, notes: 'مثبت', subcategory: 'صندوق تجميع كابلات التيار المستمر'),
          InspectionItem(id: 'g4_16', serialNo: 16, description: 'حالة البزبار داخل الصندوق', status: InspectionStatus.good, notes: 'نحاسي معزول سليم', subcategory: 'صندوق تجميع كابلات التيار المستمر'),
          InspectionItem(id: 'g4_17', serialNo: 17, description: 'ربط الكابلات داخل الصندوق', status: InspectionStatus.good, notes: 'مربوطة بإحكام', subcategory: 'صندوق تجميع كابلات التيار المستمر'),
          InspectionItem(id: 'g4_18', serialNo: 18, description: 'الصندوق محكم الاغلاق', status: InspectionStatus.good, notes: 'محكم', subcategory: 'صندوق تجميع كابلات التيار المستمر'),
          InspectionItem(id: 'g4_19', serialNo: 19, description: 'وجود اللاصق التحذيري', status: InspectionStatus.good, notes: 'موجود', subcategory: 'صندوق تجميع كابلات التيار المستمر'),
          InspectionItem(id: 'g4_20', serialNo: 20, description: 'ثبات جلاندات الصندوق', status: InspectionStatus.good, notes: 'ثابتة', subcategory: 'صندوق تجميع كابلات التيار المستمر'),
          InspectionItem(id: 'g4_21', serialNo: 21, description: 'نظافة الصندوق من الداخل', status: InspectionStatus.good, notes: 'نظيف', subcategory: 'صندوق تجميع كابلات التيار المستمر'),
          // Subcategory 4: صندوق دمج وقواطع حماية التيار المتردد
          InspectionItem(id: 'g4_22', serialNo: 22, description: 'ثبات الصندوق', status: InspectionStatus.good, notes: 'مثبت', subcategory: 'صندوق دمج وقواطع حماية التيار المتردد'),
          InspectionItem(id: 'g4_23', serialNo: 23, description: 'حرارة القواطع بإستخدام كاشف حراري', status: InspectionStatus.good, notes: 'طبيعية 29°C', subcategory: 'صندوق دمج وقواطع حماية التيار المتردد'),
          InspectionItem(id: 'g4_24', serialNo: 24, description: 'ربط الكابلات داخل الصندوق', status: InspectionStatus.good, notes: 'مربوطة', subcategory: 'صندوق دمج وقواطع حماية التيار المتردد'),
          InspectionItem(id: 'g4_25', serialNo: 25, description: 'الصندوق محكم الاغلاق', status: InspectionStatus.good, notes: 'محكم', subcategory: 'صندوق دمج وقواطع حماية التيار المتردد'),
          InspectionItem(id: 'g4_26', serialNo: 26, description: 'وجود اللاصق التحذيري', status: InspectionStatus.good, notes: 'موجود', subcategory: 'صندوق دمج وقواطع حماية التيار المتردد'),
          InspectionItem(id: 'g4_27', serialNo: 27, description: 'ثبات جلاندات الصندوق', status: InspectionStatus.good, notes: 'ثابتة', subcategory: 'صندوق دمج وقواطع حماية التيار المتردد'),
          InspectionItem(id: 'g4_28', serialNo: 28, description: 'نظافة الصندوق من الداخل', status: InspectionStatus.good, notes: 'نظيف', subcategory: 'صندوق دمج وقواطع حماية التيار المتردد'),
          // Subcategory 5: لوحة التوزيع الرئيسية
          InspectionItem(id: 'g4_29', serialNo: 29, description: 'ثبات الصندوق', status: InspectionStatus.good, notes: 'مثبت', subcategory: 'لوحة التوزيع الرئيسية'),
          InspectionItem(id: 'g4_30', serialNo: 30, description: 'حرارة القواطع بإستخدام كاشف حراري', status: InspectionStatus.good, notes: 'طبيعية', subcategory: 'لوحة التوزيع الرئيسية'),
          InspectionItem(id: 'g4_31', serialNo: 31, description: 'ربط الكابلات داخل الصندوق', status: InspectionStatus.good, notes: 'تم الشد', subcategory: 'لوحة التوزيع الرئيسية'),
          InspectionItem(id: 'g4_32', serialNo: 32, description: 'الصندوق محكم الاغلاق', status: InspectionStatus.good, notes: 'محكم', subcategory: 'لوحة التوزيع الرئيسية'),
          InspectionItem(id: 'g4_33', serialNo: 33, description: 'وجود اللاصق التحذيري', status: InspectionStatus.good, notes: 'موجود', subcategory: 'لوحة التوزيع الرئيسية'),
          InspectionItem(id: 'g4_34', serialNo: 34, description: 'ثبات جلاندات الصندوق', status: InspectionStatus.good, notes: 'ثابتة', subcategory: 'لوحة التوزيع الرئيسية'),
          InspectionItem(id: 'g4_35', serialNo: 35, description: 'نظافة الصندوق من الداخل', status: InspectionStatus.good, notes: 'نظيف', subcategory: 'لوحة التوزيع الرئيسية'),
          // Subcategory 6: مفتاح تبديل يدوي لمصدر الطاقة
          InspectionItem(id: 'g4_36', serialNo: 36, description: 'ثبات الصندوق', status: InspectionStatus.good, notes: 'مثبت', subcategory: 'مفتاح تبديل يدوي لمصدر الطاقة'),
          InspectionItem(id: 'g4_37', serialNo: 37, description: 'الحرارة داخل الصندوق "المبدل"', status: InspectionStatus.good, notes: 'طبيعية', subcategory: 'مفتاح تبديل يدوي لمصدر الطاقة'),
          InspectionItem(id: 'g4_38', serialNo: 38, description: 'ربط الكابلات داخل الصندوق', status: InspectionStatus.good, notes: 'مربوطة', subcategory: 'مفتاح تبديل يدوي لمصدر الطاقة'),
          InspectionItem(id: 'g4_39', serialNo: 39, description: 'الصندوق محكم الاغلاق', status: InspectionStatus.good, notes: 'محكم', subcategory: 'مفتاح تبديل يدوي لمصدر الطاقة'),
          InspectionItem(id: 'g4_40', serialNo: 40, description: 'وجود اللاصق التحذيري', status: InspectionStatus.good, notes: 'موجود', subcategory: 'مفتاح تبديل يدوي لمصدر الطاقة'),
          InspectionItem(id: 'g4_41', serialNo: 41, description: 'ثبات جلاندات الصندوق', status: InspectionStatus.good, notes: 'ثابتة', subcategory: 'مفتاح تبديل يدوي لمصدر الطاقة'),
          InspectionItem(id: 'g4_42', serialNo: 42, description: 'نظافة الصندوق من الداخل', status: InspectionStatus.good, notes: 'نظيف', subcategory: 'مفتاح تبديل يدوي لمصدر الطاقة'),
        ],
      ),
      // Model 5 (Page 4) - 7 items
      const InspectionGroup(
        id: 'group_5',
        groupNumber: 5,
        title: 'نموذج فحص منظمات الشحن',
        items: [
          InspectionItem(id: 'g5_1', serialNo: 1, description: 'تثبيت منظمات الشحن', status: InspectionStatus.good, notes: 'مثبتة على الحائط'),
          InspectionItem(id: 'g5_2', serialNo: 2, description: 'ربط الكابلات بمنظمات الشحن', status: InspectionStatus.good, notes: 'مربوطة بإحكام'),
          InspectionItem(id: 'g5_3', serialNo: 3, description: 'الرطوبة حول منظمات الشحن', status: InspectionStatus.good, notes: 'جافة وخالية من الرطوبة'),
          InspectionItem(id: 'g5_4', serialNo: 4, description: 'الإشارات التحذيرية لمنظمات الشحن', status: InspectionStatus.good, notes: 'لا توجد إنذارات'),
          InspectionItem(id: 'g5_5', serialNo: 5, description: 'شحن البطاريات من خلال منظمات الشحن', status: InspectionStatus.good, notes: 'تعمل بكفاءة Float/Bulk'),
          InspectionItem(id: 'g5_6', serialNo: 6, description: 'النظافة والغبار عند منظمات الشحن', status: InspectionStatus.good, notes: 'تم تنظيف فلاتر التبريد'),
          InspectionItem(id: 'g5_7', serialNo: 7, description: 'درجة الحرارة عند منظمات الشحن', status: InspectionStatus.good, notes: 'طبيعية (32°C)'),
        ],
      ),
      // Model 6 (Page 4) - 8 items
      const InspectionGroup(
        id: 'group_6',
        groupNumber: 6,
        title: 'نموذج فحص عواكس التيار (الانفرترات)',
        items: [
          InspectionItem(id: 'g6_1', serialNo: 1, description: 'تثبيت العاكس', status: InspectionStatus.good, notes: 'مثبت بالقواعد الجدارية'),
          InspectionItem(id: 'g6_2', serialNo: 2, description: 'ربط كابلات ال DC بالعاكس', status: InspectionStatus.good, notes: 'مشدوة بعزم معتمد'),
          InspectionItem(id: 'g6_3', serialNo: 3, description: 'الإشارات التحذيرية لعاكس', status: InspectionStatus.good, notes: 'المؤشرات خضراء Normal'),
          InspectionItem(id: 'g6_4', serialNo: 4, description: 'الرطوبة حول العاكس', status: InspectionStatus.good, notes: 'خالية من الرطوبة'),
          InspectionItem(id: 'g6_5', serialNo: 5, description: 'فولتية الخرج عند العاكس', status: InspectionStatus.good, notes: '228V AC مستقرة'),
          InspectionItem(id: 'g6_6', serialNo: 6, description: 'النظافة والغبار عند العاكس', status: InspectionStatus.good, notes: 'نظيفة ومراوحها تعمل'),
          InspectionItem(id: 'g6_7', serialNo: 7, description: 'ربط كابلات ال AC بالعاكس', status: InspectionStatus.good, notes: 'مربوطة ومعزولة'),
          InspectionItem(id: 'g6_8', serialNo: 8, description: 'درجة الحرارة عند العاكس', status: InspectionStatus.good, notes: 'طبيعية (34°C)'),
        ],
      ),
      // Model 7 (Page 4) - 13 items in 3 subcategories
      const InspectionGroup(
        id: 'group_7',
        groupNumber: 7,
        title: 'نموذج فحص نظام التهوية – و نظام الانذار و الحماية ونظام المراقبة و المتابعة',
        items: [
          // Subcategory 1: نظام التهوية
          InspectionItem(id: 'g7_1', serialNo: 1, description: 'درجة حرارة الغرفة', status: InspectionStatus.good, notes: '24°C مستقرة', subcategory: 'نظام التهوية وتكييف الغرفة'),
          InspectionItem(id: 'g7_2', serialNo: 2, description: 'نظافة شبك وفلاتر المراوح', status: InspectionStatus.good, notes: 'تم غسيل وتنظيف الفلاتر', subcategory: 'نظام التهوية وتكييف الغرفة'),
          InspectionItem(id: 'g7_3', serialNo: 3, description: 'عمل المراوح', status: InspectionStatus.good, notes: 'تعمل بسلاسة وبدون اهتزاز', subcategory: 'نظام التهوية وتكييف الغرفة'),
          // Subcategory 2: نظام إنذار ومكافحة الحرائق
          InspectionItem(id: 'g7_4', serialNo: 4, description: 'عمل حساس الدخان والحرارة', status: InspectionStatus.good, notes: 'تم اختباره ويعمل', subcategory: 'نظام إنذار ومكافحة الحرائق والسلامة'),
          InspectionItem(id: 'g7_5', serialNo: 5, description: 'مصدر الطاقة لحساس الدخان والحرارة', status: InspectionStatus.good, notes: 'البطارية الداخلية مشحونة', subcategory: 'نظام إنذار ومكافحة الحرائق والسلامة'),
          InspectionItem(id: 'g7_6', serialNo: 6, description: 'ثبات حساس الدخان والحرارة', status: InspectionStatus.good, notes: 'مثبت بالسقف', subcategory: 'نظام إنذار ومكافحة الحرائق والسلامة'),
          InspectionItem(id: 'g7_7', serialNo: 7, description: 'حالة طفايات الحريق من حيث التعبئة والتثبيت', status: InspectionStatus.good, notes: 'المؤشر في الأخضر صالحة', subcategory: 'نظام إنذار ومكافحة الحرائق والسلامة'),
          // Subcategory 3: نظام المراقبة والمتابعة
          InspectionItem(id: 'g7_8', serialNo: 8, description: 'ثبات شاشة المراقبة والمتابعة', status: InspectionStatus.good, notes: 'مثبتة باللوحة', subcategory: 'نظام المراقبة والمتابعة'),
          InspectionItem(id: 'g7_9', serialNo: 9, description: 'ضبط شاشة المراقبة والمتابعة', status: InspectionStatus.good, notes: 'الإعدادات صحيحة', subcategory: 'نظام المراقبة والمتابعة'),
          InspectionItem(id: 'g7_10', serialNo: 10, description: 'قراءات الشاشة تطابق قراءات أجهزة القياس', status: InspectionStatus.good, notes: 'مطابقة 100%', subcategory: 'نظام المراقبة والمتابعة'),
          InspectionItem(id: 'g7_11', serialNo: 11, description: 'حالة الذاكرة في شاشة المراقبة والمتابعة', status: InspectionStatus.good, notes: 'تسجيل البيانات مستمر', subcategory: 'نظام المراقبة والمتابعة'),
          InspectionItem(id: 'g7_12', serialNo: 12, description: 'قائمة الأخطاء في شاشة المراقبة والمتابعة', status: InspectionStatus.good, notes: 'خالية من الأعطال 0 Error', subcategory: 'نظام المراقبة والمتابعة'),
          InspectionItem(id: 'g7_13', serialNo: 13, description: 'توصيل منظمات الشحن والأنفرترات بالشاشة', status: InspectionStatus.good, notes: 'متصلة عبر RS485', subcategory: 'نظام المراقبة والمتابعة'),
        ],
      ),
      // Model 8 (Page 5) - 6 items
      const InspectionGroup(
        id: 'group_8',
        groupNumber: 8,
        title: 'نموذج فحص الاضاءة الداخلية و الخارجية',
        items: [
          InspectionItem(id: 'g8_1', serialNo: 1, description: 'حالة لمبات الإضاءة الداخلية 9 وات', status: InspectionStatus.good, notes: 'تضيء بشكل ممتاز'),
          InspectionItem(id: 'g8_2', serialNo: 2, description: 'حالة لمبات الإضاءة الداخلية 20 وات', status: InspectionStatus.good, notes: 'سليمة وتعمل'),
          InspectionItem(id: 'g8_3', serialNo: 3, description: 'حالة لمبات الإضاءة الخارجية 30 وات', status: InspectionStatus.good, notes: 'تعمل بكفاءة'),
          InspectionItem(id: 'g8_4', serialNo: 4, description: 'عمل الخلية الضوئية', status: InspectionStatus.good, notes: 'التحكم التلقائي سليم'),
          InspectionItem(id: 'g8_5', serialNo: 5, description: 'ثبات لمبات الإضاءة الخارجية 30 وات', status: InspectionStatus.good, notes: 'مثبتة بإحكام'),
          InspectionItem(id: 'g8_6', serialNo: 6, description: 'سلامة التمديدات الكهربائية للمبات الخارجية', status: InspectionStatus.good, notes: 'معزولة ومحمية'),
        ],
      ),
      // Model 9 (Page 5) - 10 items
      const InspectionGroup(
        id: 'group_9',
        groupNumber: 9,
        title: 'نموذج فحص التاريض و الحماية من الصواعق',
        items: [
          InspectionItem(id: 'g9_1', serialNo: 1, description: 'مقاومة حفرة التأريض', status: InspectionStatus.good, notes: '2.8 أوم (أقل من 5 أوم)'),
          InspectionItem(id: 'g9_2', serialNo: 2, description: 'مقاومة حفرة الحماية من الصواعق', status: InspectionStatus.good, notes: '3.1 أوم'),
          InspectionItem(id: 'g9_3', serialNo: 3, description: 'توصيل نظام الحماية من الصواعق', status: InspectionStatus.good, notes: 'توصيل مستمر'),
          InspectionItem(id: 'g9_4', serialNo: 4, description: 'توصيل كابلات التاريض عند الالواح', status: InspectionStatus.good, notes: 'مربوطة بمسامير مسننة'),
          InspectionItem(id: 'g9_5', serialNo: 5, description: 'توصيل كابلات التاريض عند الصناديق', status: InspectionStatus.good, notes: 'مربوطة بالبزبار'),
          InspectionItem(id: 'g9_6', serialNo: 6, description: 'توصيل الكابلات في بزبرات التأريض', status: InspectionStatus.good, notes: 'محكمة الربط'),
          InspectionItem(id: 'g9_7', serialNo: 7, description: 'ثبات بزبرات التأريض', status: InspectionStatus.good, notes: 'مثبتة على عوازل'),
          InspectionItem(id: 'g9_8', serialNo: 8, description: 'ثبات مانعة الصواعق', status: InspectionStatus.good, notes: 'مثبتة بأعلى نقطة'),
          InspectionItem(id: 'g9_9', serialNo: 9, description: 'كليبات الربط داخل حفرة التأريض', status: InspectionStatus.good, notes: 'نحاسية سليمة'),
          InspectionItem(id: 'g9_10', serialNo: 10, description: 'رطوبة غرفة التأريض', status: InspectionStatus.good, notes: 'طبيعية ومناسبة'),
        ],
      ),
      // Model 10 (Page 5) - 8 items
      const InspectionGroup(
        id: 'group_10',
        groupNumber: 10,
        title: 'نموذج فحص مصفوفة تخزين الطاقة (البطاريات)',
        items: [
          InspectionItem(id: 'g10_1', serialNo: 1, description: 'ثبات راك البطاريات', status: InspectionStatus.good, notes: 'هيكل حديدي قوي وثابت'),
          InspectionItem(id: 'g10_2', serialNo: 2, description: 'شد مسامير الربط عند اقطاب البطاريات', status: InspectionStatus.good, notes: 'تمت مراجعة عزم الشد'),
          InspectionItem(id: 'g10_3', serialNo: 3, description: 'النظافة والغبار عند البطاريات', status: InspectionStatus.good, notes: 'نظيفة وممسوحة'),
          InspectionItem(id: 'g10_4', serialNo: 4, description: 'فرق الجهد الكلي للبطاريات في الراك', status: InspectionStatus.good, notes: '51.8V متوازن'),
          InspectionItem(id: 'g10_5', serialNo: 5, description: 'عدم وجود انتفاخ في البطاريات', status: InspectionStatus.good, notes: 'خلايا سليمة تماماً'),
          InspectionItem(id: 'g10_6', serialNo: 6, description: 'عدم وجود تسريب او أكسدة عند اقطاب البطاريات', status: InspectionStatus.good, notes: 'لا يوجد أكسدة'),
          InspectionItem(id: 'g10_7', serialNo: 7, description: 'درجة الحرارة عند البطاريات', status: InspectionStatus.good, notes: '24.5°C'),
          InspectionItem(id: 'g10_8', serialNo: 8, description: 'سلامة وثبات الكابلات على البزبار في راكات البطاريات', status: InspectionStatus.good, notes: 'مثبتة ومعزولة'),
        ],
      ),
    ];
  }

  /// 96 battery cells (4 strings x 24 cells) with 0.0 values for engineer input
  static List<BatteryMeasurement> get defaultBatteryMeasurements => blankBatteryMeasurements;

  /// System operational telemetry measurements with blank measured values
  static List<OperationalData> get defaultOperationalData => blankOperationalData;

  /// 16 Solar PV Strings measurements with 0.0 values for engineer input
  static List<StringMeasurement> get defaultStringMeasurements => blankStringMeasurements;

  /// Blank inspection groups for fresh inspection sessions (no pre-filled statuses)
  static List<InspectionGroup> get blankInspectionGroups {
    return defaultInspectionGroups.map((group) {
      return group.copyWith(
        items: group.items.map((item) {
          return item.copyWith(
            status: InspectionStatus.uninspected,
            notes: '',
          );
        }).toList(),
      );
    }).toList();
  }

  /// Blank 96 battery cells with zero measurements for new sessions
  static List<BatteryMeasurement> get blankBatteryMeasurements {
    final list = <BatteryMeasurement>[];
    for (int i = 1; i <= 96; i++) {
      final stringNum = ((i - 1) ~/ 24) + 1;
      list.add(BatteryMeasurement(
        cellNumber: i,
        stringNumber: stringNum,
        voltage: 0.0,
        temperature: 0.0,
        boltTorque: 0.0,
        internalResistance: 0.0,
        notes: '',
      ));
    }
    return list;
  }

  /// Blank operational telemetry for new sessions
  static List<OperationalData> get blankOperationalData {
    return [
      const OperationalData(id: 'op_load', parameter: 'الحمل على الإنفرتر', unit: 'W', measuredValue: '', standardRange: '< 5000', status: '', notes: ''),
      const OperationalData(id: 'op_load_1', parameter: 'الحمل على الإنفرتر #1', unit: 'W', measuredValue: '', standardRange: '< 5000', status: '', notes: ''),
      const OperationalData(id: 'op_load_2', parameter: 'الحمل على الإنفرتر #2', unit: 'W', measuredValue: '', standardRange: '< 5000', status: '', notes: ''),
      const OperationalData(id: 'op_load_3', parameter: 'الحمل على الإنفرتر #3', unit: 'W', measuredValue: '', standardRange: '< 5000', status: '', notes: ''),
      const OperationalData(id: 'op_load_4', parameter: 'الحمل على الإنفرتر #4', unit: 'W', measuredValue: '', standardRange: '< 5000', status: '', notes: ''),
      const OperationalData(id: 'op_load_5', parameter: 'الحمل على الإنفرتر #5', unit: 'W', measuredValue: '', standardRange: '< 5000', status: '', notes: ''),
      const OperationalData(id: 'op_load_6', parameter: 'الحمل على الإنفرتر #6', unit: 'W', measuredValue: '', standardRange: '< 5000', status: '', notes: ''),
      const OperationalData(id: 'op_ac_v', parameter: 'فرق جهد الخرج (متردد) للإنفرتر', unit: 'Vac', measuredValue: '', standardRange: '220 - 230', status: '', notes: ''),
      const OperationalData(id: 'op_dc_v', parameter: 'فرق جهد الدخول (مستمر) للإنفرتر', unit: 'Vdc', measuredValue: '', standardRange: '48.0 - 54.0', status: '', notes: ''),
      const OperationalData(id: 'op_cc_i', parameter: 'التيار المنتج بمصفوفة الألواح لمنظم الشحن', unit: 'Adc', measuredValue: '', standardRange: '60 - 100', status: '', notes: ''),
      const OperationalData(id: 'op_cc_v', parameter: 'فرق جهد مصفوفة الألواح لمنظم الشحن', unit: 'Vdc', measuredValue: '', standardRange: '150 - 250', status: '', notes: ''),
      const OperationalData(id: 'op_freq', parameter: 'تردد التيار المتردد (Frequency)', unit: 'Hz', measuredValue: '', standardRange: '49.8 - 50.2', status: '', notes: ''),
      const OperationalData(id: 'op_temp', parameter: 'درجة حرارة غرفة البطاريات والتحكم', unit: '°C', measuredValue: '', standardRange: '20 - 25', status: '', notes: ''),
    ];
  }

  /// Blank 16 PV strings measurements with zero values for new sessions
  static List<StringMeasurement> get blankStringMeasurements {
    final list = <StringMeasurement>[];
    for (int i = 1; i <= 16; i++) {
      list.add(StringMeasurement(
        stringNumber: i,
        panelCount: 0,
        openCircuitVoltageVoc: 0.0,
        shortCircuitCurrentIsc: 0.0,
        operatingVoltageVmp: 0.0,
        operatingCurrentImp: 0.0,
        solarIrradiance: 0.0,
        notes: '',
      ));
    }
    return list;
  }

  /// Blank attendance list for new sessions
  static List<AttendanceRecord> get blankAttendanceList {
    return [
      const AttendanceRecord(serialNo: 1, name: '', role: 'مهندس صيانة المنظومة (رئيس الفريق)', affiliation: '', notes: ''),
      const AttendanceRecord(serialNo: 2, name: '', role: 'فني كهرباء وطاقة شمسية', affiliation: '', notes: ''),
      const AttendanceRecord(serialNo: 3, name: '', role: 'فني بطاريات وتكييف', affiliation: '', notes: ''),
      const AttendanceRecord(serialNo: 4, name: '', role: 'ممثل المرفق الخدمي / المستفيد', affiliation: '', notes: ''),
    ];
  }

  /// Team attendance list with blank names
  static List<AttendanceRecord> get defaultAttendanceList => blankAttendanceList;

  /// Default full report matching the institutional solar maintenance report 1:1
  static Report get sampleDialysisReport {
    return Report(
      id: 'rep_abs_dialysis_001',
      templateId: 'tmpl_solar_11p',
      title: 'تقرير الصيانة الدورية لمنظومة الطاقة الشمسية - مكتب الأتقان الهندسي',
      reportNumber: 'REP-SOL-2025-08',
      contractNumber: '1010720',
      visitDate: '2025/08/15',
      visitTime: '09:00 ص - 03:30 م',
      visitNumber: '1',
      description: 'تقرير الزيارة الدورية الشاملة لصيانة وفحص منظومة الطاقة الشمسية ومصفوفة البطاريات بمكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة.',
      projectInfo: const ProjectInfo(
        projectName: 'توريد وتركيب وصيانة 21 منظومة طاقة شمسية منفصلة عن الشبكة لعدد من المنشآت في عدة محافظات.',
        ownerEntity: 'وزارة الصحة العامة و البيئة',
        implementingContractor: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
        funder: 'مكتب الأمم المتحدة لخدمات المشاريع- صنعاء',
        governorate: 'صنعاء',
        district: 'السبعين',
        location: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
      ),
      facilityInfo: const FacilityInfo(
        facilityName: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
        facilityNameEn: 'Al-Etqan Engineering Office for Engineering Services and Energy Solutions',
        facilityType: 'مرفق هندسي وخدمي',
        category: 'CAT 8',
        contactPerson: 'م. أحمد سعيد العنسي - مدير المكتب',
        phone: '777 123 456',
        email: 'info@aletqan-solar.ye',
      ),
      systemSpecs: const SystemSpecs(
        systemType: 'منظومة طاقة شمسية منفصلة عن الشبكة Off-Grid',
        capacityKw: '57.6 kW',
        panelsCountAndWatt: '96 x 600Wp',
        invertersCapacity: '10KVA',
        invertersCount: '6',
        chargeControllersCapacity: '100 A (150-250) Vdc',
        chargeControllersCount: '13',
        batteryUnitsCapacity: '2500Ah',
        batteryUnitsCount: '96 x 2V',
        otherAppliances: 'مكيف هواء 1 طن عدد 2',
      ),
      inspectionGroups: defaultInspectionGroups,
      batteryMeasurements: defaultBatteryMeasurements,
      operationalData: defaultOperationalData,
      stringMeasurements: defaultStringMeasurements,
      correctiveActions: [
        const CorrectiveAction(
          id: 'ca_1',
          observation: 'تراكم غبار خفيف على المجموعة الثالثة من الألواح',
          correctiveAction: 'تم تنظيفها بالكامل بالماء المقطر وأدوات مخصصة',
          responsiblePerson: 'فريق الصيانة',
          targetDate: 'تم الإنجاز أثناء الزيارة',
          priority: 'منخفضة',
        ),
        const CorrectiveAction(
          id: 'ca_2',
          observation: 'فلتر الهواء للمكيف رقم 1 يحتاج غسيل دوري',
          correctiveAction: 'تم تنظيف الفلتر وإعادة تركيبه وفحص غاز التبريد',
          responsiblePerson: 'فني التكييف',
          targetDate: 'تم الإنجاز أثناء الزيارة',
          priority: 'متوسطة',
        ),
      ],
      photos: [],
      signatures: [
        const ReportSignature(
          id: 'sig_1',
          role: 'مهندس الصيانة المسؤول',
          signerName: 'م. أحمد سعيد العنسي',
          jobTitle: 'مهندس صيانة أول - مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
          signedDate: '2025/08/15',
        ),
        const ReportSignature(
          id: 'sig_2',
          role: 'ممثل المرفق الخدمي / المستفيد',
          signerName: 'د. عبد الله أحمد',
          jobTitle: 'مدير مكتب الأتقان الهندسي',
          signedDate: '2025/08/15',
        ),
      ],
      approvalStatement: const ApprovalStatement(
        projectTitle: 'توريد وتركيب وصيانة 21 منظومة طاقة شمسية منفصلة عن الشبكة',
        facilityName: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
        beneficiaryRepName: 'د. عبد الله أحمد',
        beneficiaryRepRole: 'مدير المكتب (ممثل المنشأة)',
        contractorRepName: 'م. أحمد سعيد العنسي',
        contractorRepRole: 'مهندس الصيانة المعتمد',
        approvalDate: '2025/08/15',
      ),
      attendanceList: defaultAttendanceList,
      showNeedsInReport: true,
      requestedNeeds: [
        MaintenanceNeedItem(
          id: 'need_sample_01',
          facilityName: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
          currentVisitNumber: '1',
          targetVisitNumber: '2',
          name: 'قاطع تيار DC 125A 2P (شنايدر)',
          quantity: 2,
          unit: 'حبة',
          category: 'قواطع DC',
          priority: NeedPriority.critical,
          reason: 'تلف حراري في القاطع نتيجة الحمل الزائد ويشكل خطورة على الإنفرتر رقم 2',
          relatedInspectionItemId: 'item_4_1',
          relatedInspectionItemTitle: 'قواطع التيار المستمر (DC Breakers)',
          createdAt: DateTime(2025, 8, 15),
        ),
        MaintenanceNeedItem(
          id: 'need_sample_02',
          facilityName: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
          currentVisitNumber: '1',
          targetVisitNumber: '2',
          name: 'كابل طاقة شمسية 16mm² مع طقم موصلات MC4',
          quantity: 25,
          unit: 'متر',
          category: 'كابلات وتوصيلات',
          priority: NeedPriority.urgent,
          reason: 'استبدال وصلة التغذية لسلسلة الألواح المتضررة من العوامل الجوية',
          relatedInspectionItemId: 'item_2_1',
          relatedInspectionItemTitle: 'كابلات التيار المستمر DC Cables',
          createdAt: DateTime(2025, 8, 15),
        ),
      ],
      status: ReportStatus.completed,
      createdAt: DateTime(2025, 8, 15),
      updatedAt: DateTime(2025, 8, 15),
    );
  }
}
