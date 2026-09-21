import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/core/constants/yemen_locations.dart';
import 'package:report_craft/services/default_templates.dart';

void main() {
  group('YemenLocations Tests', () {
    test('Contains all official 21 governorates and administrative divisions', () {
      expect(YemenLocations.governorates.length, 21);
      expect(YemenLocations.governorates.contains('حجة'), isTrue);
      expect(YemenLocations.governorates.contains('الحديدة'), isTrue);
      expect(YemenLocations.governorates.contains('صنعاء (أمانة العاصمة)'), isTrue);
      expect(YemenLocations.governorates.contains('تعز'), isTrue);
      expect(YemenLocations.governorates.contains('عدن'), isTrue);
    });

    test('Correctly retrieves districts for a governorate', () {
      final hajjahDistricts = YemenLocations.getDistrictsFor('حجة');
      expect(hajjahDistricts.contains('عبس'), isTrue);
      expect(hajjahDistricts.contains('حجة'), isTrue);
      expect(hajjahDistricts.contains('المحابشة'), isTrue);

      final hodeidahDistricts = YemenLocations.getDistrictsFor('الحديدة');
      expect(hodeidahDistricts.contains('باجل'), isTrue);
      expect(hodeidahDistricts.contains('بيت الفقيه'), isTrue);
      expect(hodeidahDistricts.contains('زبيد'), isTrue);
    });

    test('Handles fuzzy and empty governorate inputs', () {
      expect(YemenLocations.getDistrictsFor(''), isEmpty);
      expect(YemenLocations.getDistrictsFor(null), isEmpty);
      final capital = YemenLocations.getDistrictsFor('أمانة العاصمة');
      expect(capital.contains('معين'), isTrue);
    });
  });

  group('Report effective location getters', () {
    test('effectiveGovernorate and effectiveDistrict prefer facilityInfo then projectInfo', () {
      final base = DefaultTemplates.sampleDialysisReport;

      // 1. When facilityInfo has values
      final r1 = base.copyWith(
        facilityInfo: base.facilityInfo.copyWith(governorate: 'الحديدة', directorate: 'باجل'),
        projectInfo: base.projectInfo.copyWith(governorate: 'حجة', district: 'عبس'),
      );
      expect(r1.effectiveGovernorate, 'الحديدة');
      expect(r1.effectiveDistrict, 'باجل');

      // 2. When facilityInfo is empty, fallback to projectInfo
      final r2 = base.copyWith(
        facilityInfo: base.facilityInfo.copyWith(governorate: '', directorate: ''),
        projectInfo: base.projectInfo.copyWith(governorate: 'تعز', district: 'المخا'),
      );
      expect(r2.effectiveGovernorate, 'تعز');
      expect(r2.effectiveDistrict, 'المخا');
    });
  });
}
