import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/breadcrumb_widget.dart';
import '../../models/client.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../state/reports_provider.dart';
import 'client_details_screen.dart';
import '../../core/widgets/yemeni_phone_field.dart';

class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final sites = ref.watch(sitesProvider);
    final reports = ref.watch(reportsProvider);

    final filteredClients = _searchQuery.isEmpty
        ? clients
        : ref.read(clientsProvider.notifier).search(_searchQuery);

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.business_center, color: AppTheme.solarGold, size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'دليل العملاء والمواقع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Stats Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: AppTheme.primaryNavy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Quick Summary Row
                Row(
                  children: [
                    _buildStatItem('إجمالي العملاء', '${clients.length}', Icons.apartment, AppTheme.brandCyan),
                    _buildStatDivider(),
                    _buildStatItem('المواقع الميدانية', '${sites.length}', Icons.pin_drop, AppTheme.solarGold),
                    _buildStatDivider(),
                    _buildStatItem('الزيارات والتقارير', '${reports.length}', Icons.assignment, Colors.greenAccent),
                  ],
                ),
                const SizedBox(height: 14),
                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'البحث باسم العميل أو المنشأة أو المحافظة...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: filteredClients.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = filteredClients[index];
                      final stats = ref.watch(clientStatsProvider(client.id));

                      return _buildClientCard(context, client, stats);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.solarGold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('إضافة عميل جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddClientDialog(context),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return const SizedBox(width: 8);
  }

  Widget _buildClientCard(BuildContext context, Client client, ClientStats stats) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientDetailsScreen(client: client),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Client Top Row
              Row(
                children: [
                  // Client Logo or Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: client.logoBase64 != null && client.logoBase64!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(client.logoBase64!),
                              fit: BoxFit.contain,
                            ),
                          )
                        : const Icon(Icons.apartment, color: AppTheme.primaryNavy, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.nameAr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        if (client.nameEn.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            client.nameEn,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.brandCyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            client.clientType,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brandCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                    onSelected: (action) {
                      if (action == 'edit') {
                        _showEditClientDialog(context, client);
                      } else if (action == 'delete') {
                        _confirmDeleteClient(context, client);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16, color: AppTheme.textDark),
                            SizedBox(width: 8),
                            Text('تعديل بيانات العميل', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف العميل', style: TextStyle(fontSize: 12, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (client.contactPerson.isNotEmpty || client.phone.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 15, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          client.contactPerson,
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (client.phone.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          client.phone,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1, color: AppTheme.borderSubtle),
              const SizedBox(height: 8),

              // Bottom Stats Row & CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildChipBadge(Icons.location_on_outlined, '${stats.sitesCount} مواقع', AppTheme.primaryNavy),
                        _buildChipBadge(Icons.assignment_outlined, '${stats.reportsCount} زيارة', AppTheme.solarGold),
                        if (stats.draftReports > 0)
                          _buildChipBadge(Icons.pending_actions_rounded, '${stats.draftReports} مسودة', AppTheme.statusFollowup),
                        if (stats.lastVisitDate != null)
                          _buildChipBadge(Icons.event_available_rounded, stats.lastVisitDate!, AppTheme.statusGood),
                      ],
                    ),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'استعراض المواقع',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.brandCyan,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.brandCyan),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: EmptyStateGuide(
          icon: Icons.apartment_rounded,
          title: 'لا يوجد عملاء مضافين حالياً',
          description: 'أضف عميلاً جديداً (وزارة، منظمة، مؤسسة) ثم ابدأ بإضافة المواقع والمنشآت الميدانية التابعة له.',
          actionLabel: 'إضافة العميل الأول',
          onAction: () => _showAddClientDialog(context),
        ),
      ),
    );
  }

  Widget _buildFormSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryNavy),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLogoSelectorCard({
    required BuildContext context,
    required String? logoBase64,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasLogo = logoBase64 != null && logoBase64.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_rounded, size: 16, color: AppTheme.primaryNavy),
              const SizedBox(width: 6),
              const Text(
                'شعار العميل / المنشأة الرسمية',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
              const Spacer(),
              if (hasLogo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.statusGood.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.statusGood),
                      SizedBox(width: 4),
                      Text('تم اعتماد الشعار', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusGood)),
                    ],
                  ),
                )
              else
                const Text(
                  'اختياري (لترويسة التقارير)',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasLogo ? AppTheme.brandCyan.withValues(alpha: 0.5) : const Color(0xFFCBD5E1),
                    width: hasLogo ? 1.5 : 1.0,
                  ),
                ),
                child: hasLogo
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(logoBase64),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, color: AppTheme.textMuted),
                        ),
                      )
                    : const Icon(Icons.apartment_rounded, color: AppTheme.textMuted, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLogo
                          ? 'يظهر هذا الشعار تلقائياً في ترويسة جميع التقارير والمستندات الهندسية التابعة لهذا العميل.'
                          : 'أرفق شعار الوزارة / المنظمة ليظهر رسمياً في ترويسة التقارير والشهادات الفنية.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: BorderSide(color: hasLogo ? AppTheme.primaryNavy : AppTheme.brandCyan),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(hasLogo ? Icons.change_circle_outlined : Icons.add_photo_alternate_rounded, size: 16, color: hasLogo ? AppTheme.primaryNavy : AppTheme.brandCyan),
                          label: Text(
                            hasLogo ? 'تغيير الشعار' : 'اختيار صورة الشعار',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasLogo ? AppTheme.primaryNavy : AppTheme.brandCyan,
                            ),
                          ),
                          onPressed: onPick,
                        ),
                        if (hasLogo) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'حذف الشعار',
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.statusRejected.withValues(alpha: 0.08),
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.statusRejected),
                            onPressed: onRemove,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    final nameArCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String clientType = 'جهة حكومية / وزارة';
    String? selectedLogoBase64;

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
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
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
                        color: AppTheme.solarGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_business_rounded, color: AppTheme.solarGold, size: 24),
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
                            'تسجيل بيانات الوزارة أو المنظمة أو المؤسسة والمواقع التابعة لها',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Card 0: Logo Picker
                _buildLogoSelectorCard(
                  context: ctx,
                  logoBase64: selectedLogoBase64,
                  onPick: () async {
                    try {
                      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                      if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
                        final b64 = base64Encode(res.files.first.bytes!);
                        setModalState(() {
                          selectedLogoBase64 = b64;
                        });
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر اختيار الشعار: $e')),
                        );
                      }
                    }
                  },
                  onRemove: () {
                    setModalState(() {
                      selectedLogoBase64 = null;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Card 1: Basic Info
                _buildFormSectionCard(
                  title: 'معلومات الجهة الأساسية',
                  icon: Icons.apartment_rounded,
                  children: [
                    TextField(
                      controller: nameArCtrl,
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
                    const SizedBox(height: 12),
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
                    const Text('تصنيف الجهة:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
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
                const SizedBox(height: 14),

                // Card 2: Contact Person & Phone
                _buildFormSectionCard(
                  title: 'ضابط الاتصال والتواصل المباشر',
                  icon: Icons.contact_phone_rounded,
                  children: [
                    TextField(
                      controller: contactCtrl,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        labelText: 'ضابط الاتصال / المسؤول',
                        hintText: 'مثال: د. طارق الحيدري',
                        prefixIcon: const Icon(Icons.person_rounded, size: 18, color: AppTheme.primaryNavy),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    YemeniPhoneField(
                      controller: phoneCtrl,
                      label: 'رقم الهاتف / الاتصال المعتمد',
                      hint: '777 123 456',
                      onContactPicked: (contact) {
                        if (contact.name != null && contactCtrl.text.trim().isEmpty) {
                          setModalState(() {
                            contactCtrl.text = contact.name!;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Card 3: Address
                _buildFormSectionCard(
                  title: 'المقر الرئيسي والعنوان',
                  icon: Icons.location_on_rounded,
                  children: [
                    TextField(
                      controller: addressCtrl,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        labelText: 'العنوان أو المقر الرئيسي',
                        hintText: 'مثال: صنعاء - شارع الستين - بجوار وزارة الصحة',
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
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('حفظ بيانات العميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          if (nameArCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('يرجى إدخال اسم العميل بالعربي على الأقل')),
                            );
                            return;
                          }
                          await ref.read(clientsProvider.notifier).addClient(
                            nameAr: nameArCtrl.text.trim(),
                            nameEn: nameEnCtrl.text.trim(),
                            clientType: clientType,
                            contactPerson: contactCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            address: addressCtrl.text.trim(),
                            logoBase64: selectedLogoBase64,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
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

  void _showEditClientDialog(BuildContext context, Client client) {
    final nameArCtrl = TextEditingController(text: client.nameAr);
    final nameEnCtrl = TextEditingController(text: client.nameEn);
    final contactCtrl = TextEditingController(text: client.contactPerson);
    final phoneCtrl = TextEditingController(text: client.phone);
    final addressCtrl = TextEditingController(text: client.address);
    String clientType = client.clientType;
    String? selectedLogoBase64 = client.logoBase64;

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
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
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
                        color: AppTheme.brandCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_rounded, color: AppTheme.brandCyan, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تعديل بيانات العميل',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            'تحديث بيانات الاتصال والمسؤول والمقر الرئيسي وشعار الجهة',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Card 0: Logo Picker
                _buildLogoSelectorCard(
                  context: ctx,
                  logoBase64: selectedLogoBase64,
                  onPick: () async {
                    try {
                      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                      if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
                        final b64 = base64Encode(res.files.first.bytes!);
                        setModalState(() {
                          selectedLogoBase64 = b64;
                        });
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذر اختيار الشعار: $e')),
                        );
                      }
                    }
                  },
                  onRemove: () {
                    setModalState(() {
                      selectedLogoBase64 = null;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Card 1: Basic Info
                _buildFormSectionCard(
                  title: 'معلومات الجهة الأساسية',
                  icon: Icons.apartment_rounded,
                  children: [
                    TextField(
                      controller: nameArCtrl,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        labelText: 'اسم العميل / الجهة (عربي) *',
                        prefixIcon: const Icon(Icons.business_rounded, size: 18, color: AppTheme.primaryNavy),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameEnCtrl,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        labelText: 'اسم العميل (English)',
                        prefixIcon: const Icon(Icons.language_rounded, size: 18, color: AppTheme.primaryNavy),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('تصنيف الجهة:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
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
                const SizedBox(height: 14),

                // Card 2: Contact Person & Phone
                _buildFormSectionCard(
                  title: 'ضابط الاتصال والتواصل المباشر',
                  icon: Icons.contact_phone_rounded,
                  children: [
                    TextField(
                      controller: contactCtrl,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        labelText: 'ضابط الاتصال / المسؤول',
                        prefixIcon: const Icon(Icons.person_rounded, size: 18, color: AppTheme.primaryNavy),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    YemeniPhoneField(
                      controller: phoneCtrl,
                      label: 'رقم الهاتف / الاتصال المعتمد',
                      hint: '777 123 456',
                      onContactPicked: (contact) {
                        if (contact.name != null && contactCtrl.text.trim().isEmpty) {
                          setModalState(() {
                            contactCtrl.text = contact.name!;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Card 3: Address
                _buildFormSectionCard(
                  title: 'المقر الرئيسي والعنوان',
                  icon: Icons.location_on_rounded,
                  children: [
                    TextField(
                      controller: addressCtrl,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        labelText: 'العنوان أو المقر الرئيسي',
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
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          if (nameArCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('اسم العميل بالعربي مطلوب')),
                            );
                            return;
                          }
                          final updatedClient = Client(
                            id: client.id,
                            nameAr: nameArCtrl.text.trim(),
                            nameEn: nameEnCtrl.text.trim(),
                            clientType: clientType,
                            logoBase64: selectedLogoBase64,
                            contactPerson: contactCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            email: client.email,
                            address: addressCtrl.text.trim(),
                            notes: client.notes,
                            createdAt: client.createdAt,
                            updatedAt: DateTime.now(),
                          );
                          await ref.read(clientsProvider.notifier).updateClient(updatedClient);
                          if (ctx.mounted) Navigator.pop(ctx);
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

  void _confirmDeleteClient(BuildContext context, Client client) {
    final sites = ref.read(sitesProvider);
    final reports = ref.read(reportsProvider);
    final clientSites = sites.where((s) => s.clientId == client.id).toList();
    final siteIds = clientSites.map((s) => s.id).toSet();
    final clientReports = reports.where(
      (r) => r.clientId == client.id || siteIds.contains(r.siteId),
    ).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.statusRejected, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'حذف العميل: ${client.displayName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيؤدي هذا الإجراء إلى حذف هذا العميل وجميع البيانات المرتبطة به نهائياً:',
              style: TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusRejected.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.statusRejected.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• عدد المواقع التابعة: ${clientSites.length} موقع', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('• عدد تقارير الزيارات: ${clientReports.length} تقرير', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('• كافة القياسات والصور والتوقيعات التابعة لها', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'تحذير: لا يمكن التراجع عن هذا الإجراء بعد تنفيذه.',
              style: TextStyle(fontSize: 12, color: AppTheme.statusRejected, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await deleteClientCascade(ref, client.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حذف العميل "${client.displayName}" وجميع مواقعه وتقاريره بنجاح'),
                    backgroundColor: AppTheme.primaryNavy,
                  ),
                );
              }
            },
            child: const Text('حذف نهائي شامل', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
