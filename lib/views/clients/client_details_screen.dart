import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/client.dart';
import '../../models/site.dart';
import '../../models/report.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../../state/reports_provider.dart';
import '../sites/site_details_screen.dart';
import '../sites/site_form_screen.dart';
import '../session/maintenance_session_screen.dart';

class ClientDetailsScreen extends ConsumerWidget {
  final Client client;

  const ClientDetailsScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep live client state if edited
    final allClients = ref.watch(clientsProvider);
    final currentClient = allClients.firstWhere(
      (c) => c.id == client.id,
      orElse: () => client,
    );

    final sites = ref.watch(sitesForClientProvider(currentClient.id));
    final reports = ref.watch(reportsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: AppBar(
        title: Text(
          currentClient.nameAr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ─── Client Profile Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.primaryNavy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client Avatar or Logo
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: currentClient.logoBase64 != null && currentClient.logoBase64!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(
                                base64Decode(currentClient.logoBase64!),
                                fit: BoxFit.contain,
                              ),
                            )
                          : const Icon(Icons.apartment, color: AppTheme.primaryNavy, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentClient.nameAr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (currentClient.nameEn.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              currentClient.nameEn,
                              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.brandCyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currentClient.clientType,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.brandCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (currentClient.contactPerson.isNotEmpty || currentClient.phone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: AppTheme.solarGold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          currentClient.contactPerson,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        if (currentClient.phone.isNotEmpty) ...[
                          const Spacer(),
                          const Icon(Icons.phone, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            currentClient.phone,
                            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Sites Section Header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pin_drop, color: AppTheme.primaryNavy, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'المواقع والمنشآت التابعة (${sites.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.solarGold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_location_alt, size: 16),
                  label: const Text('إضافة موقع جديد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiteFormScreen(clientId: currentClient.id),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ─── Sites List ─────────────────────────────────────────────────────
          Expanded(
            child: sites.isEmpty
                ? _buildNoSitesState(context, currentClient)
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: sites.length,
                    itemBuilder: (context, index) {
                      final site = sites[index];
                      final siteReports = reports
                          .where((r) => r.siteId == site.id || r.facilityInfo.facilityName == site.nameAr)
                          .toList();

                      return _buildSiteCard(context, ref, site, currentClient, siteReports);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(
    BuildContext context,
    WidgetRef ref,
    Site site,
    Client client,
    List<Report> siteReports,
  ) {
    int nextVisitNum = 1;
    if (siteReports.isNotEmpty) {
      final nums = siteReports.map((r) => int.tryParse(r.visitNumber) ?? 1).toList();
      nums.sort();
      nextVisitNum = nums.last + 1;
    }

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
              builder: (_) => SiteDetailsScreen(site: site),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Site Row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.solarGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.solar_power, color: AppTheme.solarGold, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.nameAr,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        if (site.nameEn.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            site.nameEn,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          '${site.governorate} • ${site.directorate}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      site.category,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Dedicated Funder & Specs Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, size: 16, color: AppTheme.brandCyan),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'الممول: ${site.funderNameAr}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (site.systemSpecs.capacityKw.isNotEmpty) ...[
                      Text(
                        site.systemSpecs.capacityKw,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.solarGold),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: AppTheme.borderSubtle),
              const SizedBox(height: 8),

              // Bottom Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الزيارات المنفذة: ${siteReports.length}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.rocket_launch, size: 14),
                        label: Text(
                          'بدء زيارة ($nextVisitNum)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final newReport = await ref.read(reportsProvider.notifier).createReportForSite(
                            site: site,
                            client: client,
                            customVisitNumber: nextVisitNum.toString(),
                          );
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MaintenanceSessionScreen(reportId: newReport.id),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SiteDetailsScreen(site: site),
                            ),
                          );
                        },
                        child: const Text('ملف الموقع', style: TextStyle(fontSize: 11)),
                      ),
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

  Widget _buildNoSitesState(BuildContext context, Client client) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text(
              'لا توجد مواقع مسجلة لهذا العميل بعد',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'أضف المواقع والمنشآت التابعة لهذا العميل وحدد الممول الخاص بكل موقع ومواصفاته الفنية.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.solarGold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_location_alt, size: 18),
              label: const Text('إضافة أول موقع الآن', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SiteFormScreen(clientId: client.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
