import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_craft/core/utils/ui_helpers.dart';
import 'package:report_craft/models/organization.dart';
import 'package:report_craft/services/default_templates.dart';
import 'package:report_craft/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Signature Base64 Sanitization & Safety Tests', () {
    test('safeDecodeBase64 strips data URI scheme and decodes bytes', () {
      final original = 'Test Signature Data 12345';
      final b64 = base64Encode(utf8.encode(original));
      final withDataUri = 'data:image/png;base64,$b64';

      final decodedFromPdf = PdfExportService.safeDecodeBase64(withDataUri);
      expect(decodedFromPdf, isNotNull);
      expect(utf8.decode(decodedFromPdf!), original);

      final decodedFromUi = UiHelpers.safeDecodeBase64(withDataUri);
      expect(decodedFromUi, isNotNull);
      expect(utf8.decode(decodedFromUi!), original);
    });

    test('safeDecodeBase64 handles newlines, whitespace, and padding', () {
      final original = 'Whitespace and padding test string';
      final rawB64 = base64Encode(utf8.encode(original));
      final unpadded = rawB64.replaceAll('=', '');
      final withWhitespace = '  \n  $unpadded  \r\n  ';

      final decoded = PdfExportService.safeDecodeBase64(withWhitespace);
      expect(decoded, isNotNull);
      expect(utf8.decode(decoded!), original);
    });

    test('safeDecodeBase64 returns null for null, empty, or corrupted strings gracefully', () {
      expect(PdfExportService.safeDecodeBase64(null), isNull);
      expect(PdfExportService.safeDecodeBase64(''), isNull);
      expect(PdfExportService.safeDecodeBase64('   '), isNull);
      expect(PdfExportService.safeDecodeBase64('???not-valid-base64???'), isNull);
    });
  });

  group('Signature PDF Generation with Data URIs & Cancellation Tests', () {
    // 1x1 transparent PNG base64
    const validPngB64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

    test('Generates PDF with Data URI signatures without throwing FormatException', () async {
      final sampleReport = DefaultTemplates.sampleDialysisReport;
      const branding = OrganizationProfile(
        id: 'org_test',
        name: 'مشروع الطاقة المتجددة لدعم الخدمات الصحية في اليمن',
      );

      final reportWithDataUris = sampleReport.copyWith(
        approvalStatement: sampleReport.approvalStatement.copyWith(
          contractorSignatureBase64: 'data:image/png;base64,$validPngB64',
          beneficiarySignatureBase64: 'data:image/png;base64,$validPngB64',
          stampBase64: 'data:image/png;base64,$validPngB64',
        ),
        attendanceList: sampleReport.attendanceList.map((a) {
          return a.copyWith(signatureBase64: 'data:image/png;base64,$validPngB64');
        }).toList(),
      );

      final pdfBytes = await PdfExportService.generateReportPdf(
        report: reportWithDataUris,
        branding: branding,
        pagesToExport: [10, 11], // Dual statement & attendance
      );

      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes[0], 0x25); // %PDF
    });

    test('Generates PDF with cleared signatures without ghost signatures or crash', () async {
      final sampleReport = DefaultTemplates.sampleDialysisReport;
      const branding = OrganizationProfile(
        id: 'org_test',
        name: 'مشروع الطاقة المتجددة لدعم الخدمات الصحية في اليمن',
      );

      // Explicitly cleared signatures
      final reportWithClearedSigs = sampleReport.copyWith(
        approvalStatement: sampleReport.approvalStatement.copyWith(
          contractorSignatureBase64: '',
          beneficiarySignatureBase64: '',
          stampBase64: '',
        ),
        signatures: sampleReport.signatures.map((s) => s.copyWith(signatureBase64: '')).toList(),
        attendanceList: sampleReport.attendanceList.map((a) => a.copyWith(signatureBase64: '')).toList(),
      );

      final pdfBytes = await PdfExportService.generateReportPdf(
        report: reportWithClearedSigs,
        branding: branding,
        pagesToExport: [1, 10, 11],
      );

      expect(pdfBytes.isNotEmpty, true);
    });
  });
}
