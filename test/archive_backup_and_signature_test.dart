import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Archive Backup & Restore Tests', () {
    test('Can encode and decode archive with database and simulated photos', () async {
      final archive = Archive();

      // Simulated database JSON
      final dummyDb = {
        'version': '2.1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'reports': <Map<String, dynamic>>[],
        'templates': <Map<String, dynamic>>[],
        'branding': {'id': 'org_default'},
        'clients': [
          {
            'id': 'c_1',
            'nameAr': 'عميل تجريبي',
            'clientType': 'مستشفى',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ],
        'sites': [
          {
            'id': 's_1',
            'clientId': 'c_1',
            'nameAr': 'موقع تجريبي',
            'category': 'طبي',
            'governorate': 'أمانة العاصمة',
            'directorate': 'معين',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ],
      };

      final dbBytes = utf8.encode(jsonEncode(dummyDb));
      archive.addFile(ArchiveFile('database.json', dbBytes.length, dbBytes));

      // Add dummy photo files
      final dummyPhotoBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]; // JPEG header
      archive.addFile(ArchiveFile('photos/test_photo_1.jpg', dummyPhotoBytes.length, dummyPhotoBytes));
      archive.addFile(ArchiveFile('photos/test_photo_2.jpg', dummyPhotoBytes.length, dummyPhotoBytes));

      // Encode archive
      final zipBytes = ZipEncoder().encode(archive);
      expect(zipBytes, isNotNull);
      expect(zipBytes.length, greaterThan(0));

      // Decode archive
      final decodedArchive = ZipDecoder().decodeBytes(zipBytes);
      ArchiveFile? decodedDb;
      int photoCount = 0;

      for (final file in decodedArchive) {
        if (file.name == 'database.json') {
          decodedDb = file;
        } else if (file.name.startsWith('photos/') && !file.isDirectory) {
          photoCount++;
        }
      }

      expect(decodedDb, isNotNull);
      expect(photoCount, 2);

      final decodedContent = utf8.decode(decodedDb!.content as List<int>);
      final parsed = jsonDecode(decodedContent) as Map<String, dynamic>;
      expect(parsed['clients'].length, 1);
      expect(parsed['sites'].length, 1);
      expect(parsed['clients'][0]['nameAr'], 'عميل تجريبي');
    });

    test('BackupInspectionResult holds correct fields for archive and JSON', () {
      const archiveResult = BackupInspectionResult(
        isValid: true,
        reportCount: 5,
        templateCount: 2,
        clientCount: 3,
        siteCount: 4,
        photosCount: 12,
        isArchive: true,
      );

      expect(archiveResult.isValid, isTrue);
      expect(archiveResult.isArchive, isTrue);
      expect(archiveResult.photosCount, 12);
      expect(archiveResult.clientCount, 3);
      expect(archiveResult.siteCount, 4);

      const jsonResult = BackupInspectionResult(
        isValid: true,
        reportCount: 3,
        isArchive: false,
      );

      expect(jsonResult.isArchive, isFalse);
      expect(jsonResult.photosCount, 0);
    });
  });
}
