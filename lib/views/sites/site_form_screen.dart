import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/yemen_locations.dart';
import '../../models/site.dart';
import '../../models/client.dart';
import '../../models/report.dart';
import '../../state/sites_provider.dart';
import '../../state/clients_provider.dart';

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
    _governorateCtrl = TextEditingController(text: s?.governorate ?? 'حجة');
    _directorateCtrl = TextEditingController(text: s?.directorate ?? '');
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
    _contractorCtrl = TextEditingController(
        text: s?.implementingContractor ?? 'مؤسسة حمدان لتقنية الطاقة المتجددة');
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

    return Scaffold(
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
                  TextFormField(
                    controller: _nameArCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم المنشأة' : null,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنشأة / الموقع (عربي) *',
                      hintText: 'مثال: مركز غسيل الكلى عبس',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameEnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Facility Name (English)',
                      hintText: 'e.g. Abs Dialysis Center',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _facilityTypeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'نوع المنشأة',
                            hintText: 'مركز صحي، مستشفى...',
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
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final currentGov = _governorateCtrl.text.trim().isNotEmpty ? _governorateCtrl.text.trim() : 'حجة';
                      final availableGovs = YemenLocations.governorates;
                      final govList = availableGovs.contains(currentGov) ? availableGovs : [currentGov, ...availableGovs];

                      final districts = YemenLocations.getDistrictsFor(currentGov);
                      final currentDist = _directorateCtrl.text.trim().isNotEmpty
                          ? _directorateCtrl.text.trim()
                          : (districts.isNotEmpty ? districts.first : '');
                      final distList = (districts.contains(currentDist) || currentDist.isEmpty)
                          ? districts
                          : [currentDist, ...districts];

                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('site_gov_$currentGov'),
                              initialValue: govList.contains(currentGov) ? currentGov : null,
                              decoration: const InputDecoration(
                                labelText: 'المحافظة',
                                prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                              ),
                              items: govList.map((g) => DropdownMenuItem(
                                value: g,
                                child: Text(g, style: const TextStyle(fontSize: 13)),
                              )).toList(),
                              onChanged: (newGov) {
                                if (newGov == null) return;
                                setState(() {
                                  _governorateCtrl.text = newGov;
                                  final newDistricts = YemenLocations.getDistrictsFor(newGov);
                                  _directorateCtrl.text = newDistricts.isNotEmpty ? newDistricts.first : '';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('site_dist_${currentGov}_$currentDist'),
                              initialValue: distList.contains(currentDist) ? currentDist : (distList.isNotEmpty ? distList.first : null),
                              decoration: const InputDecoration(
                                labelText: 'المديرية',
                                prefixIcon: Icon(Icons.map_outlined, size: 20),
                              ),
                              items: distList.map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d, style: const TextStyle(fontSize: 13)),
                              )).toList(),
                              onChanged: (newDist) {
                                if (newDist == null) return;
                                setState(() {
                                  _directorateCtrl.text = newDist;
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _locationAddressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'العنوان التفصيلي للموقع',
                      hintText: 'مثال: بجوار المستشفى الريفي - الشارع العام',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contactPersonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ضابط الاتصال / مدير الموقع',
                            hintText: 'مثال: د. يحيى الشجاع',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم هاتف مسؤول الموقع',
                            hintText: '+967 771 ...',
                          ),
                        ),
                      ),
                    ],
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
                            hintText: 'مؤسسة حمدان لتقنية الطاقة',
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
