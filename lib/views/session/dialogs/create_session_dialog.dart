import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/yemen_locations.dart';
import '../../../models/report.dart';
import '../../../models/report_template.dart';
import '../../../models/site.dart';
import '../../../models/client.dart';
import '../../../state/reports_provider.dart';
import '../../../state/templates_provider.dart';
import '../../../state/clients_provider.dart';
import '../../../state/sites_provider.dart';
import '../../../state/branding_provider.dart';
import '../../editor/report_editor_screen.dart';
import '../maintenance_session_screen.dart';
import '../../sites/site_form_screen.dart';
import '../../../core/widgets/yemeni_phone_field.dart';

/// أنماط إنشاء التقرير / جلسة الصيانة
enum SessionCreationMode {
  fromSiteDirectory,
  fromExisting,
}

/// شاشة ونموذج بدء صيانة جديدة وإدخال بيانات التقرير
/// مصممة وفق أحدث معايير وتطبيقات الهواتف الذكية:
/// - شاشة كاملة متجاوبة (Full-Screen Modal) تمنع تعارض الإيماءات وحجب لوحة المفاتيح.
/// - بطاقات تبويب منظمة بصرياً (المصدر، المشروع، المنشأة، مواصفات المنظومة).
/// - لواحق قياسية للوحدات (kW, Ah, KVA) مع أزرار عدّ سريعة (+ / -) للكميات.
/// - رقاقات ذكية للاختيارات السريعة وتاريخ/وقت الزيارة.
/// - شريط إجراءات سفلي بارز ومريح للإبهام.
class CreateSessionDialog extends ConsumerStatefulWidget {
  final ReportTemplate? initialTemplate;
  final bool openSessionDirectly;
  final Site? initialSite;
  final Client? initialClient;

  const CreateSessionDialog({
    super.key,
    this.initialTemplate,
    this.openSessionDirectly = true,
    this.initialSite,
    this.initialClient,
  });

  /// نقطة الدخول الثابتة المتوافقة مع كافة الشاشات
  static Future<void> show(
    BuildContext context, {
    ReportTemplate? initialTemplate,
    bool openSessionDirectly = true,
    Site? initialSite,
    Client? initialClient,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateSessionDialog(
          initialTemplate: initialTemplate,
          openSessionDirectly: openSessionDirectly,
          initialSite: initialSite,
          initialClient: initialClient,
        ),
      ),
    );
  }

  @override
  ConsumerState<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<CreateSessionDialog> {
  final ScrollController _scrollController = ScrollController();
  SessionCreationMode _mode = SessionCreationMode.fromSiteDirectory;

  Site? _selectedSite;
  Client? _selectedClient;
  Report? _selectedSourceReport;
  List<int> _activeBatteryGroups = [1, 2, 3, 4];
  List<int> _activeCombinerBoxes = [1, 2, 3, 4];

  bool _isSubmitting = false;
  bool _hasUserEdited = false;

  // 1. حقول بيانات المشروع والتعاقد
  final _projectNameCtrl = TextEditingController();
  final _contractNumberCtrl = TextEditingController();
  final _ownerEntityCtrl = TextEditingController();
  final _funderCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  final _governorateCtrl = TextEditingController(text: 'أمانة العاصمة');
  final _districtCtrl = TextEditingController(text: 'السبعين');
  final _locationCtrl = TextEditingController();

  // 2. حقول بيانات المنشأة والزيارة
  final _facilityNameCtrl = TextEditingController();
  final _facilityNameEnCtrl = TextEditingController();
  final _facilityTypeCtrl = TextEditingController(text: 'مستشفى / مركز صحي');
  final _categoryCtrl = TextEditingController(text: 'CAT 8');
  final _visitNumberCtrl = TextEditingController(text: '1');
  final _visitDateCtrl = TextEditingController();
  final _visitTimeCtrl = TextEditingController(text: '09:00 ص - 03:00 م');
  final _contactPersonCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // 3. حقول مواصفات المنظومة
  final _systemTypeCtrl = TextEditingController(text: 'منفصلة عن الشبكة (Off-Grid)');
  final _capacityKwCtrl = TextEditingController(text: '57.6');
  final _panelsCountAndWattCtrl = TextEditingController(text: '96 x 600Wp');
  final _batteryUnitsCapacityCtrl = TextEditingController(text: '2500');
  final _batteryUnitsCountCtrl = TextEditingController(text: '96 x 2V');
  final _invertersCapacityCtrl = TextEditingController(text: '10');
  final _invertersCountCtrl = TextEditingController(text: '6');
  final _chargeControllersCapacityCtrl = TextEditingController(text: '100 A (150-250) Vdc');
  final _chargeControllersCountCtrl = TextEditingController(text: '13');
  final _otherAppliancesCtrl = TextEditingController(text: 'مكيف هواء 1 طن عدد 2');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visitDateCtrl.text =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // ضبط المقاول الافتراضي من هوية المكتب
      final branding = ref.read(brandingProvider);
      if (_contractorCtrl.text.isEmpty && branding.name.isNotEmpty) {
        _contractorCtrl.text = branding.name;
      }

      if (widget.initialSite != null) {
        final clients = ref.read(clientsProvider);
        final client = widget.initialClient ??
            clients.firstWhere(
              (c) => c.id == widget.initialSite!.clientId,
              orElse: () => Client(
                id: widget.initialSite!.clientId,
                nameAr: 'الجهة المالكة',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
        _populateFromSite(widget.initialSite!, client);
      } else if (widget.initialClient != null) {
        setState(() {
          _selectedClient = widget.initialClient;
          _ownerEntityCtrl.text = widget.initialClient!.displayName;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _projectNameCtrl.dispose();
    _contractNumberCtrl.dispose();
    _ownerEntityCtrl.dispose();
    _funderCtrl.dispose();
    _contractorCtrl.dispose();
    _governorateCtrl.dispose();
    _districtCtrl.dispose();
    _locationCtrl.dispose();

    _facilityNameCtrl.dispose();
    _facilityNameEnCtrl.dispose();
    _facilityTypeCtrl.dispose();
    _categoryCtrl.dispose();
    _visitNumberCtrl.dispose();
    _visitDateCtrl.dispose();
    _visitTimeCtrl.dispose();
    _contactPersonCtrl.dispose();
    _phoneCtrl.dispose();

    _systemTypeCtrl.dispose();
    _capacityKwCtrl.dispose();
    _panelsCountAndWattCtrl.dispose();
    _batteryUnitsCapacityCtrl.dispose();
    _batteryUnitsCountCtrl.dispose();
    _invertersCapacityCtrl.dispose();
    _invertersCountCtrl.dispose();
    _chargeControllersCapacityCtrl.dispose();
    _chargeControllersCountCtrl.dispose();
    _otherAppliancesCtrl.dispose();
    super.dispose();
  }

  void _markEdited() {
    if (!_hasUserEdited) {
      _hasUserEdited = true;
    }
  }

  // ─── استيراد بيانات الموقع والعميل ──────────────────────────────────────────
  void _populateFromSite(Site site, Client client) {
    setState(() {
      _selectedSite = site;
      _selectedClient = client;

      // Project Info
      _projectNameCtrl.text = site.projectName.isNotEmpty
          ? site.projectName
          : 'توريد وتركيب وصيانة 21 منظومة طاقة شمسية منفصلة عن الشبكة';
      _contractNumberCtrl.text = site.contractNumber;
      _ownerEntityCtrl.text = client.displayName;
      _funderCtrl.text = site.funderNameAr.isNotEmpty ? site.funderNameAr : 'مكتب الأمم المتحدة لخدمات المشاريع - UNOPS';
      if (site.implementingContractor.isNotEmpty) {
        _contractorCtrl.text = site.implementingContractor;
      }
      _governorateCtrl.text = site.governorate.isNotEmpty ? YemenLocations.normalizeGovernorate(site.governorate) : 'أمانة العاصمة';
      _districtCtrl.text = site.directorate.isNotEmpty ? site.directorate : 'السبعين';
      _locationCtrl.text = site.locationAddress;

      // Facility Info
      _facilityNameCtrl.text = site.nameAr;
      _facilityNameEnCtrl.text = site.nameEn;
      _facilityTypeCtrl.text = site.facilityType.isNotEmpty ? site.facilityType : 'مستشفى / مركز صحي';
      _categoryCtrl.text = site.category.isNotEmpty ? site.category : 'CAT 8';

      // حساب رقم الزيارة التالي
      final allReports = ref.read(reportsProvider);
      final siteReports = allReports
          .where((r) => r.siteId == site.id || r.facilityInfo.facilityName == site.nameAr)
          .toList();
      int nextNum = 1;
      if (siteReports.isNotEmpty) {
        final nums = siteReports.map((r) => int.tryParse(r.visitNumber) ?? 1).toList();
        nums.sort();
        nextNum = nums.last + 1;
      }
      _visitNumberCtrl.text = nextNum.toString();
      _contactPersonCtrl.text = site.contactPerson;
      _phoneCtrl.text = site.phone;

      // System Specs (تجريد الوحدات للحقول الرقمية المباشرة)
      _systemTypeCtrl.text = site.systemSpecs.systemType.isNotEmpty
          ? site.systemSpecs.systemType
          : 'منفصلة عن الشبكة (Off-Grid)';
      _capacityKwCtrl.text = _cleanUnit(site.systemSpecs.capacityKw, 'kW');
      _panelsCountAndWattCtrl.text = site.systemSpecs.panelsCountAndWatt.isNotEmpty
          ? site.systemSpecs.panelsCountAndWatt
          : '96 x 600Wp';
      _batteryUnitsCapacityCtrl.text = _cleanUnit(site.systemSpecs.batteryUnitsCapacity, 'Ah');
      _batteryUnitsCountCtrl.text = site.systemSpecs.batteryUnitsCount.isNotEmpty
          ? site.systemSpecs.batteryUnitsCount
          : '96 x 2V';
      _invertersCapacityCtrl.text = _cleanUnit(site.systemSpecs.invertersCapacity, 'KVA');
      _invertersCountCtrl.text = site.systemSpecs.invertersCount.isNotEmpty
          ? site.systemSpecs.invertersCount
          : '6';
      _chargeControllersCapacityCtrl.text = site.systemSpecs.chargeControllersCapacity.isNotEmpty
          ? site.systemSpecs.chargeControllersCapacity
          : '100 A (150-250) Vdc';
      _chargeControllersCountCtrl.text = site.systemSpecs.chargeControllersCount.isNotEmpty
          ? site.systemSpecs.chargeControllersCount
          : '13';
      _otherAppliancesCtrl.text = site.systemSpecs.otherAppliances;
    });
  }

  // ─── استيراد من تقرير سابق ──────────────────────────────────────────────────
  void _populateFromReport(Report source) {
    setState(() {
      _selectedSourceReport = source;

      // محاولة الربط التلقائي بالعميل والموقع التابعين للتقرير السابق إن وُجدا
      final clients = ref.read(clientsProvider);
      final sites = ref.read(sitesProvider);

      Client? foundClient;
      if (source.clientId.isNotEmpty) {
        foundClient = clients.where((c) => c.id == source.clientId).firstOrNull;
      }

      Site? foundSite;
      if (source.siteId.isNotEmpty) {
        foundSite = sites.where((s) => s.id == source.siteId).firstOrNull;
      }
      if (foundSite == null && source.facilityInfo.facilityName.isNotEmpty) {
        foundSite = sites.where((s) => s.nameAr == source.facilityInfo.facilityName).firstOrNull;
      }
      if (foundClient == null && foundSite != null) {
        foundClient = clients.where((c) => c.id == foundSite!.clientId).firstOrNull;
      }

      if (foundSite != null) _selectedSite = foundSite;
      if (foundClient != null) {
        _selectedClient = foundClient;
        _ownerEntityCtrl.text = foundClient.displayName;
      }

      _projectNameCtrl.text = source.projectInfo.projectName;
      _contractNumberCtrl.text = source.contractNumber;
      if (foundClient == null) {
        _ownerEntityCtrl.text = source.projectInfo.ownerEntity;
      }
      _funderCtrl.text = source.projectInfo.funder;
      _contractorCtrl.text = source.projectInfo.implementingContractor;
      _governorateCtrl.text = source.projectInfo.governorate;
      _districtCtrl.text = source.projectInfo.district;
      _locationCtrl.text = source.projectInfo.location;

      _facilityNameCtrl.text = source.facilityInfo.facilityName;
      _facilityNameEnCtrl.text = source.facilityInfo.facilityNameEn;
      _facilityTypeCtrl.text = source.facilityInfo.facilityType;
      _categoryCtrl.text = source.facilityInfo.category;

      final prevVisitNum = int.tryParse(source.visitNumber) ?? 1;
      _visitNumberCtrl.text = (prevVisitNum + 1).toString();
      _contactPersonCtrl.text = source.facilityInfo.contactPerson;
      _phoneCtrl.text = source.facilityInfo.phone;

      _systemTypeCtrl.text = source.systemSpecs.systemType;
      _capacityKwCtrl.text = _cleanUnit(source.systemSpecs.capacityKw, 'kW');
      _panelsCountAndWattCtrl.text = source.systemSpecs.panelsCountAndWatt;
      _batteryUnitsCapacityCtrl.text = _cleanUnit(source.systemSpecs.batteryUnitsCapacity, 'Ah');
      _batteryUnitsCountCtrl.text = source.systemSpecs.batteryUnitsCount;
      _invertersCapacityCtrl.text = _cleanUnit(source.systemSpecs.invertersCapacity, 'KVA');
      _invertersCountCtrl.text = source.systemSpecs.invertersCount;
      _chargeControllersCapacityCtrl.text = source.systemSpecs.chargeControllersCapacity;
      _chargeControllersCountCtrl.text = source.systemSpecs.chargeControllersCount;
      _otherAppliancesCtrl.text = source.systemSpecs.otherAppliances;

      if (source.activeBatteryGroups.isNotEmpty) {
        _activeBatteryGroups = List<int>.from(source.activeBatteryGroups);
      }
      if (source.activeCombinerBoxes.isNotEmpty) {
        _activeCombinerBoxes = List<int>.from(source.activeCombinerBoxes);
      }
    });
  }

  String _cleanUnit(String val, String unit) {
    if (val.isEmpty) return '';
    return val.replaceAll(unit, '').replaceAll(unit.toLowerCase(), '').trim();
  }

  // ─── تأكيد الخروج عند وجود تعديلات ──────────────────────────────────────────
  Future<bool> _handlePopScope() async {
    if (!_hasUserEdited) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.solarGold, size: 24),
            SizedBox(width: 8),
            Text('تجاهل التعديلات؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'أدخلت بيانات في هذا النموذج، هل أنت متأكد من رغبتك في إلغاء بدء الجلسة والتراجع؟',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('البقاء والإكمال'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تجاهل وخروج'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  // ─── إضافة عميل جديد مباشرة من نموذج إنشاء التقرير ─────────────────────────
  void _showAddClientDialog(BuildContext context) {
    final nameArCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String clientType = 'جهة حكومية / وزارة';

    // حقول اختيارية لإنشاء أول موقع للعميل في خطوة واحدة
    final siteNameCtrl = TextEditingController();
    final siteGovCtrl = TextEditingController(text: 'أمانة العاصمة');
    final siteDistCtrl = TextEditingController(text: 'السبعين');
    bool createSiteTogether = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryNavy, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إضافة عميل جديد / جهة شريكة',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            'سيتم حفظ العميل وتحديده تلقائياً للتقرير الحالي',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Card 1: Client Basic Info
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.apartment_rounded, size: 16, color: AppTheme.primaryNavy),
                          SizedBox(width: 6),
                          Text(
                            'معلومات الجهة الأساسية',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameArCtrl,
                        autofocus: true,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          labelText: 'اسم العميل / الجهة (عربي) *',
                          hintText: 'مثال: وزارة الصحة العامة والسكان',
                          prefixIcon: const Icon(Icons.business_rounded, size: 18, color: AppTheme.primaryNavy),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameEnCtrl,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          labelText: 'اسم العميل (English)',
                          hintText: 'e.g. Ministry of Public Health',
                          prefixIcon: const Icon(Icons.language_rounded, size: 18, color: AppTheme.primaryNavy),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('تصنيف الجهة:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          'جهة حكومية / وزارة',
                          'منظمة دولية / مانحة',
                          'مؤسسة محلية / مجتمعية',
                          'قطاع خاص / شركة',
                        ].map((type) {
                          final isSel = clientType == type;
                          return ChoiceChip(
                            label: Text(type),
                            selected: isSel,
                            backgroundColor: Colors.white,
                            selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.12),
                            side: BorderSide(
                              color: isSel ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
                              width: isSel ? 1.5 : 1.0,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? AppTheme.primaryNavy : AppTheme.textDark,
                            ),
                            onSelected: (sel) {
                              if (sel) setModalState(() => clientType = type);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card 2: Contact
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.contact_phone_rounded, size: 16, color: AppTheme.primaryNavy),
                          SizedBox(width: 6),
                          Text(
                            'ضابط الاتصال والتواصل',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contactCtrl,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          labelText: 'ضابط الاتصال / المسؤول (اختياري)',
                          hintText: 'مثال: د. طارق الحيدري',
                          prefixIcon: const Icon(Icons.person_rounded, size: 18, color: AppTheme.primaryNavy),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                      const SizedBox(height: 10),
                      YemeniPhoneField(
                        controller: phoneCtrl,
                        label: 'رقم الهاتف / الاتصال (اختياري)',
                        hint: '777 123 456',
                        onContactPicked: (contact) {
                          if (contact.name != null && contactCtrl.text.trim().isEmpty) {
                            setModalState(() {
                              contactCtrl.text = contact.name!;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: addressCtrl,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          labelText: 'المقر أو العنوان الرئيسي (اختياري)',
                          hintText: 'مثال: صنعاء - شارع الستين',
                          prefixIcon: const Icon(Icons.place_rounded, size: 18, color: AppTheme.primaryNavy),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Card 3: Optional Quick Site Creation
                Container(
                  decoration: BoxDecoration(
                    color: createSiteTogether ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: createSiteTogether ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => setModalState(() => createSiteTogether = !createSiteTogether),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: createSiteTogether,
                              activeColor: const Color(0xFF16A34A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (v) => setModalState(() => createSiteTogether = v ?? false),
                            ),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'تسجيل موقع / منشأة أولى لهذا العميل مباشرة',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                  ),
                                  Text(
                                    'اختياري: يتيح لك إنشاء الموقع وربطه بالتقرير فوراً في خطوة واحدة',
                                    style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (createSiteTogether) ...[
                        const Divider(height: 16),
                        TextField(
                          controller: siteNameCtrl,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                          decoration: InputDecoration(
                            labelText: 'اسم المنشأة / الموقع الميداني *',
                            hintText: 'مثال: مستشفى عبس الريفي',
                            prefixIcon: const Icon(Icons.location_city_rounded, size: 18, color: Color(0xFF16A34A)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: siteGovCtrl,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'المحافظة',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: siteDistCtrl,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'المديرية',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('حفظ واختيار العميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        onPressed: () async {
                          if (nameArCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('يرجى إدخال اسم العميل بالعربي على الأقل')),
                            );
                            return;
                          }

                          final newClient = await ref.read(clientsProvider.notifier).addClient(
                            nameAr: nameArCtrl.text.trim(),
                            nameEn: nameEnCtrl.text.trim(),
                            clientType: clientType,
                            contactPerson: contactCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            address: addressCtrl.text.trim(),
                          );

                          Site? newSite;
                          if (createSiteTogether && siteNameCtrl.text.trim().isNotEmpty) {
                            newSite = await ref.read(sitesProvider.notifier).addSite(
                              clientId: newClient.id,
                              nameAr: siteNameCtrl.text.trim(),
                              governorate: siteGovCtrl.text.trim(),
                              directorate: siteDistCtrl.text.trim(),
                              facilityType: 'مستشفى / مركز صحي',
                              category: 'CAT 8',
                              contactPerson: contactCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                            );
                          }

                          if (ctx.mounted) Navigator.pop(ctx);

                          HapticFeedback.mediumImpact();
                          _markEdited();
                          setState(() {
                            _selectedClient = newClient;
                            _ownerEntityCtrl.text = newClient.displayName;
                            if (newSite != null) {
                              _populateFromSite(newSite, newClient);
                            } else {
                              _selectedSite = null;
                            }
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  newSite != null
                                      ? 'تم حفظ العميل "${newClient.displayName}" والموقع "${newSite.nameAr}" واختيارهما بنجاح! ✨'
                                      : 'تم حفظ العميل "${newClient.displayName}" واختياره بنجاح! ✨',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: AppTheme.statusGood,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── فتح شاشة إضافة موقع جديد للعميل المحدد ─────────────────────────────────
  Future<void> _openAddSiteForClient(Client client) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SiteFormScreen(clientId: client.id),
      ),
    );
    if (!mounted) return;
    final clientSites = ref.read(sitesProvider).where((s) => s.clientId == client.id).toList();
    if (clientSites.isNotEmpty) {
      final newestSite = clientSites.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
      HapticFeedback.mediumImpact();
      _markEdited();
      setState(() {
        _populateFromSite(newestSite, client);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم اختيار الموقع "${newestSite.nameAr}" وجلب مواصفاته للتقرير بنجاح ✨',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.statusGood,
        ),
      );
    }
  }

  // ─── حفظ وبدء الجلسة / إنشاء التقرير ─────────────────────────────────────────
  Future<void> _submit({required bool startInteractiveSession}) async {
    final resolvedClientId = _selectedClient?.id ?? _selectedSourceReport?.clientId;
    final resolvedSiteId = _selectedSite?.id ?? _selectedSourceReport?.siteId;

    if (resolvedClientId == null || resolvedClientId.isEmpty ||
        resolvedSiteId == null || resolvedSiteId.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى تحديد العميل والموقع أولاً لضمان ترابط الزيارة والتقرير بالدليل الميداني ⚠️',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.solarGold,
        ),
      );
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    if (_facilityNameCtrl.text.trim().isEmpty) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة اسم المنشأة بالعربية'),
          backgroundColor: AppTheme.solarGold,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final projectInfo = ProjectInfo(
        projectName: _projectNameCtrl.text.trim(),
        ownerEntity: _ownerEntityCtrl.text.trim().isNotEmpty
            ? _ownerEntityCtrl.text.trim()
            : (_selectedClient?.displayName ?? ''),
        implementingContractor: _contractorCtrl.text.trim(),
        funder: _funderCtrl.text.trim(),
        governorate: _governorateCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
      );

      final facilityInfo = FacilityInfo(
        facilityName: _facilityNameCtrl.text.trim(),
        facilityNameEn: _facilityNameEnCtrl.text.trim(),
        facilityType: _facilityTypeCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        contactPerson: _contactPersonCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        visitDate: _visitDateCtrl.text.trim(),
        visitNumber: _visitNumberCtrl.text.trim().isEmpty ? '1' : _visitNumberCtrl.text.trim(),
      );

      // تجهيز المواصفات مع الوحدات القياسية
      final cap = _capacityKwCtrl.text.trim();
      final battCap = _batteryUnitsCapacityCtrl.text.trim();
      final invCap = _invertersCapacityCtrl.text.trim();

      final systemSpecs = SystemSpecs(
        systemType: _systemTypeCtrl.text.trim(),
        capacityKw: cap.isNotEmpty ? (cap.endsWith('kW') ? cap : '$cap kW') : '',
        panelsCountAndWatt: _panelsCountAndWattCtrl.text.trim(),
        invertersCapacity: invCap.isNotEmpty ? (invCap.endsWith('KVA') ? invCap : '$invCap KVA') : '',
        invertersCount: _invertersCountCtrl.text.trim(),
        chargeControllersCapacity: _chargeControllersCapacityCtrl.text.trim(),
        chargeControllersCount: _chargeControllersCountCtrl.text.trim(),
        batteryUnitsCapacity: battCap.isNotEmpty ? (battCap.endsWith('Ah') ? battCap : '$battCap Ah') : '',
        batteryUnitsCount: _batteryUnitsCountCtrl.text.trim(),
        otherAppliances: _otherAppliancesCtrl.text.trim(),
      );

      final templates = ref.read(templatesProvider);
      final selectedTemplate = widget.initialTemplate ??
          (templates.isNotEmpty ? templates.first : null);

      final newReport = await ref.read(reportsProvider.notifier).createCustomReport(
        templateId: selectedTemplate?.id ?? 'tmpl_solar_11p',
        contractNumber: _contractNumberCtrl.text.trim(),
        visitNumber: _visitNumberCtrl.text.trim().isEmpty ? '1' : _visitNumberCtrl.text.trim(),
        visitDate: _visitDateCtrl.text.trim(),
        visitTime: _visitTimeCtrl.text.trim(),
        projectInfo: projectInfo,
        facilityInfo: facilityInfo,
        systemSpecs: systemSpecs,
        clientId: resolvedClientId,
        siteId: resolvedSiteId,
        site: _selectedSite,
        client: _selectedClient,
        activeBatteryGroups: _activeBatteryGroups,
        activeCombinerBoxes: _activeCombinerBoxes,
        cloneSourceReport: _mode == SessionCreationMode.fromExisting ? _selectedSourceReport : null,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (startInteractiveSession) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MaintenanceSessionScreen(reportId: newReport.id),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportEditorScreen(reportId: newReport.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إنشاء التقرير: $e'),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUserEdited,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _handlePopScope();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildAppBar(),
          body: SingleChildScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. بطاقة اختيار المسار والمنشأة المستهدفة
                _buildSourceAndSiteCard(),
                const SizedBox(height: 16),

                // 2. بطاقة بيانات المشروع والتعاقد
                _buildProjectInfoCard(),
                const SizedBox(height: 16),

                // 3. بطاقة بيانات المنشأة وتفاصيل الزيارة
                _buildFacilityAndVisitCard(),
                const SizedBox(height: 16),

                // 4. بطاقة المواصفات الفنية المتقدمة للمنظومة
                _buildSystemSpecsCard(),
              ],
            ),
          ),
          bottomNavigationBar: _buildStickyBottomBar(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.textDark,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppTheme.textDark),
        onPressed: () async {
          final shouldLeave = await _handlePopScope();
          if (shouldLeave && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بدء صيانة جديدة / تقرير جديد',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryNavy,
            ),
          ),
          Text(
            'تهيئة بيانات المشروع والموقع ومواصفات المنظومة',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: AppTheme.textMuted),
          tooltip: 'إرشادات الإدخال',
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('إرشادات إعداد الزيارة'),
                content: const Text(
                  '1. اختر العميل والموقع ليتم استيراد كافة المواصفات المحفوظة تلقائياً.\n'
                  '2. يمكنك تعديل أي مواصفات فنية قبل بدء الزيارة لتطابق الواقع الميداني.\n'
                  '3. ستنتقل مباشرة إما لجلسة الفحص الميداني التفاعلية أوفلاين أو لمحرر التقرير الشامل.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً')),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // البطاقة 1: مصدر الزيارة والمنشأة المستهدفة
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSourceAndSiteCard() {
    final clients = ref.watch(clientsProvider);
    final sites = ref.watch(sitesProvider);
    final existingReports = ref.watch(reportsProvider);

    final availableSites = _selectedClient != null
        ? sites.where((s) => s.clientId == _selectedClient!.id).toList()
        : <Site>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.solarGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.domain_verification_rounded, color: AppTheme.solarGold, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. الموقع والمنشأة المستهدفة',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    Text(
                      'حدد الموقع لجلب المواصفات التعاقدية والتاريخية تلقائياً',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // محول نمط الإنشاء (دليل المواقع / استنساخ من سابق)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildSegmentTab(
                  mode: SessionCreationMode.fromSiteDirectory,
                  label: 'من دليل المواقع الميدانية',
                  icon: Icons.location_city_rounded,
                ),
                _buildSegmentTab(
                  mode: SessionCreationMode.fromExisting,
                  label: 'استنساخ من تقرير سابق',
                  icon: Icons.history_edu_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_mode == SessionCreationMode.fromSiteDirectory) ...[
            if (clients.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.solarGold, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'لا يوجد عملاء مسجلون بالدليل بعد. أضف عميلاً وموقعاً أولاً.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.solarGold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _showAddClientDialog(context),
                      child: const Text('إضافة عميل', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 1. اختيار العميل مع أيقونة إضافة عميل جديد
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Client>(
                      key: ValueKey('client_dropdown_${_selectedClient?.id}'),
                      initialValue: _selectedClient,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'الجهة المالكة / العميل *',
                        hintText: 'اختر الجهة المالكة...',
                        prefixIcon: const Icon(Icons.business_rounded, color: AppTheme.primaryNavy, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: clients.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (client) {
                        if (client != null) {
                          HapticFeedback.selectionClick();
                          _markEdited();
                          setState(() {
                            _selectedClient = client;
                            _selectedSite = null;
                            _ownerEntityCtrl.text = client.displayName;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'إضافة عميل جديد',
                    child: Material(
                      color: AppTheme.primaryNavy,
                      borderRadius: BorderRadius.circular(10),
                      elevation: 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showAddClientDialog(context),
                        child: Container(
                          height: 48,
                          width: 48,
                          alignment: Alignment.center,
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. اختيار الموقع مع أيقونة إضافة موقع ميداني جديد
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Site>(
                      key: ValueKey('site_dropdown_${_selectedSite?.id}'),
                      initialValue: _selectedSite,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'الموقع الميداني / المنشأة *',
                        hintText: _selectedClient == null ? 'اختر العميل أولاً لعرض مواقعه' : 'اختر المنشأة...',
                        prefixIcon: const Icon(Icons.location_on_rounded, color: AppTheme.primaryNavy, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: availableSites.map((site) {
                        final loc = [site.governorate, site.directorate].where((s) => s.isNotEmpty).join(' • ');
                        return DropdownMenuItem(
                          value: site,
                          child: Text(
                            loc.isNotEmpty ? '${site.nameAr} ($loc)' : site.nameAr,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _selectedClient == null
                          ? null
                          : (site) {
                              if (site != null) {
                                HapticFeedback.selectionClick();
                                _markEdited();
                                _populateFromSite(site, _selectedClient!);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: _selectedClient != null ? 'إضافة موقع ميداني جديد لهذا العميل' : 'حدد العميل أولاً لإضافة موقع',
                    child: Material(
                      color: _selectedClient != null ? AppTheme.brandCyan : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                      elevation: _selectedClient != null ? 1 : 0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _selectedClient != null ? () => _openAddSiteForClient(_selectedClient!) : null,
                        child: Container(
                          height: 48,
                          width: 48,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.add_location_alt_rounded,
                            color: _selectedClient != null ? Colors.white : AppTheme.textMuted,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedClient != null && availableSites.isEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا توجد مواقع مسجلة للعميل "${_selectedClient!.displayName}" بعد.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF15803D),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                        label: const Text('إضافة موقع الآن', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () => _openAddSiteForClient(_selectedClient!),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ] else ...[
            // استنساخ من تقرير سابق
            DropdownButtonFormField<Report>(
              initialValue: _selectedSourceReport,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'التقرير السابق المستهدف *',
                hintText: 'اختر المنشأة لنسخ مواصفاتها وحساب رقم الزيارة التالي...',
                prefixIcon: const Icon(Icons.history_rounded, color: AppTheme.brandCyan, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: existingReports.map((rep) {
                final vNum = rep.visitNumber.isNotEmpty ? rep.visitNumber : '1';
                final fac = rep.facilityInfo.facilityName.isNotEmpty ? rep.facilityInfo.facilityName : rep.title;
                return DropdownMenuItem(
                  value: rep,
                  child: Text(
                    '$fac (زيارة $vNum) - عقد: ${rep.contractNumber}',
                    style: const TextStyle(fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (rep) {
                if (rep != null) {
                  HapticFeedback.selectionClick();
                  _markEdited();
                  _populateFromReport(rep);
                }
              },
            ),
            if (_selectedSourceReport != null && _selectedSourceReport!.requestedNeeds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, color: AppTheme.solarGold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'يوجد ${_selectedSourceReport!.requestedNeeds.length} مواد مطلوبة من الزيارة السابقة للتثبيت في هذه الزيارة.',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          if (_selectedSite != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.statusGood.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.statusGood.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.statusGood, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'تم ربط الموقع وتعبئة مواصفات ${_selectedSite!.nameAr} تلقائياً.',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.statusGood, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_mode == SessionCreationMode.fromExisting && _selectedSourceReport != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.link_off_rounded, color: AppTheme.solarGold, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'التقرير السابق غير مرتبط بموقع في الدليل',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'يرجى اختيار العميل والموقع الميداني لإقران التقرير الجديد بهما:',
                    style: TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Client>(
                    initialValue: _selectedClient,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'الجهة المالكة / العميل *',
                      isDense: true,
                      prefixIcon: const Icon(Icons.business_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: clients.map((c) => DropdownMenuItem(value: c, child: Text(c.displayName, style: const TextStyle(fontSize: 12.5)))).toList(),
                    onChanged: (c) {
                      if (c != null) {
                        setState(() {
                          _selectedClient = c;
                          _selectedSite = null;
                        });
                      }
                    },
                  ),
                  if (_selectedClient != null) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Site>(
                      initialValue: _selectedSite,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'الموقع الميداني *',
                        isDense: true,
                        prefixIcon: const Icon(Icons.location_on_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: availableSites.map((s) => DropdownMenuItem(value: s, child: Text(s.nameAr, style: const TextStyle(fontSize: 12.5)))).toList(),
                      onChanged: (s) {
                        if (s != null) {
                          setState(() {
                            _selectedSite = s;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required SessionCreationMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _mode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _mode = mode);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isSelected ? AppTheme.primaryNavy : AppTheme.textMuted),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.primaryNavy : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // البطاقة 2: بيانات المشروع والتعاقد
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildProjectInfoCard() {
    return _buildCollapsibleSectionCard(
      title: '2. بيانات المشروع والتعاقد الرسمي',
      subtitle: 'بيانات المشروع، العقد، الجهات المعنية والموقع الجغرافي',
      icon: Icons.article_rounded,
      iconColor: AppTheme.brandCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم المشروع
          _buildStandardInput(
            controller: _projectNameCtrl,
            label: 'اسم المشروع الرسمي',
            hint: 'مثال: توريد وتركيب وصيانة 21 منظومة طاقة شمسية منفصلة عن الشبكة',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 12),

          // رقم العقد والجهة الممولة
          Row(
            children: [
              Expanded(
                child: _buildStandardInput(
                  controller: _contractNumberCtrl,
                  label: 'رقم العقد',
                  hint: 'مثال: 1010720',
                  icon: Icons.tag_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStandardInput(
                  controller: _funderCtrl,
                  label: 'الجهة الممولة (UNOPS)',
                  hint: 'مكتب الأمم المتحدة لخدمات المشاريع',
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'جهات التمويل المقترحة:',
            items: const [
              _QuickPresetItem(label: 'مكتب الأمم المتحدة لخدمات المشاريع - UNOPS', icon: Icons.public_rounded),
              _QuickPresetItem(label: 'منظمة الصحة العالمية - WHO', icon: Icons.health_and_safety_rounded),
              _QuickPresetItem(label: 'اليونيسف - UNICEF', icon: Icons.child_care_rounded),
              _QuickPresetItem(label: 'البرنامج السعودي لتنمية وإعمار اليمن', icon: Icons.handshake_rounded),
            ],
            currentValue: _funderCtrl.text,
            onSelected: (val) {
              _markEdited();
              setState(() => _funderCtrl.text = val);
            },
          ),
          const SizedBox(height: 12),

          // الجهة المالكة والمقاول
          Row(
            children: [
              Expanded(
                child: _buildStandardInput(
                  controller: _ownerEntityCtrl,
                  label: 'الجهة المالكة / الوزارة',
                  hint: 'وزارة الصحة العامة والسكان',
                  icon: Icons.account_balance_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStandardInput(
                  controller: _contractorCtrl,
                  label: 'المقاول المنفذ',
                  hint: 'مكتب الأتقان الهندسي',
                  icon: Icons.engineering_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'الجهات المالكة الشائعة:',
            items: const [
              _QuickPresetItem(label: 'وزارة الصحة العامة والسكان', icon: Icons.local_hospital_rounded),
              _QuickPresetItem(label: 'المؤسسة العامة للكهرباء', icon: Icons.electrical_services_rounded),
              _QuickPresetItem(label: 'وزارة المياه والبيئة', icon: Icons.water_drop_rounded),
            ],
            currentValue: _ownerEntityCtrl.text,
            onSelected: (val) {
              _markEdited();
              setState(() => _ownerEntityCtrl.text = val);
            },
          ),
          const SizedBox(height: 14),

          // شريط الموقع الجغرافي (محافظة ومديرية)
          const Text(
            'الموقع الجغرافي والإداري للمنظومة:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final effectiveGov = YemenLocations.normalizeGovernorate(_governorateCtrl.text);
              final dists = YemenLocations.getDistrictsFor(effectiveGov);
              final effectiveDist = dists.contains(_districtCtrl.text)
                  ? _districtCtrl.text
                  : (dists.isNotEmpty ? dists.first : '');

              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('gov_$effectiveGov'),
                      initialValue: effectiveGov,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'المحافظة',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        prefixIcon: const Icon(Icons.location_city_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: YemenLocations.governorates.map((g) {
                        return DropdownMenuItem(
                          value: g,
                          child: Text(
                            g,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (gov) {
                        if (gov != null) {
                          _markEdited();
                          setState(() {
                            _governorateCtrl.text = gov;
                            final newDists = YemenLocations.getDistrictsFor(gov);
                            _districtCtrl.text = newDists.isNotEmpty ? newDists.first : '';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('dist_${effectiveGov}_$effectiveDist'),
                      initialValue: effectiveDist.isNotEmpty ? effectiveDist : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'المديرية',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        prefixIcon: const Icon(Icons.map_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: dists.map((d) {
                        return DropdownMenuItem(
                          value: d,
                          child: Text(
                            d,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (dist) {
                        if (dist != null) {
                          _markEdited();
                          setState(() => _districtCtrl.text = dist);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _buildStandardInput(
            controller: _locationCtrl,
            label: 'الموقع الدقيق / القرية / المرفق',
            hint: 'مثال: عزلة بني حسن - مبنى الطوارئ العام',
            icon: Icons.pin_drop_rounded,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // البطاقة 3: بيانات المنشأة والزيارة
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildFacilityAndVisitCard() {
    return _buildCollapsibleSectionCard(
      title: '3. بيانات المنشأة وموعد الزيارة',
      subtitle: 'اسم المرفق، نوعه، الفئة وتوقيت الزيارة والمسؤول المستلم',
      icon: Icons.local_hospital_rounded,
      iconColor: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسما المنشأة (عربي وإنجليزي)
          _buildStandardInput(
            controller: _facilityNameCtrl,
            label: 'اسم المنشأة بالعربية *',
            hint: 'مثال: مستشفى الثورة العام - مركز الغسيل الكلوي',
            icon: Icons.local_hospital_outlined,
          ),
          const SizedBox(height: 12),
          _buildStandardInput(
            controller: _facilityNameEnCtrl,
            label: 'اسم المنشأة بالإنجليزية (Facility Name En)',
            hint: 'مثال: Al-Thawra General Hospital - Dialysis Center',
            icon: Icons.translate_rounded,
          ),
          const SizedBox(height: 12),

          // نوع المنشأة والفئة مع رقاقات سريعة
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildStandardInput(
                  controller: _facilityTypeCtrl,
                  label: 'نوع المنشأة',
                  hint: 'مستشفى / مركز صحي',
                  icon: Icons.category_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildStandardInput(
                  controller: _categoryCtrl,
                  label: 'الفئة (Category)',
                  hint: 'CAT 8',
                  icon: Icons.grade_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'نوع المنشأة الشائع:',
            items: const [
              _QuickPresetItem(label: 'مستشفى عام', icon: Icons.local_hospital_rounded),
              _QuickPresetItem(label: 'مركز صحي', icon: Icons.healing_rounded),
              _QuickPresetItem(label: 'مركز غسيل كلى', icon: Icons.medical_services_rounded),
              _QuickPresetItem(label: 'مستشفى ريفي', icon: Icons.apartment_rounded),
              _QuickPresetItem(label: 'وحدة صحية', icon: Icons.health_and_safety_rounded),
            ],
            currentValue: _facilityTypeCtrl.text,
            onSelected: (val) {
              _markEdited();
              setState(() => _facilityTypeCtrl.text = val);
            },
          ),
          const SizedBox(height: 14),

          // توقيت وتاريخ الزيارة ورقمها
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildStandardInput(
                  controller: _visitDateCtrl,
                  label: 'تاريخ الزيارة',
                  hint: 'YYYY/MM/DD',
                  icon: Icons.calendar_today_rounded,
                  readOnly: true,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      _markEdited();
                      setState(() {
                        _visitDateCtrl.text =
                            '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildCounterField(
                  controller: _visitNumberCtrl,
                  label: 'رقم الزيارة',
                  icon: Icons.tag_rounded,
                  min: 1,
                  max: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // وقت الزيارة
          _buildStandardInput(
            controller: _visitTimeCtrl,
            label: 'وقت وفترة الزيارة',
            hint: '09:00 ص - 03:00 م',
            icon: Icons.access_time_rounded,
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'فترة الزيارة الشائعة:',
            items: const [
              _QuickPresetItem(label: '09:00 ص - 03:00 م', icon: Icons.wb_sunny_rounded),
              _QuickPresetItem(label: '08:30 ص - 01:30 م', icon: Icons.schedule_rounded),
              _QuickPresetItem(label: 'فترة صباحية (فحص شامل)', icon: Icons.checklist_rounded),
              _QuickPresetItem(label: 'فترة مسائية (طوارئ)', icon: Icons.nights_stay_rounded),
            ],
            currentValue: _visitTimeCtrl.text,
            onSelected: (val) {
              _markEdited();
              setState(() => _visitTimeCtrl.text = val);
            },
          ),
          const SizedBox(height: 14),

          // مسؤول المنشأة ورقم الهاتف اليمني (Full Width Stacked)
          _buildStandardInput(
            controller: _contactPersonCtrl,
            label: 'مسؤول المنشأة / المستلم',
            hint: 'د. عبد الله أحمد',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 12),
          YemeniPhoneField(
            controller: _phoneCtrl,
            label: 'رقم هاتف مسؤول المنشأة للتواصل',
            hint: '777 123 456',
            onContactPicked: (contact) {
              if (contact.name != null && _contactPersonCtrl.text.trim().isEmpty) {
                _markEdited();
                setState(() => _contactPersonCtrl.text = contact.name!);
              }
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // البطاقة 4: المواصفات الفنية القياسية للمنظومة
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSystemSpecsCard() {
    return _buildCollapsibleSectionCard(
      title: '4. المواصفات الفنية لمنظومة الطاقة الشمسية',
      subtitle: 'مصفوفة التوليد، العواكس، المنظمات، والبطاريات بالوحدات المعيارية',
      icon: Icons.solar_power_rounded,
      iconColor: AppTheme.primaryNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نوع المنظومة
          _buildStandardInput(
            controller: _systemTypeCtrl,
            label: 'نوع المنظومة الشمسية',
            hint: 'منفصلة عن الشبكة (Off-Grid) / هجينة (Hybrid)',
            icon: Icons.alt_route_rounded,
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'نوع المنظومة المقترح:',
            items: const [
              _QuickPresetItem(label: 'منفصلة عن الشبكة (Off-Grid)', icon: Icons.power_off_rounded),
              _QuickPresetItem(label: 'هجينة (Hybrid)', icon: Icons.autorenew_rounded),
              _QuickPresetItem(label: 'متصلة بالشبكة (On-Grid)', icon: Icons.electrical_services_rounded),
            ],
            currentValue: _systemTypeCtrl.text,
            onSelected: (val) {
              _markEdited();
              setState(() => _systemTypeCtrl.text = val);
            },
          ),
          const SizedBox(height: 14),

          // ─── القسم الفرعي أ: الألواح والقدرة الكلية ─────────────────────────────
          _buildSubSectionHeader('☀️ مصفوفة الألواح والقدرة الإجمالية'),
          Row(
            children: [
              Expanded(
                child: _buildStandardInput(
                  controller: _capacityKwCtrl,
                  label: 'القدرة الإجمالية',
                  hint: '57.6',
                  icon: Icons.bolt_rounded,
                  suffixText: 'kW',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStandardInput(
                  controller: _panelsCountAndWattCtrl,
                  label: 'الألواح (عدد × واط)',
                  hint: '96 x 600Wp',
                  icon: Icons.grid_view_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'مصفوفات الألواح والقدرة القياسية:',
            items: const [
              _QuickPresetItem(label: '96 x 600Wp', subLabel: '57.6 kW', icon: Icons.solar_power_rounded),
              _QuickPresetItem(label: '72 x 550Wp', subLabel: '39.6 kW', icon: Icons.solar_power_rounded),
              _QuickPresetItem(label: '48 x 600Wp', subLabel: '28.8 kW', icon: Icons.solar_power_rounded),
              _QuickPresetItem(label: '32 x 450Wp', subLabel: '14.4 kW', icon: Icons.solar_power_rounded),
              _QuickPresetItem(label: '24 x 400Wp', subLabel: '9.6 kW', icon: Icons.solar_power_rounded),
            ],
            currentValue: _panelsCountAndWattCtrl.text,
            onSelected: (val) {
              _markEdited();
              setState(() {
                _panelsCountAndWattCtrl.text = val;
                if (val == '96 x 600Wp') _capacityKwCtrl.text = '57.6';
                if (val == '72 x 550Wp') _capacityKwCtrl.text = '39.6';
                if (val == '48 x 600Wp') _capacityKwCtrl.text = '28.8';
                if (val == '32 x 450Wp') _capacityKwCtrl.text = '14.4';
                if (val == '24 x 400Wp') _capacityKwCtrl.text = '9.6';
              });
            },
          ),
          const SizedBox(height: 16),

          // ─── القسم الفرعي ب: الإنفرترات والعواكس ────────────────────────────────
          _buildSubSectionHeader('🔄 العواكس والإنفرترات (Inverters)'),
          Row(
            children: [
              Expanded(
                child: _buildStandardInput(
                  controller: _invertersCapacityCtrl,
                  label: 'قدرة العاكس الواحد',
                  hint: '10',
                  icon: Icons.swap_horiz_rounded,
                  suffixText: 'KVA',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCounterField(
                  controller: _invertersCountCtrl,
                  label: 'عدد العواكس',
                  icon: Icons.developer_board_rounded,
                  min: 1,
                  max: 16,
                  suffix: 'عواكس',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'قدرة العاكس الواحد المعتادة:',
            items: const [
              _QuickPresetItem(label: '10 KVA', icon: Icons.bolt_rounded),
              _QuickPresetItem(label: '15 KVA', icon: Icons.bolt_rounded),
              _QuickPresetItem(label: '5 KVA', icon: Icons.bolt_rounded),
              _QuickPresetItem(label: '8 KVA', icon: Icons.bolt_rounded),
              _QuickPresetItem(label: '3 KVA', icon: Icons.bolt_rounded),
            ],
            currentValue: _invertersCapacityCtrl.text.isNotEmpty ? '${_invertersCapacityCtrl.text} KVA' : '',
            onSelected: (val) {
              _markEdited();
              setState(() => _invertersCapacityCtrl.text = val.replaceAll(' KVA', '').trim());
            },
          ),
          const SizedBox(height: 16),

          // ─── القسم الفرعي ج: منظمات الشحن وصناديق التجميع ───────────────────────
          _buildSubSectionHeader('⚡ منظمات الشحن وصناديق التجميع'),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildStandardInput(
                  controller: _chargeControllersCapacityCtrl,
                  label: 'مواصفات منظم الشحن',
                  hint: '100 A (150-250) Vdc',
                  icon: Icons.speed_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildCounterField(
                  controller: _chargeControllersCountCtrl,
                  label: 'عدد المنظمات',
                  icon: Icons.tag_rounded,
                  min: 1,
                  max: 24,
                  suffix: 'منظم',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'مواصفات منظم الشحن الشائعة:',
            items: const [
              _QuickPresetItem(label: '100 A (150-250) Vdc', icon: Icons.speed_rounded),
              _QuickPresetItem(label: '80 A (150 Vdc)', icon: Icons.speed_rounded),
              _QuickPresetItem(label: '60 A (150 Vdc)', icon: Icons.speed_rounded),
            ],
            currentValue: _chargeControllersCapacityCtrl.text,
            onSelected: (val) {
              _markEdited();
              setState(() => _chargeControllersCapacityCtrl.text = val);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'صناديق التجميع النشطة في الزيارة:',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChipOption(
                label: 'صندوقين (1-2)',
                icon: Icons.check_box_outlined,
                isSelected: _activeCombinerBoxes.length == 2 && _activeCombinerBoxes.contains(1) && _activeCombinerBoxes.contains(2),
                onTap: () {
                  _markEdited();
                  setState(() => _activeCombinerBoxes = [1, 2]);
                },
              ),
              _buildChoiceChipOption(
                label: '3 صناديق (1-3)',
                icon: Icons.check_box_outlined,
                isSelected: _activeCombinerBoxes.length == 3 && _activeCombinerBoxes.contains(3),
                onTap: () {
                  _markEdited();
                  setState(() => _activeCombinerBoxes = [1, 2, 3]);
                },
              ),
              _buildChoiceChipOption(
                label: '4 صناديق (1-4)',
                icon: Icons.check_box_outlined,
                isSelected: _activeCombinerBoxes.length == 4,
                onTap: () {
                  _markEdited();
                  setState(() => _activeCombinerBoxes = [1, 2, 3, 4]);
                },
              ),
              _buildChoiceChipOption(
                label: 'كافة الصناديق (1-16)',
                icon: Icons.select_all_rounded,
                isSelected: _activeCombinerBoxes.length == 16,
                onTap: () {
                  _markEdited();
                  setState(() => _activeCombinerBoxes = List.generate(16, (i) => i + 1));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── القسم الفرعي د: مصفوفة البطاريات وتخزين الطاقة ────────────────────
          _buildSubSectionHeader('🔋 مصفوفة البطاريات وتخزين الطاقة'),
          Row(
            children: [
              Expanded(
                child: _buildStandardInput(
                  controller: _batteryUnitsCapacityCtrl,
                  label: 'سعة الخلية / الوحدة',
                  hint: '2500',
                  icon: Icons.battery_charging_full_rounded,
                  suffixText: 'Ah',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStandardInput(
                  controller: _batteryUnitsCountCtrl,
                  label: 'عدد الوحدات والجهد',
                  hint: '96 x 2V',
                  icon: Icons.battery_std_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildQuickPresetSection(
            title: 'تكوينات بنك البطاريات القياسية:',
            items: const [
              _QuickPresetItem(label: '96 x 2V', subLabel: '2500Ah', icon: Icons.battery_charging_full_rounded),
              _QuickPresetItem(label: '48 x 2V', subLabel: '1500Ah', icon: Icons.battery_charging_full_rounded),
              _QuickPresetItem(label: '24 x 2V', subLabel: '1000Ah', icon: Icons.battery_charging_full_rounded),
              _QuickPresetItem(label: '16 x 12V', subLabel: '200Ah', icon: Icons.battery_std_rounded),
              _QuickPresetItem(label: '8 x 12V', subLabel: '200Ah', icon: Icons.battery_std_rounded),
            ],
            currentValue: _batteryUnitsCountCtrl.text,
            onSelected: (val) {
              _markEdited();
              setState(() {
                _batteryUnitsCountCtrl.text = val;
                if (val == '96 x 2V') _batteryUnitsCapacityCtrl.text = '2500';
                if (val == '48 x 2V') _batteryUnitsCapacityCtrl.text = '1500';
                if (val == '24 x 2V') _batteryUnitsCapacityCtrl.text = '1000';
                if (val == '16 x 12V') _batteryUnitsCapacityCtrl.text = '200';
                if (val == '8 x 12V') _batteryUnitsCapacityCtrl.text = '200';
              });
            },
          ),
          const SizedBox(height: 14),

          const Text(
            'مجموعات البطاريات المطلوب تضمينها بالتقرير:',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1, 2, 3, 4].map((g) {
              final isSel = _activeBatteryGroups.contains(g);
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _markEdited();
                  setState(() {
                    if (isSel) {
                      if (_activeBatteryGroups.length > 1) {
                        _activeBatteryGroups.remove(g);
                      }
                    } else {
                      _activeBatteryGroups.add(g);
                    }
                    _activeBatteryGroups.sort();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primaryNavy : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
                      width: isSel ? 1.4 : 1.0,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryNavy.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: isSel ? AppTheme.solarGold : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'المجموعة $g',
                        style: TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(خلايا ${(g - 1) * 24 + 1}-${g * 24})',
                        style: TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 10,
                          color: isSel ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ─── القسم الفرعي هـ: الأحمال الإضافية والتكييف ─────────────────────────
          _buildSubSectionHeader('❄️ أحمال وأجهزة إضافية (أخرى)'),
          _buildStandardInput(
            controller: _otherAppliancesCtrl,
            label: 'المكيفات والأجهزة الإضافية',
            hint: 'مثال: مكيف هواء 1 طن عدد 2 + مضخة مياه',
            icon: Icons.ac_unit_rounded,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // ودجات مساعدة لتنسيق الحقول القياسية والأزرار
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildSubSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryNavy,
        ),
      ),
    );
  }

  Widget _buildCollapsibleSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.7, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStandardInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffixText,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      scrollPadding: const EdgeInsets.all(90),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      onChanged: (_) => _markEdited(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryNavy.withValues(alpha: 0.7)),
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildCounterField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int min = 1,
    int max = 64,
    String suffix = '',
  }) {
    int currentVal = int.tryParse(controller.text.trim()) ?? min;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              InkWell(
                onTap: currentVal > min
                    ? () {
                        HapticFeedback.selectionClick();
                        _markEdited();
                        setState(() {
                          currentVal--;
                          controller.text = currentVal.toString();
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: currentVal > min ? const Color(0xFFF1F5F9) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.remove, size: 16, color: currentVal > min ? AppTheme.primaryNavy : Colors.grey),
                ),
              ),
              Expanded(
                child: Text(
                  suffix.isNotEmpty ? '$currentVal $suffix' : '$currentVal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
              ),
              InkWell(
                onTap: currentVal < max
                    ? () {
                        HapticFeedback.selectionClick();
                        _markEdited();
                        setState(() {
                          currentVal++;
                          controller.text = currentVal.toString();
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: currentVal < max ? AppTheme.primaryNavy.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.add, size: 16, color: currentVal < max ? AppTheme.primaryNavy : Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChipOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.solarGold),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(icon, size: 13, color: const Color(0xFF64748B)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Almarai',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPresetSection({
    String? title,
    required List<_QuickPresetItem> items,
    String? currentValue,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 2, top: 4),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 13, color: AppTheme.solarGold),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Almarai',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: items.map((item) {
            final bool selected = currentValue != null &&
                currentValue.trim().isNotEmpty &&
                (currentValue.trim() == item.label.trim() ||
                    (item.subLabel != null && currentValue.contains(item.label)));

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(item.label);
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryNavy : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
                    width: selected ? 1.4 : 1.0,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryNavy.withValues(alpha: 0.18),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.solarGold),
                      const SizedBox(width: 5),
                    ] else if (item.icon != null) ...[
                      Icon(item.icon, size: 13, color: const Color(0xFF64748B)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: 'Almarai',
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (item.subLabel != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.22)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.subLabel!,
                          style: TextStyle(
                            fontFamily: 'Almarai',
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


  // ══════════════════════════════════════════════════════════════════════════════
  // شريط الإجراءات السفلي الثابت (Sticky Bottom Bar)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!widget.openSessionDirectly) ...[
              // نمط محرر التقرير كإجراء رئيسي أولاً
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  side: const BorderSide(color: AppTheme.primaryNavy),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: const Text(
                  'الفحص الميداني',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                onPressed: _isSubmitting ? null : () => _submit(startInteractiveSession: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.edit_note_rounded, color: AppTheme.solarGold, size: 22),
                  label: Text(
                    _isSubmitting ? 'جاري إنشاء التقرير...' : 'فتح محرر التقرير الشامل 📝',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                  onPressed: _isSubmitting ? null : () => _submit(startInteractiveSession: false),
                ),
              ),
            ] else ...[
              // نمط الفحص الميداني كإجراء رئيسي أولاً
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  side: const BorderSide(color: AppTheme.primaryNavy),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text(
                  'محرر التقرير',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                onPressed: _isSubmitting ? null : () => _submit(startInteractiveSession: false),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_circle_filled_rounded, color: AppTheme.solarGold, size: 22),
                  label: Text(
                    _isSubmitting ? 'جاري إنشاء الجلسة...' : 'بدء الفحص الميداني الآن 🚀',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                  onPressed: _isSubmitting ? null : () => _submit(startInteractiveSession: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickPresetItem {
  final String label;
  final String? subLabel;
  final IconData? icon;

  const _QuickPresetItem({
    required this.label,
    this.subLabel,
    this.icon,
  });
}
