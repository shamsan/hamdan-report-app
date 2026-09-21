import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/organization.dart';
import '../services/storage_service.dart';

class BrandingNotifier extends StateNotifier<OrganizationProfile> {
  final StorageService _storage;

  BrandingNotifier(this._storage)
      : super(const OrganizationProfile(
          id: 'org_default',
          name: 'مكتب الأتقان الهندسي للخدمات الهندسية وحلول الطاقة',
          subTitle: 'للخدمات الهندسية وحلول الطاقة',
        )) {
    load();
  }

  Future<void> load() async {
    final profile = await _storage.loadBranding();
    state = profile;
  }

  Future<void> updateProfile(OrganizationProfile updated) async {
    state = updated;
    await _storage.saveBranding(updated);
  }

  Future<void> updateColors({int? primaryColor, int? secondaryColor}) async {
    final updated = state.copyWith(
      primaryColorValue: primaryColor ?? state.primaryColorValue,
      secondaryColorValue: secondaryColor ?? state.secondaryColorValue,
    );
    await updateProfile(updated);
  }
}

final brandingProvider = StateNotifierProvider<BrandingNotifier, OrganizationProfile>((ref) {
  return BrandingNotifier(StorageService());
});
