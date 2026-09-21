import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../services/storage_service.dart';
import 'sites_provider.dart';
import 'reports_provider.dart';

class ClientsNotifier extends StateNotifier<List<Client>> {
  final StorageService _storage;

  ClientsNotifier(this._storage) : super([]) {
    load();
  }

  Future<void> load() async {
    final list = await _storage.loadClients();
    if (mounted) state = list;
  }

  Future<Client> addClient({
    required String nameAr,
    String nameEn = '',
    String clientType = 'جهة حكومية / وزارة',
    String? logoBase64,
    String contactPerson = '',
    String phone = '',
    String email = '',
    String address = '',
    String notes = '',
  }) async {
    const uuid = Uuid();
    final newClient = Client(
      id: 'client_${uuid.v4().substring(0, 8)}',
      nameAr: nameAr.trim(),
      nameEn: nameEn.trim(),
      clientType: clientType,
      logoBase64: logoBase64,
      contactPerson: contactPerson.trim(),
      phone: phone.trim(),
      email: email.trim(),
      address: address.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _storage.saveSingleClient(newClient);
    state = [...state, newClient]..sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return newClient;
  }

  Future<void> updateClient(Client updated) async {
    final clientWithTime = updated.copyWith(updatedAt: DateTime.now());
    await _storage.saveSingleClient(clientWithTime);
    state = [
      for (final c in state)
        if (c.id == updated.id) clientWithTime else c
    ]..sort((a, b) => a.nameAr.compareTo(b.nameAr));
  }

  Future<void> deleteClient(String id) async {
    await _storage.deleteClient(id);
    state = state.where((c) => c.id != id).toList();
  }

  List<Client> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return state;
    return state.where((c) {
      return c.nameAr.toLowerCase().contains(q) ||
          c.nameEn.toLowerCase().contains(q) ||
          c.contactPerson.toLowerCase().contains(q) ||
          c.clientType.toLowerCase().contains(q);
    }).toList();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ClientsNotifier(storage);
});

/// العميل بمعرفه
final clientByIdProvider = Provider.family<Client?, String>((ref, clientId) {
  final clients = ref.watch(clientsProvider);
  try {
    return clients.firstWhere((c) => c.id == clientId);
  } catch (_) {
    return null;
  }
});

/// حذف عميل مع جميع مواقعه وتقاريره (Cascade Delete)
/// يُستدعى من الـ UI مع ref
Future<CascadeDeleteInfo> deleteClientCascade(WidgetRef ref, String clientId) async {
  // تجميع المعلومات قبل الحذف
  final sites = ref.read(sitesProvider);
  final reports = ref.read(reportsProvider);
  final clientSites = sites.where((s) => s.clientId == clientId).toList();
  final siteIds = clientSites.map((s) => s.id).toSet();
  final clientReports = reports.where(
    (r) => r.clientId == clientId || siteIds.contains(r.siteId),
  ).toList();

  final info = CascadeDeleteInfo(
    sitesCount: clientSites.length,
    reportsCount: clientReports.length,
  );

  // حذف التقارير أولاً
  for (final report in clientReports) {
    await ref.read(reportsProvider.notifier).deleteReport(report.id);
  }

  // حذف المواقع
  for (final site in clientSites) {
    await ref.read(sitesProvider.notifier).deleteSite(site.id);
  }

  // حذف العميل
  await ref.read(clientsProvider.notifier).deleteClient(clientId);

  return info;
}

/// حذف موقع مع جميع تقاريره (Cascade Delete)
Future<CascadeDeleteInfo> deleteSiteCascade(WidgetRef ref, String siteId) async {
  final reports = ref.read(reportsProvider);
  final siteReports = reports.where((r) => r.siteId == siteId).toList();

  final info = CascadeDeleteInfo(
    sitesCount: 1,
    reportsCount: siteReports.length,
  );

  // حذف التقارير أولاً
  for (final report in siteReports) {
    await ref.read(reportsProvider.notifier).deleteReport(report.id);
  }

  // حذف الموقع
  await ref.read(sitesProvider.notifier).deleteSite(siteId);

  return info;
}

/// معلومات الحذف المتدرج — تُستخدم في حوار التأكيد
class CascadeDeleteInfo {
  final int sitesCount;
  final int reportsCount;

  const CascadeDeleteInfo({
    required this.sitesCount,
    required this.reportsCount,
  });
}
