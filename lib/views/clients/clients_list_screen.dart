import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/client.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../state/reports_provider.dart';
import 'client_details_screen.dart';

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
            Text(
              'دليل العملاء والمواقع',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                      final clientSites = sites.where((s) => s.clientId == client.id).toList();
                      final clientReports = reports.where((r) =>
                          r.clientId == client.id ||
                          clientSites.any((s) => s.id == r.siteId || s.nameAr == r.facilityInfo.facilityName)).length;

                      return _buildClientCard(context, client, clientSites.length, clientReports);
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

  Widget _buildClientCard(BuildContext context, Client client, int sitesCount, int reportsCount) {
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
                      Text(
                        client.contactPerson,
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textDark),
                      ),
                      if (client.phone.isNotEmpty) ...[
                        const Spacer(),
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
                  Row(
                    children: [
                      _buildChipBadge(Icons.location_on_outlined, '$sitesCount مواقع', AppTheme.primaryNavy),
                      const SizedBox(width: 8),
                      _buildChipBadge(Icons.assignment_outlined, '$reportsCount زيارة وتقارير', AppTheme.solarGold),
                    ],
                  ),
                  const Row(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.solarGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.business_outlined, size: 48, color: AppTheme.solarGold),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد عملاء مضافين حالياً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'أضف عميلاً جديداً (وزارة، منظمة، مؤسسة) ثم ابدأ بإضافة المواقع والمنشآت التابعة له.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة العميل الأول', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddClientDialog(context),
            ),
          ],
        ),
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_business, color: AppTheme.solarGold),
              SizedBox(width: 8),
              Text('إضافة عميل جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameArCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل / الجهة (عربي) *',
                    hintText: 'مثال: وزارة الصحة العامة والسكان',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameEnCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل (English)',
                    hintText: 'e.g. Ministry of Public Health',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: clientType,
                  decoration: const InputDecoration(labelText: 'نوع العميل'),
                  items: const [
                    DropdownMenuItem(value: 'جهة حكومية / وزارة', child: Text('جهة حكومية / وزارة')),
                    DropdownMenuItem(value: 'منظمة دولية / مانحة', child: Text('منظمة دولية / مانحة')),
                    DropdownMenuItem(value: 'مؤسسة محلية / مجتمعية', child: Text('مؤسسة محلية / مجتمعية')),
                    DropdownMenuItem(value: 'قطاع خاص / شركة', child: Text('قطاع خاص / شركة')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => clientType = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ضابط الاتصال / المسؤول',
                    hintText: 'مثال: د. طارق الحيدري',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف / الاتصال',
                    hintText: '+967 777 ...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'العنوان أو المقر الرئيسي',
                    hintText: 'مثال: صنعاء - الحصبة',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
              onPressed: () async {
                if (nameArCtrl.text.trim().isEmpty) return;
                await ref.read(clientsProvider.notifier).addClient(
                  nameAr: nameArCtrl.text,
                  nameEn: nameEnCtrl.text,
                  clientType: clientType,
                  contactPerson: contactCtrl.text,
                  phone: phoneCtrl.text,
                  address: addressCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ العميل'),
            ),
          ],
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit, color: AppTheme.brandCyan),
              SizedBox(width: 8),
              Text('تعديل بيانات العميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameArCtrl,
                  decoration: const InputDecoration(labelText: 'اسم العميل / الجهة (عربي) *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameEnCtrl,
                  decoration: const InputDecoration(labelText: 'اسم العميل (English)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: clientType,
                  decoration: const InputDecoration(labelText: 'نوع العميل'),
                  items: const [
                    DropdownMenuItem(value: 'جهة حكومية / وزارة', child: Text('جهة حكومية / وزارة')),
                    DropdownMenuItem(value: 'منظمة دولية / مانحة', child: Text('منظمة دولية / مانحة')),
                    DropdownMenuItem(value: 'مؤسسة محلية / مجتمعية', child: Text('مؤسسة محلية / مجتمعية')),
                    DropdownMenuItem(value: 'قطاع خاص / شركة', child: Text('قطاع خاص / شركة')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => clientType = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'ضابط الاتصال / المسؤول'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف / الاتصال'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'العنوان أو المقر الرئيسي'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandCyan),
              onPressed: () async {
                if (nameArCtrl.text.trim().isEmpty) return;
                await ref.read(clientsProvider.notifier).updateClient(
                  client.copyWith(
                    nameAr: nameArCtrl.text,
                    nameEn: nameEnCtrl.text,
                    clientType: clientType,
                    contactPerson: contactCtrl.text,
                    phone: phoneCtrl.text,
                    address: addressCtrl.text,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteClient(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف العميل "${client.nameAr}"؟ لن يتم حذف التقارير التاريخية السابقة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(clientsProvider.notifier).deleteClient(client.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
