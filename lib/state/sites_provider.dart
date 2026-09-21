import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/site.dart';
import '../models/report.dart';
import '../services/storage_service.dart';
import 'clients_provider.dart';

class SitesNotifier extends StateNotifier<List<Site>> {
  final StorageService _storage;

  SitesNotifier(this._storage) : super([]) {
    load();
  }

  Future<void> load() async {
    final list = await _storage.loadSites();
    if (mounted) state = list;
  }

  Future<Site> addSite({
    required String clientId,
    required String nameAr,
    String nameEn = '',
    String facilityType = 'مركز صحي',
    String category = 'CAT 8',
    String governorate = '',
    String directorate = '',
    String locationAddress = '',
    double? latitude,
    double? longitude,
    String funderNameAr = 'مكتب الأمم المتحدة لخدمات المشاريع - UNOPS',
    String funderNameEn = 'UNOPS',
    String? funderLogoBase64,
    bool showFunderLogo = true,
    String projectName = '',
    String contractNumber = '',
    String implementingContractor = '',
    String? contractorLogoBase64,
    SystemSpecs systemSpecs = const SystemSpecs(),
    String contactPerson = '',
    String phone = '',
    String email = '',
    String installationDate = '',
  }) async {
    const uuid = Uuid();
    final newSite = Site(
      id: 'site_${uuid.v4().substring(0, 8)}',
      clientId: clientId,
      nameAr: nameAr.trim(),
      nameEn: nameEn.trim(),
      facilityType: facilityType,
      category: category.trim(),
      governorate: governorate.trim(),
      directorate: directorate.trim(),
      locationAddress: locationAddress.trim(),
      latitude: latitude,
      longitude: longitude,
      funderNameAr: funderNameAr.trim(),
      funderNameEn: funderNameEn.trim(),
      funderLogoBase64: funderLogoBase64,
      showFunderLogo: showFunderLogo,
      projectName: projectName.trim(),
      contractNumber: contractNumber.trim(),
      implementingContractor: implementingContractor.trim(),
      contractorLogoBase64: contractorLogoBase64,
      systemSpecs: systemSpecs,
      contactPerson: contactPerson.trim(),
      phone: phone.trim(),
      email: email.trim(),
      installationDate: installationDate.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _storage.saveSingleSite(newSite);
    state = [...state, newSite]..sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return newSite;
  }

  Future<void> updateSite(Site updated) async {
    final siteWithTime = updated.copyWith(updatedAt: DateTime.now());
    await _storage.saveSingleSite(siteWithTime);
    state = [
      for (final s in state)
        if (s.id == updated.id) siteWithTime else s
    ]..sort((a, b) => a.nameAr.compareTo(b.nameAr));
  }

  Future<void> deleteSite(String id) async {
    await _storage.deleteSite(id);
    state = state.where((s) => s.id != id).toList();
  }

  List<Site> getSitesForClient(String clientId) {
    return state.where((s) => s.clientId == clientId).toList();
  }

  List<Site> search({String query = '', String? clientId}) {
    final q = query.trim().toLowerCase();
    var list = state;
    if (clientId != null && clientId.isNotEmpty) {
      list = list.where((s) => s.clientId == clientId).toList();
    }
    if (q.isEmpty) return list;
    return list.where((s) {
      return s.nameAr.toLowerCase().contains(q) ||
          s.nameEn.toLowerCase().contains(q) ||
          s.governorate.toLowerCase().contains(q) ||
          s.directorate.toLowerCase().contains(q) ||
          s.funderNameAr.toLowerCase().contains(q) ||
          s.contractNumber.toLowerCase().contains(q) ||
          s.contactPerson.toLowerCase().contains(q);
    }).toList();
  }
}

final sitesProvider = StateNotifierProvider<SitesNotifier, List<Site>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SitesNotifier(storage);
});

final sitesForClientProvider = Provider.family<List<Site>, String>((ref, clientId) {
  final sites = ref.watch(sitesProvider);
  return sites.where((s) => s.clientId == clientId).toList();
});

final siteByIdProvider = Provider.family<Site?, String>((ref, siteId) {
  final sites = ref.watch(sitesProvider);
  try {
    return sites.firstWhere((s) => s.id == siteId);
  } catch (_) {
    return null;
  }
});
