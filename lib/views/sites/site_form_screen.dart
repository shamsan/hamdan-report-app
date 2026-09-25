import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/yemen_locations.dart';
import '../../models/site.dart';
import '../../models/client.dart';
import '../../models/report.dart';
import '../../state/sites_provider.dart';
import '../../state/clients_provider.dart';
import '../../state/branding_provider.dart';
import '../../core/widgets/yemeni_phone_field.dart';

class SiteFormScreen extends ConsumerStatefulWidget {
  final String clientId;
  final Site? siteToEdit;

  const SiteFormScreen({
    super.key,
    required this.clientId,
    this.siteToEdit,
  });

  @override
  ConsumerState<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends ConsumerState<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Facility & Location Controllers
  late final TextEditingController _nameArCtrl;
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _facilityTypeCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _governorateCtrl;
  late final TextEditingController _directorateCtrl;
  late final TextEditingController _locationAddressCtrl;
  late final TextEditingController _contactPersonCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _installationDateCtrl;

  // 2. Funder & Contract Controllers
  late final TextEditingController _funderNameArCtrl;
  late final TextEditingController _funderNameEnCtrl;
  late final TextEditingController _projectNameCtrl;
  late final TextEditingController _contractNumberCtrl;
  late final TextEditingController _contractorCtrl;
  bool _showFunderLogo = true;

  // 3. Solar System Specs Controllers
  late final TextEditingController _systemTypeCtrl;
  late final TextEditingController _capacityKwCtrl;
  late final TextEditingController _panelsCtrl;
  late final TextEditingController _invertersCtrl;
  late final TextEditingController _batteriesCtrl;
  late final TextEditingController _chargeControllersCtrl;
  late final TextEditingController _otherAppliancesCtrl;

  bool get _isEditing => widget.siteToEdit != null;

  @override
  void initState() {
    super.initState();
    final s = widget.siteToEdit;

    _nameArCtrl = TextEditingController(text: s?.nameAr ?? '');
    _nameEnCtrl = TextEditingController(text: s?.nameEn ?? '');
    _facilityTypeCtrl = TextEditingController(text: s?.facilityType ?? 'مركز صحي');
    _categoryCtrl = TextEditingController(text: s?.category ?? 'CAT 8');
    _governorateCtrl = TextEditingController(
        text: (s?.governorate != null && s!.governorate.trim().isNotEmpty) ? s.governorate : 'حجة');
    _directorateCtrl = TextEditingController(
        text: (s?.directorate != null && s!.directorate.trim().isNotEmpty) ? s.directorate : 'عبس');
    _locationAddressCtrl = TextEditingController(text: s?.locationAddress ?? '');
    _contactPersonCtrl = TextEditingController(text: s?.contactPerson ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _installationDateCtrl = TextEditingController(text: s?.installationDate ?? '');

    _funderNameArCtrl = TextEditingController(
        text: s?.funderNameAr ?? 'مكتب الأمم المتحدة لخدمات المشاريع - UNOPS');
    _funderNameEnCtrl = TextEditingController(text: s?.funderNameEn ?? 'UNOPS');
    _projectNameCtrl = TextEditingController(
        text: s?.projectName ?? 'مشروع تشغيل وصيانة منظومات الطاقة الشمسية');
    _contractNumberCtrl = TextEditingController(text: s?.contractNumber ?? '');
    final branding = ref.read(brandingProvider);
    _contractorCtrl = TextEditingController(
        text: s?.implementingContractor ?? (branding.contractorNameAr.isNotEmpty ? branding.contractorNameAr : ''));
    _showFunderLogo = s?.showFunderLogo ?? true;

    final specs = s?.systemSpecs ?? const SystemSpecs();
    _systemTypeCtrl = TextEditingController(text: specs.systemType.isNotEmpty ? specs.systemType : 'منظومة هجينة (Hybrid Solar PV System)');
    _capacityKwCtrl = TextEditingController(text: specs.capacityKw);
    _panelsCtrl = TextEditingController(text: specs.panelsCountAndWatt);
    _invertersCtrl = TextEditingController(text: specs.invertersCapacity);
    _batteriesCtrl = TextEditingController(text: specs.batteryUnitsCapacity);
    _chargeControllersCtrl = TextEditingController(text: specs.chargeControllersCapacity);
    _otherAppliancesCtrl = TextEditingController(text: specs.otherAppliances);
  }

  @override
  void dispose() {
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _facilityTypeCtrl.dispose();
    _categoryCtrl.dispose();
    _governorateCtrl.dispose();
    _directorateCtrl.dispose();
    _locationAddressCtrl.dispose();
    _contactPersonCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _installationDateCtrl.dispose();

    _funderNameArCtrl.dispose();
    _funderNameEnCtrl.dispose();
    _projectNameCtrl.dispose();
    _contractNumberCtrl.dispose();
    _contractorCtrl.dispose();

    _systemTypeCtrl.dispose();
    _capacityKwCtrl.dispose();
    _panelsCtrl.dispose();
    _invertersCtrl.dispose();
    _batteriesCtrl.dispose();
    _chargeControllersCtrl.dispose();
    _otherAppliancesCtrl.dispose();
    super.dispose();
  }

  Future<bool> _handlePopScope() async {
    final hasChanges = _nameArCtrl.text.isNotEmpty ||
        _contactPersonCtrl.text.isNotEmpty ||
        _phoneCtrl.text.isNotEmpty;
    if (!hasChanges) {
      return true;
    }

    HapticFeedback.lightImpact();
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.solarGold, size: 24),
            SizedBox(width: 8),
            Text('تجاهل التغييرات؟', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'هل تريد الخروج وتجاهل البيانات والتعديلات المدخلة للموقع؟',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('البقاء للإكمال', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تجاهل والخروج'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final client = clients.firstWhere(
      (c) => c.id == widget.clientId,
      orElse: () => Client(
        id: widget.clientId,
        nameAr: 'العميل المحدد',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _handlePopScope();
        if (leave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'تعديل بيانات الموقع' : 'إضافة موقع ميداني جديد',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client Banner Info
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: AppTheme.brandCyan, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الموقع تابع للعميل / الجهة المستفيدة:', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          Text(client.nameAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 1. Facility & Location Section
              _buildSectionCard(
                icon: Icons.apartment,
                title: '1. بيانات المنشأة والموقع الجغرافي',
                color: AppTheme.primaryNavy,
                children: [
                  // 1. Facility Name (Arabic)
                  TextFormField(
                    controller: _nameArCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم المنشأة' : null,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنشأة / الموقع (عربي) *',
                      hintText: 'مثال: مركز غسيل الكلى عبس',
                      prefixIcon: Icon(Icons.apartment_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Facility Name (English)
                  TextFormField(
                    controller: _nameEnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Facility Name (English)',
                      hintText: 'e.g. Abs Dialysis Center',
                      prefixIcon: Icon(Icons.translate_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Facility Type & Category in a clean Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _facilityTypeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'نوع المنشأة',
                            hintText: 'مركز صحي، مستشفى...',
                            prefixIcon: Icon(Icons.local_hospital_outlined, size: 19),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _categoryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الفئة (Category)',
                            hintText: 'CAT 8, CAT 6...',
                            prefixIcon: Icon(Icons.category_outlined, size: 19),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4. Custom Location Selector Row (المحافظة والمديرية) - No Overflow, Searchable & Editable
                  Row(
                    children: [
                      _buildLocationTile(
                        label: 'المحافظة',
                        value: _governorateCtrl.text.trim().isNotEmpty ? _governorateCtrl.text.trim() : 'حجة',
                        icon: Icons.location_city_rounded,
                        iconColor: AppTheme.primaryNavy,
                        onTap: () => _showLocationPicker(isGovernorate: true),
                      ),
                      const SizedBox(width: 10),
                      _buildLocationTile(
                        label: 'المديرية',
                        value: _directorateCtrl.text.trim().isNotEmpty ? _directorateCtrl.text.trim() : 'عبس',
                        icon: Icons.map_rounded,
                        iconColor: AppTheme.brandCyan,
                        onTap: () => _showLocationPicker(isGovernorate: false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. Detailed Address
                  TextFormField(
                    controller: _locationAddressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'العنوان التفصيلي للموقع',
                      hintText: 'مثال: بجوار المستشفى الريفي - الشارع العام',
                      prefixIcon: Icon(Icons.pin_drop_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 6. Contact Person / Site Manager (Full width - No Truncation!)
                  TextFormField(
                    controller: _contactPersonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ضابط الاتصال / مدير الموقع',
                      hintText: 'مثال: د. يحيى الشجاع',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 7. Full-width Yemeni Phone Field (9 digits, carrier badge, contact picker)
                  YemeniPhoneField(
                    controller: _phoneCtrl,
                    label: 'رقم هاتف مسؤول الموقع',
                    hint: '771 123 456',
                    onContactPicked: (contact) {
                      if (contact.name != null && _contactPersonCtrl.text.trim().isEmpty) {
                        setState(() {
                          _contactPersonCtrl.text = contact.name!;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Dedicated Site Funder & Contract Section
              _buildSectionCard(
                icon: Icons.monetization_on_outlined,
                title: '2. الممول الخاص بهذا الموقع والعقد (Dedicated Funder)',
                color: AppTheme.brandCyan,
                children: [
                  const Text(
                    'اختر أو أدخل الممول الخاص بهذا الموقع (يتم اعتماده تلقائياً في كافة تقارير هذا الموقع):',
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  // Quick Funder Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFunderChip('UNOPS (الأمم المتحدة)', 'مكتب الأمم المتحدة لخدمات المشاريع - UNOPS', 'UNOPS'),
                      _buildFunderChip('البنك الدولي (World Bank)', 'البنك الدولي - World Bank', 'World Bank Group'),
                      _buildFunderChip('مركز الملك سلمان', 'مركز الملك سلمان للإغاثة والأعمال الإنسانية', 'KSRelief'),
                      _buildFunderChip('منظمة اليونيسف (UNICEF)', 'منظمة الأمم المتحدة للطفولة - UNICEF', 'UNICEF'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _funderNameArCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الجهة الممولة (عربي) *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _funderNameEnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Funder Name (English)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contractNumberCtrl,
                          decoration: const InputDecoration(
                            labelText: 'رقم العقد الخاص بالموقع',
                            hintText: 'مثال: 1010720',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _contractorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المقاول المنفذ',
                            hintText: 'اسم المقاول المنفذ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _projectNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المشروع المعتمد لهذا الموقع',
                      hintText: 'مشروع تشغيل وصيانة مراكز...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeThumbColor: AppTheme.brandCyan,
                    title: const Text('إظهار شعار الممول يمين ترويسة تقارير هذا الموقع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text('عند التفعيل تظهر الترويسة بثلاثة شعارات (الممول يميناً • العميل وسطاً • المقاول يساراً)', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                    value: _showFunderLogo,
                    onChanged: (val) => setState(() => _showFunderLogo = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Solar System Specs Section
              _buildSectionCard(
                icon: Icons.solar_power,
                title: '3. المواصفات الفنية لمنظومة الطاقة الشمسية المنفذة',
                color: AppTheme.solarGold,
                children: [
                  TextFormField(
                    controller: _systemTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نوع المنظومة الشمسية',
                      hintText: 'هجينة Hybrid / متصلة On-Grid / ضخ مياه...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _capacityKwCtrl,
                          decoration: const InputDecoration(
                            labelText: 'القدرة الكلية (kWp)',
                            hintText: 'مثال: 45.0 kWp',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _installationDateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تاريخ التركيب / الاستلام',
                            hintText: 'YYYY/MM/DD',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _panelsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الألواح الشمسية (العدد والقدرة)',
                      hintText: 'مثال: 80 لوح مونوكريستالين قدرة 550 وات',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _invertersCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الإنفرترات والمحولات',
                      hintText: 'مثال: 3 إنفرترات سعة 15kW ماركة Fronius',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _batteriesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'بنك البطاريات (النوع والسعة)',
                      hintText: 'مثال: 32 بطارية جل 2V سعة 1500Ah',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _chargeControllersCtrl,
                    decoration: const InputDecoration(
                      labelText: 'منظمات الشحن (Charge Controllers)',
                      hintText: 'مثال: منظمات شحن MPPT 250/100 عدد 4',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _otherAppliancesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'أجهزة الحماية والتأريض والمكونات الأخرى',
                      hintText: 'مثال: قواطع DC وموانع صواعق وتأريض متكامل',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.solarGold, size: 20),
                  label: Text(
                    _isEditing ? 'حفظ تعديلات الموقع' : 'اعتماد وإضافة الموقع للمنظومة',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: _saveSite,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppTheme.borderSubtle),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFunderChip(String chipLabel, String arName, String enName) {
    final isSelected = _funderNameArCtrl.text == arName;
    return ActionChip(
      label: Text(chipLabel, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppTheme.textDark)),
      backgroundColor: isSelected ? AppTheme.brandCyan : AppTheme.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: () {
        setState(() {
          _funderNameArCtrl.text = arName;
          _funderNameEnCtrl.text = enName;
        });
      },
    );
  }

  Widget _buildLocationTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationPicker({required bool isGovernorate}) {
    if (isGovernorate) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _LocationPickerSheet(
          title: 'اختر المحافظة',
          currentValue: _governorateCtrl.text.trim(),
          items: YemenLocations.governorates,
          onSelected: (selected) {
            setState(() {
              _governorateCtrl.text = selected;
              final validDistricts = YemenLocations.getDistrictsFor(selected);
              if (validDistricts.isNotEmpty && !validDistricts.contains(_directorateCtrl.text.trim())) {
                _directorateCtrl.text = validDistricts.first;
              }
            });
          },
        ),
      );
    } else {
      final currentGov = _governorateCtrl.text.trim();
      final districts = YemenLocations.getDistrictsFor(currentGov);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _LocationPickerSheet(
          title: currentGov.isNotEmpty ? 'اختر المديرية ($currentGov)' : 'اختر المديرية',
          currentValue: _directorateCtrl.text.trim(),
          items: districts.isNotEmpty ? districts : YemenLocations.getDistrictsFor('حجة'),
          onCustomEntry: () {
            Navigator.pop(context);
            _showCustomDirectorateDialog();
          },
          onSelected: (selected) {
            setState(() {
              _directorateCtrl.text = selected;
            });
          },
        ),
      );
    }
  }

  void _showCustomDirectorateDialog() {
    final customCtrl = TextEditingController(text: _directorateCtrl.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_location_alt_rounded, color: AppTheme.brandCyan, size: 22),
            SizedBox(width: 8),
            Text('إدخال اسم المديرية يدوياً', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: customCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم المديرية / العزلة',
            hintText: 'مثال: عبس، حرض، بني حسن...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (customCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _directorateCtrl.text = customCtrl.text.trim();
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandCyan),
            child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) return;

    final systemSpecs = SystemSpecs(
      systemType: _systemTypeCtrl.text.trim(),
      capacityKw: _capacityKwCtrl.text.trim(),
      panelsCountAndWatt: _panelsCtrl.text.trim(),
      invertersCapacity: _invertersCtrl.text.trim(),
      batteryUnitsCapacity: _batteriesCtrl.text.trim(),
      chargeControllersCapacity: _chargeControllersCtrl.text.trim(),
      otherAppliances: _otherAppliancesCtrl.text.trim(),
    );

    if (_isEditing) {
      final updated = widget.siteToEdit!.copyWith(
        nameAr: _nameArCtrl.text.trim(),
        nameEn: _nameEnCtrl.text.trim(),
        facilityType: _facilityTypeCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        governorate: _governorateCtrl.text.trim(),
        directorate: _directorateCtrl.text.trim(),
        locationAddress: _locationAddressCtrl.text.trim(),
        contactPerson: _contactPersonCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        installationDate: _installationDateCtrl.text.trim(),
        funderNameAr: _funderNameArCtrl.text.trim(),
        funderNameEn: _funderNameEnCtrl.text.trim(),
        projectName: _projectNameCtrl.text.trim(),
        contractNumber: _contractNumberCtrl.text.trim(),
        implementingContractor: _contractorCtrl.text.trim(),
        showFunderLogo: _showFunderLogo,
        systemSpecs: systemSpecs,
      );
      await ref.read(sitesProvider.notifier).updateSite(updated);
    } else {
      await ref.read(sitesProvider.notifier).addSite(
        clientId: widget.clientId,
        nameAr: _nameArCtrl.text.trim(),
        nameEn: _nameEnCtrl.text.trim(),
        facilityType: _facilityTypeCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        governorate: _governorateCtrl.text.trim(),
        directorate: _directorateCtrl.text.trim(),
        locationAddress: _locationAddressCtrl.text.trim(),
        contactPerson: _contactPersonCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        installationDate: _installationDateCtrl.text.trim(),
        funderNameAr: _funderNameArCtrl.text.trim(),
        funderNameEn: _funderNameEnCtrl.text.trim(),
        projectName: _projectNameCtrl.text.trim(),
        contractNumber: _contractNumberCtrl.text.trim(),
        implementingContractor: _contractorCtrl.text.trim(),
        showFunderLogo: _showFunderLogo,
        systemSpecs: systemSpecs,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}

class _LocationPickerSheet extends StatefulWidget {
  final String title;
  final String currentValue;
  final List<String> items;
  final ValueChanged<String> onSelected;
  final VoidCallback? onCustomEntry;

  const _LocationPickerSheet({
    required this.title,
    required this.currentValue,
    required this.items,
    required this.onSelected,
    this.onCustomEntry,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late final TextEditingController _searchCtrl;
  late List<String> _filteredItems;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredItems = widget.items;
      } else {
        final q = query.trim().toLowerCase();
        _filteredItems = widget.items.where((it) => it.toLowerCase().contains(q)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'بحث سريع...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppTheme.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (widget.onCustomEntry != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: widget.onCustomEntry,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.brandCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.brandCyan),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'إدخال مديرية أو عزلة يدوياً غير موجودة بالقائمة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.brandCyan,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_left_rounded, size: 18, color: AppTheme.brandCyan),
                    ],
                  ),
                ),
              ),
            ),
          Flexible(
            child: _filteredItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 40, color: AppTheme.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد نتائج تطابق "${_searchCtrl.text}"',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                        if (widget.onCustomEntry != null && _searchCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              final query = _searchCtrl.text.trim();
                              Navigator.pop(context);
                              widget.onSelected(query);
                            },
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text('استخدام "${_searchCtrl.text.trim()}"'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.brandCyan,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = item == widget.currentValue;
                      return ListTile(
                        dense: true,
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primaryNavy : AppTheme.textDark,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryNavy, size: 20)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSelected(item);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

