import 'package:flutter/material.dart';
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
import '../../editor/report_editor_screen.dart';
import '../maintenance_session_screen.dart';

import '../../sites/site_form_screen.dart';

enum SessionCreationMode {
  fromSiteDirectory,
  fromExisting,
}

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

  static Future<void> show(
    BuildContext context, {
    ReportTemplate? initialTemplate,
    bool openSessionDirectly = true,
    Site? initialSite,
    Client? initialClient,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateSessionDialog(
        initialTemplate: initialTemplate,
        openSessionDirectly: openSessionDirectly,
        initialSite: initialSite,
        initialClient: initialClient,
      ),
    );
  }

  @override
  ConsumerState<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<CreateSessionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SessionCreationMode _mode = SessionCreationMode.fromSiteDirectory;
  Site? _selectedSite;
  Client? _selectedClient;
  Report? _selectedSourceReport;
  List<int> _activeBatteryGroups = [1, 2, 3, 4];
  List<int> _activeCombinerBoxes = [1, 2, 3, 4];

  // Form Controllers - Project Info
  final _projectNameCtrl = TextEditingController();
  final _contractNumberCtrl = TextEditingController();
  final _ownerEntityCtrl = TextEditingController();
  final _funderCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  final _governorateCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // Form Controllers - Facility Info
  final _facilityNameCtrl = TextEditingController();
  final _facilityNameEnCtrl = TextEditingController();
  final _facilityTypeCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _visitNumberCtrl = TextEditingController(text: '1');
  final _visitDateCtrl = TextEditingController();
  final _visitTimeCtrl = TextEditingController(text: '09:00 ص');
  final _contactPersonCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Form Controllers - System Specs
  final _systemTypeCtrl = TextEditingController();
  final _capacityKwCtrl = TextEditingController();
  final _panelsCountAndWattCtrl = TextEditingController();
  final _batteryUnitsCapacityCtrl = TextEditingController();
  final _batteryUnitsCountCtrl = TextEditingController();
  final _invertersCapacityCtrl = TextEditingController();
  final _invertersCountCtrl = TextEditingController();
  final _chargeControllersCapacityCtrl = TextEditingController();
  final _chargeControllersCountCtrl = TextEditingController();
  final _otherAppliancesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _visitDateCtrl.text =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _populateFromSite(Site site, Client client) {
    setState(() {
      _selectedSite = site;
      _selectedClient = client;

      // Project Info
      _projectNameCtrl.text = site.projectName;
      _contractNumberCtrl.text = site.contractNumber;
      _ownerEntityCtrl.text = client.displayName;
      _funderCtrl.text = site.funderNameAr;
      _contractorCtrl.text = site.implementingContractor;
      _governorateCtrl.text = site.governorate;
      _districtCtrl.text = site.directorate;
      _locationCtrl.text = site.locationAddress;

      // Facility Info
      _facilityNameCtrl.text = site.nameAr;
      _facilityNameEnCtrl.text = site.nameEn;
      _facilityTypeCtrl.text = site.facilityType;
      _categoryCtrl.text = site.category;

      // Calculate next visit number
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

      // System Specs
      _systemTypeCtrl.text = site.systemSpecs.systemType;
      _capacityKwCtrl.text = site.systemSpecs.capacityKw;
      _panelsCountAndWattCtrl.text = site.systemSpecs.panelsCountAndWatt;
      _batteryUnitsCapacityCtrl.text = site.systemSpecs.batteryUnitsCapacity;
      _batteryUnitsCountCtrl.text = site.systemSpecs.batteryUnitsCount;
      _invertersCapacityCtrl.text = site.systemSpecs.invertersCapacity;
      _invertersCountCtrl.text = site.systemSpecs.invertersCount;
      _chargeControllersCapacityCtrl.text = site.systemSpecs.chargeControllersCapacity;
      _chargeControllersCountCtrl.text = site.systemSpecs.chargeControllersCount;
      _otherAppliancesCtrl.text = site.systemSpecs.otherAppliances;
    });
  }

  void _populateFromReport(Report source) {
    setState(() {
      _selectedSourceReport = source;

      // Project Info
      _projectNameCtrl.text = source.projectInfo.projectName;
      _contractNumberCtrl.text = source.contractNumber;
      _ownerEntityCtrl.text = source.projectInfo.ownerEntity;
      _funderCtrl.text = source.projectInfo.funder;
      _contractorCtrl.text = source.projectInfo.implementingContractor;
      _governorateCtrl.text = source.projectInfo.governorate;
      _districtCtrl.text = source.projectInfo.district;
      _locationCtrl.text = source.projectInfo.location;

      // Facility Info
      _facilityNameCtrl.text = source.facilityInfo.facilityName;
      _facilityNameEnCtrl.text = source.facilityInfo.facilityNameEn;
      _facilityTypeCtrl.text = source.facilityInfo.facilityType;
      _categoryCtrl.text = source.facilityInfo.category;
      final prevVisitNum = int.tryParse(source.visitNumber) ?? 1;
      _visitNumberCtrl.text = (prevVisitNum + 1).toString();
      _contactPersonCtrl.text = source.facilityInfo.contactPerson;
      _phoneCtrl.text = source.facilityInfo.phone;

      // System Specs
      _systemTypeCtrl.text = source.systemSpecs.systemType;
      _capacityKwCtrl.text = source.systemSpecs.capacityKw;
      _panelsCountAndWattCtrl.text = source.systemSpecs.panelsCountAndWatt;
      _batteryUnitsCapacityCtrl.text = source.systemSpecs.batteryUnitsCapacity;
      _batteryUnitsCountCtrl.text = source.systemSpecs.batteryUnitsCount;
      _invertersCapacityCtrl.text = source.systemSpecs.invertersCapacity;
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


  Future<void> _submit({required bool startInteractiveSession}) async {
    final resolvedClientId = _selectedClient?.id ?? _selectedSourceReport?.clientId;
    final resolvedSiteId = _selectedSite?.id ?? _selectedSourceReport?.siteId;

    if (resolvedClientId == null || resolvedClientId.isEmpty ||
        resolvedSiteId == null || resolvedSiteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى تحديد العميل والموقع أولاً لضمان ترابط الزيارة والتقرير بالدليل الميداني',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.solarGold,
        ),
      );
      return;
    }

    final projectInfo = ProjectInfo(
      projectName: _projectNameCtrl.text.trim(),
      ownerEntity: _ownerEntityCtrl.text.trim(),
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

    final systemSpecs = SystemSpecs(
      systemType: _systemTypeCtrl.text.trim(),
      capacityKw: _capacityKwCtrl.text.trim(),
      panelsCountAndWatt: _panelsCountAndWattCtrl.text.trim(),
      invertersCapacity: _invertersCapacityCtrl.text.trim(),
      invertersCount: _invertersCountCtrl.text.trim(),
      chargeControllersCapacity: _chargeControllersCapacityCtrl.text.trim(),
      chargeControllersCount: _chargeControllersCountCtrl.text.trim(),
      batteryUnitsCapacity: _batteryUnitsCapacityCtrl.text.trim(),
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
  }

  @override
  Widget build(BuildContext context) {
    final existingReports = ref.watch(reportsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.solar_power_rounded, color: AppTheme.primaryNavy, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بدء جلسة صيانة / تقرير جديد',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'حدد بيانات المشروع والمواصفات الفنية للمنظومة بدقة لإدراجها بالتقرير',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Mode Selection Segmented Control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildModeOption(
                        mode: SessionCreationMode.fromSiteDirectory,
                        label: 'دليل العملاء والمواقع',
                        icon: Icons.domain_verification,
                      ),
                      _buildModeOption(
                        mode: SessionCreationMode.fromExisting,
                        label: 'استنساخ من تقرير سابق',
                        icon: Icons.history_edu_rounded,
                      ),
                    ],
                  ),
                ),
              ),

              // If creating from Site Directory: Show cascading client & site selector
              if (_mode == SessionCreationMode.fromSiteDirectory) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.domain_verification, color: Color(0xFF15803D), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'حدد العميل ثم الموقع لبدء زيارة صيانة متصلة:',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, _) {
                            final clients = ref.watch(clientsProvider);
                            final sites = ref.watch(sitesProvider);

                            if (clients.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'لا يوجد عملاء مسجلين في الدليل بعد. ابدأ بإضافة عميل أولاً.',
                                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const SiteFormScreen(clientId: ''),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.add_business_rounded, size: 16),
                                      label: const Text('إضافة عميل وموقع الآن'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.solarGold,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final availableSites = _selectedClient != null
                                ? sites.where((s) => s.clientId == _selectedClient!.id).toList()
                                : <Site>[];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Step 1: Client Selector
                                DropdownButtonFormField<Client>(
                                  initialValue: _selectedClient,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: '1. الجهة المالكة / العميل *',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.business_rounded, size: 18, color: AppTheme.primaryNavy),
                                  ),
                                  hint: const Text('اختر العميل / الجهة المالكة...', style: TextStyle(fontSize: 12)),
                                  items: clients.map((c) {
                                    return DropdownMenuItem<Client>(
                                      value: c,
                                      child: Text(
                                        c.displayName,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (client) {
                                    if (client != null) {
                                      setState(() {
                                        _selectedClient = client;
                                        _selectedSite = null; // reset site when client changes
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),

                                // Step 2: Site Selector (filtered by Client)
                                if (_selectedClient != null && availableSites.isEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.solarGold),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'هذا العميل ليس لديه مواقع مسجلة بعد.',
                                            style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => SiteFormScreen(clientId: _selectedClient!.id),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.add_location_alt_rounded, size: 15),
                                          label: const Text('إضافة موقع', style: TextStyle(fontSize: 11.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  DropdownButtonFormField<Site>(
                                    initialValue: _selectedSite,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: '2. الموقع الميداني / المنشأة *',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      prefixIcon: const Icon(Icons.location_on_rounded, size: 18, color: AppTheme.primaryNavy),
                                    ),
                                    hint: Text(
                                      _selectedClient == null
                                          ? 'اختر العميل أولاً لعرض مواقعه التابعة'
                                          : 'اختر المنشأة أو الموقع...',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    items: availableSites.map((site) {
                                      final loc = [site.governorate, site.directorate].where((s) => s.isNotEmpty).join(' • ');
                                      return DropdownMenuItem<Site>(
                                        value: site,
                                        child: Text(
                                          loc.isNotEmpty ? '${site.nameAr} ($loc)' : site.nameAr,
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: _selectedClient == null
                                        ? null
                                        : (site) {
                                            if (site != null) {
                                              _populateFromSite(site, _selectedClient!);
                                            }
                                          },
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // If creating next visit from existing site report: Show source report selector
              if (_mode == SessionCreationMode.fromExisting) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history_edu_rounded, color: Color(0xFF1D4ED8), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'اختر المنشأة السابقة لتسجيل الزيارة التالية ونسخ المواصفات:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Report>(
                          initialValue: _selectedSourceReport,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          hint: const Text('اضغط لاختيار منشأة / تقرير سابق...'),
                          items: existingReports.map((rep) {
                            final vNum = rep.visitNumber.isNotEmpty ? rep.visitNumber : '1';
                            final fac = rep.facilityInfo.facilityName.isNotEmpty ? rep.facilityInfo.facilityName : rep.title;
                            return DropdownMenuItem<Report>(
                              value: rep,
                              child: Text(
                                '$fac (الزيارة $vNum) - عقد: ${rep.contractNumber}',
                                style: const TextStyle(fontSize: 12.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (rep) {
                            if (rep != null) _populateFromReport(rep);
                          },
                        ),
                        if (_selectedSourceReport != null && _selectedSourceReport!.requestedNeeds.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.inventory_2_rounded, size: 15, color: Color(0xFFD97706)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'تنبيه: يوجد ${_selectedSourceReport!.requestedNeeds.length} مواد طُلبت في الزيارة (${_selectedSourceReport!.visitNumber}) لهذا الموقع للتركيب اليوم:',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedSourceReport!.requestedNeeds
                                      .map((n) => '• ${n.name} (${n.quantity % 1 == 0 ? n.quantity.toInt() : n.quantity} ${n.unit})')
                                      .join('  |  '),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // Section Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryNavy,
                indicatorWeight: 3,
                labelColor: AppTheme.primaryNavy,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.business_rounded, size: 18), text: 'بيانات المشروع'),
                  Tab(icon: Icon(Icons.local_hospital_rounded, size: 18), text: 'بيانات المنشأة'),
                  Tab(icon: Icon(Icons.electric_bolt_rounded, size: 18), text: 'مواصفات المنظومة'),
                ],
              ),

              // Tab Views Form
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Project Info
                    _buildProjectInfoTab(scrollController),

                    // Tab 2: Facility Info
                    _buildFacilityInfoTab(scrollController),

                    // Tab 3: System Specs
                    _buildSystemSpecsTab(scrollController),
                  ],
                ),
              ),

              // Bottom Actions
              _buildBottomActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeOption({
    required SessionCreationMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = mode;
          });
        },
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
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppTheme.primaryNavy : AppTheme.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryNavy : AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectInfoTab(ScrollController controller) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _projectNameCtrl,
            label: 'اسم المشروع الرسمي',
            hint: 'مثال: توريد وتركيب وصيانة 21 منظومة طاقة شمسية منفصلة عن الشبكة',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _contractNumberCtrl,
                  label: 'رقم العقد',
                  hint: 'مثال: 1010720',
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _funderCtrl,
                  label: 'الجهة الممولة (المنفّذ)',
                  hint: 'مثال: مكتب الأمم المتحدة لخدمات المشاريع UNOPS',
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الجهة المالكة والوزارة (تظهر في ترويسة التقرير):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.local_hospital_outlined, size: 14, color: AppTheme.primaryNavy),
                    label: const Text('وزارة الصحة (مراكز صحية)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _ownerEntityCtrl.text = 'وزارة الصحة العامة والسكان'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.school_outlined, size: 14, color: AppTheme.primaryNavy),
                    label: const Text('وزارة التربية والتعليم (مدارس)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _ownerEntityCtrl.text = 'وزارة التربية والتعليم'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _ownerEntityCtrl,
                label: 'الجهة المالكة / الوزارة',
                hint: 'مثال: وزارة الصحة العامة والسكان أو وزارة التربية والتعليم',
                icon: Icons.account_balance_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _contractorCtrl,
            label: 'المقاول المنفذ',
            hint: 'مثال: شركة الأحلسي للتجارة والمقاولات المحدودة',
            icon: Icons.engineering_outlined,
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final currentGov = _governorateCtrl.text.trim().isNotEmpty ? _governorateCtrl.text.trim() : 'حجة';
              final availableGovs = YemenLocations.governorates;
              final govList = availableGovs.contains(currentGov) ? availableGovs : [currentGov, ...availableGovs];

              final districts = YemenLocations.getDistrictsFor(currentGov);
              final currentDist = _districtCtrl.text.trim().isNotEmpty
                  ? _districtCtrl.text.trim()
                  : (districts.isNotEmpty ? districts.first : '');
              final distList = (districts.contains(currentDist) || currentDist.isEmpty)
                  ? districts
                  : [currentDist, ...districts];

              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('cs_gov_$currentGov'),
                      initialValue: govList.contains(currentGov) ? currentGov : null,
                      decoration: InputDecoration(
                        labelText: 'المحافظة',
                        prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.borderSubtle),
                        ),
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
                          _districtCtrl.text = newDistricts.isNotEmpty ? newDistricts.first : '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('cs_dist_${currentGov}_$currentDist'),
                      initialValue: distList.contains(currentDist) ? currentDist : (distList.isNotEmpty ? distList.first : null),
                      decoration: InputDecoration(
                        labelText: 'المديرية',
                        prefixIcon: const Icon(Icons.map_outlined, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.borderSubtle),
                        ),
                      ),
                      items: distList.map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (newDist) {
                        if (newDist == null) return;
                        setState(() {
                          _districtCtrl.text = newDist;
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _locationCtrl,
            label: 'الموقع الدقيق / القرية / العزلة',
            hint: 'مثال: عزلة بني حسن - مركز غسيل الكلى',
            icon: Icons.pin_drop_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityInfoTab(ScrollController controller) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _facilityNameCtrl,
            label: 'اسم المنشأة بالعربية',
            hint: 'مثال: مركز غسيل الكلى عبس',
            icon: Icons.local_hospital_outlined,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _facilityNameEnCtrl,
            label: 'اسم المنشأة بالإنجليزية (Facility Name En)',
            hint: 'مثال: Abs Dialysis Center',
            icon: Icons.translate_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _facilityTypeCtrl,
                  label: 'نوع المنشأة',
                  hint: 'مثال: مركز صحي / مستشفى ريفي',
                  icon: Icons.category_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _categoryCtrl,
                  label: 'الفئة (Category)',
                  hint: 'مثال: CAT 8 / CAT 7',
                  icon: Icons.grade_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildTextField(
                  controller: _visitDateCtrl,
                  label: 'تاريخ الزيارة (YYYY/MM/DD)',
                  hint: '2025/08/15',
                  icon: Icons.calendar_today_outlined,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() {
                        _visitDateCtrl.text =
                            '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: _visitNumberCtrl,
                  label: 'رقم الزيارة',
                  hint: '1',
                  icon: Icons.tag_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildTextField(
                  controller: _visitTimeCtrl,
                  label: 'وقت الزيارة',
                  hint: '09:00 ص - 03:00 م',
                  icon: Icons.access_time_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _contactPersonCtrl,
                  label: 'مسؤول المنشأة / المستلم',
                  hint: 'مثال: د. عبد الله أحمد',
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _phoneCtrl,
                  label: 'رقم الهاتف للتواصل',
                  hint: 'مثال: 777 123 456',
                  icon: Icons.phone_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSpecsTab(ScrollController controller) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _capacityKwCtrl,
                  label: 'القدرة الإجمالية (kW)',
                  hint: 'مثال: 57.6 kW',
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _panelsCountAndWattCtrl,
                  label: 'عدد الألواح × القدرة',
                  hint: 'مثال: 96 x 600Wp',
                  icon: Icons.solar_power_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _batteryUnitsCapacityCtrl,
                  label: 'سعة وحدة تخزين الطاقة',
                  hint: 'مثال: 2500Ah',
                  icon: Icons.battery_charging_full_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _batteryUnitsCountCtrl,
                  label: 'عدد وحدات تخزين الطاقة',
                  hint: 'مثال: 96 x 2V',
                  icon: Icons.format_list_numbered_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _invertersCapacityCtrl,
                  label: 'قدرة العاكس',
                  hint: 'مثال: 10KVA',
                  icon: Icons.swap_horiz_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _invertersCountCtrl,
                  label: 'عدد العواكس',
                  hint: 'مثال: 6',
                  icon: Icons.tag_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _chargeControllersCapacityCtrl,
                  label: 'قدرة منظم الشحن',
                  hint: 'مثال: 100 A (150-250) Vdc',
                  icon: Icons.speed_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _chargeControllersCountCtrl,
                  label: 'عدد منظمات الشحن',
                  hint: 'مثال: 13',
                  icon: Icons.tag_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _otherAppliancesCtrl,
            label: 'أحمال وأجهزة إضافية (أخرى)',
            hint: 'مثال: مكيف هواء 1 طن عدد 2',
            icon: Icons.ac_unit_rounded,
          ),
          const SizedBox(height: 20),

          // Custom Site Layout Card (Active Battery Groups & Active Combiner Boxes)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune_rounded, color: AppTheme.primaryNavy, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تخصيص هيكل التقرير للموقع',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            'تحديد مجموعات البطاريات وصناديق التجميع حسب حجم المنظومة الفعلي',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // 1. Active Battery Groups
                const Text(
                  'مجموعات البطاريات المطلوب تضمينها بالتقرير:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 2, 3, 4].map((g) {
                    final isSel = _activeBatteryGroups.contains(g);
                    return FilterChip(
                      label: Text('المجموعة $g (خلايا ${(g - 1) * 24 + 1}-${g * 24})'),
                      selected: isSel,
                      selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.18),
                      checkmarkColor: AppTheme.primaryNavy,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? AppTheme.primaryNavy : AppTheme.textSecondary,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_activeBatteryGroups.contains(g)) _activeBatteryGroups.add(g);
                          } else {
                            if (_activeBatteryGroups.length > 1) {
                              _activeBatteryGroups.remove(g);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يجب اختيار مجموعة بطاريات واحدة على الأقل')),
                              );
                            }
                          }
                          _activeBatteryGroups.sort();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _activeBatteryGroups.length <= 2 ? Icons.check_circle_outline : Icons.info_outline,
                      size: 14,
                      color: _activeBatteryGroups.length <= 2 ? AppTheme.statusGood : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _activeBatteryGroups.length <= 2
                            ? 'سيتم توليد صفحة واحدة موسعة للبطاريات (Page 6) وتعديل ترقيم التقرير تلقائياً.'
                            : 'سيتم توليد صفحتين متتاليتين للبطاريات (الصفحات 6 و 7) لتغطية الـ 4 مجموعات.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: _activeBatteryGroups.length <= 2 ? Colors.green.shade800 : AppTheme.textMuted,
                          fontWeight: _activeBatteryGroups.length <= 2 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Active Combiner Boxes
                const Text(
                  'صناديق التجميع والمنظمات النشطة بالموقع:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('صندوقين (1-2)'),
                      selected: _activeCombinerBoxes.length == 2 && _activeCombinerBoxes.contains(1) && _activeCombinerBoxes.contains(2),
                      selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.18),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _activeCombinerBoxes = [1, 2];
                            if (_chargeControllersCountCtrl.text.isEmpty || _chargeControllersCountCtrl.text == '13') {
                              _chargeControllersCountCtrl.text = '2';
                            }
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('3 صناديق (1-3)'),
                      selected: _activeCombinerBoxes.length == 3 && _activeCombinerBoxes.contains(1) && _activeCombinerBoxes.contains(2) && _activeCombinerBoxes.contains(3),
                      selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.18),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _activeCombinerBoxes = [1, 2, 3];
                            if (_chargeControllersCountCtrl.text.isEmpty || _chargeControllersCountCtrl.text == '13') {
                              _chargeControllersCountCtrl.text = '3';
                            }
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('4 صناديق (1-4)'),
                      selected: _activeCombinerBoxes.length == 4 && _activeCombinerBoxes.contains(4),
                      selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.18),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _activeCombinerBoxes = [1, 2, 3, 4];
                            if (_chargeControllersCountCtrl.text.isEmpty || _chargeControllersCountCtrl.text == '13') {
                              _chargeControllersCountCtrl.text = '4';
                            }
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('كافة الصناديق (1-16)'),
                      selected: _activeCombinerBoxes.length == 16,
                      selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.18),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _activeCombinerBoxes = List.generate(16, (i) => i + 1);
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'سيتم إظهار الصناديق المحددة فقط في جدول قياسات الألواح (Page 9) وبيانات التشغيل بأعمدة مريحة ومقروءة.',
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          readOnly: onTap != null,
          onTap: onTap,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            prefixIcon: Icon(icon, size: 18, color: AppTheme.primaryNavy.withValues(alpha: 0.7)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Open in full editor button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: AppTheme.primaryNavy),
              ),
              icon: const Icon(Icons.edit_document, size: 18, color: AppTheme.primaryNavy),
              label: const Text(
                'محرر التقرير',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
              onPressed: () => _submit(startInteractiveSession: false),
            ),
            const SizedBox(width: 10),

            // Start interactive field session (Primary)
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.play_circle_filled_rounded, size: 20, color: AppTheme.solarGold),
                label: const Text(
                  'بدء جلسة الفحص الميداني',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _submit(startInteractiveSession: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
