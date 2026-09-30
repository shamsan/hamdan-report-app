import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/organization.dart';
import '../models/inspection_item.dart';
import '../models/measurement_data.dart';
import '../models/signature_data.dart';
import '../models/report_photo.dart';
import '../models/maintenance_need.dart';
import '../models/report.dart';
import '../core/utils/arabic_reshaper.dart';
import 'default_templates.dart';
import 'package:image/image.dart' as image_pkg;
import '../core/licensing/security/secure_quota_store.dart';

class PdfExportService {
  /// Safely sanitizes and decodes a base64 image string (strips data URIs, whitespace, handles padding)
  static Uint8List? safeDecodeBase64(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.contains(',')) {
      cleaned = cleaned.substring(cleaned.indexOf(',') + 1).trim();
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return null;
    final remainder = cleaned.length % 4;
    if (remainder > 0) {
      cleaned = cleaned.padRight(cleaned.length + (4 - remainder), '=');
    }
    try {
      final bytes = base64Decode(cleaned);
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  /// Safely wraps a base64 image into pw.MemoryImage without throwing
  static pw.MemoryImage? safeMemoryImage(String? base64Str) {
    final bytes = safeDecodeBase64(base64Str);
    if (bytes != null && bytes.isNotEmpty) {
      try {
        return pw.MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Safely trims any excess transparent or solid whitespace around signatures and returns pw.MemoryImage
  static pw.MemoryImage? safeSignatureImage(String? base64Str) {
    final bytes = safeDecodeBase64(base64Str);
    if (bytes != null && bytes.isNotEmpty) {
      try {
        final decoded = image_pkg.decodeImage(bytes);
        if (decoded != null) {
          image_pkg.Image trimmed;
          if (decoded.hasAlpha) {
            trimmed = image_pkg.trim(decoded, mode: image_pkg.TrimMode.transparent, padding: 6);
          } else {
            trimmed = image_pkg.trim(decoded, mode: image_pkg.TrimMode.topLeftColor, fuzzy: 0.08, padding: 6);
          }
          if (trimmed.width > 0 && trimmed.height > 0) {
            final trimmedBytes = Uint8List.fromList(image_pkg.encodePng(trimmed));
            return pw.MemoryImage(trimmedBytes);
          }
        }
        return pw.MemoryImage(bytes);
      } catch (_) {
        try {
          return pw.MemoryImage(bytes);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  /// Helper to reshape and bidi Arabic text for PDF
  static String _ar(String? text, [int? maxCharsPerLine]) {
    if (text == null || text.trim().isEmpty) return '';
    return ArabicReshaper.shapeAndBidi(text, maxCharsPerLine: maxCharsPerLine);
  }

  /// Helper specifically for notes and comments in tables to wrap downwards cleanly
  static String _arNotes(String? text, [int maxChars = 28]) {
    if (text == null || text.trim().isEmpty) return '';
    return ArabicReshaper.shapeAndBidi(text, maxCharsPerLine: maxChars);
  }

  /// Wraps Arabic text dynamically to fill the available width from margin to margin
  /// ensuring lines never break prematurely or leave empty gaps.
  static String wrapArabicByWidth(String text, double maxWidth, double fontSize, PdfFont font) {
    if (text.isEmpty) return text;
    final tokenPattern = RegExp(r'\([^\)]*\)[\.\,\:\;\!\؟\?\،]*|\[[^\]]*\][\.\,\:\;\!\؟\?\،]*|\S+');
    final words = tokenPattern.allMatches(text.trim()).map((m) => m.group(0)!).toList();
    final lines = <String>[];
    String currentLine = '';

    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      final reshaped = ArabicReshaper.shapeAndBidi(testLine);
      final width = font.stringMetrics(reshaped).size.x * fontSize;
      if (width <= maxWidth || currentLine.isEmpty) {
        currentLine = testLine;
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines.map((l) => ArabicReshaper.shapeAndBidi(l)).join('\n');
  }

  /// Builds and returns the multi-page PDF document as bytes matching the reference PDF 1:1
  static Future<Uint8List> generateReportPdf({
    required Report report,
    required OrganizationProfile branding,
    List<int>? pagesToExport,
  }) async {
    // 🛡️ فحص ومنع إعادة التدوير للتقارير (Anti-Recycling Check)
    await SecureQuotaStore.trackPdfExportEvent(
      reportId: report.id,
      facilityName: report.facilityInfo.facilityName,
      visitDate: report.visitDate,
    );

    final pdf = pw.Document();

    // 1. Load Arabic TrueType fonts from assets (Official Pure Arabic Naskh - Noto Naskh Arabic)
    final fontRegularData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf');
    final fontFallbackData = await rootBundle.load('assets/fonts/Tahoma-Regular.ttf');
    final ttfRegular = pw.Font.ttf(fontRegularData);
    final ttfBold = pw.Font.ttf(fontBoldData);
    final ttfFallback = pw.Font.ttf(fontFallbackData);

    // 2. Load authentic logos (Hierarchical: Report custom -> Global branding -> Asset fallback)
    pw.MemoryImage? logoFacility;
    pw.MemoryImage? logoUnops;
    pw.MemoryImage? logoContractor;

    // A. Contractor Logo
    try {
      final customContractor = report.contractorLogoBase64;
      final customImg = safeMemoryImage(customContractor);
      final brandImg = safeMemoryImage(branding.contractorLogoBase64);
      if (customImg != null) {
        logoContractor = customImg;
      } else if (brandImg != null) {
        logoContractor = brandImg;
      } else {
        final d = await rootBundle.load('assets/logos/logo_contractor.png');
        logoContractor = pw.MemoryImage(d.buffer.asUint8List());
      }
    } catch (_) {}

    // B. Ministry / Facility Logo
    try {
      final customMinistry = report.ministryLogoBase64;
      final customImg = safeMemoryImage(customMinistry);
      final brandImg = safeMemoryImage(branding.facilityLogoBase64);
      if (customImg != null) {
        logoFacility = customImg;
      } else if (brandImg != null) {
        logoFacility = brandImg;
      } else {
        final d = await rootBundle.load('assets/logos/logo_facility.png');
        logoFacility = pw.MemoryImage(d.buffer.asUint8List());
      }
    } catch (_) {}

    // C. Funder / Right Logo
    try {
      final customFunder = report.funderLogoBase64;
      final customImg = safeMemoryImage(customFunder);
      final brandImg = safeMemoryImage(branding.unopsLogoBase64);
      if (customImg != null) {
        logoUnops = customImg;
      } else if (brandImg != null) {
        logoUnops = brandImg;
      } else {
        final d = await rootBundle.load('assets/logos/logo_unops.png');
        logoUnops = pw.MemoryImage(d.buffer.asUint8List());
      }
    } catch (_) {}

    // 2.5. Load Digital Signatures & Stamps for Running Footer & Page 10
    final engSigBase64 = (report.approvalStatement.contractorSignatureBase64 != null && report.approvalStatement.contractorSignatureBase64!.trim().isNotEmpty)
        ? report.approvalStatement.contractorSignatureBase64!.trim()
        : report.signatures.cast<ReportSignature?>().firstWhere(
            (s) => s != null && s.signatureBase64 != null && s.signatureBase64!.trim().isNotEmpty &&
                   (s.role.contains('مهندس') || s.role.contains('صيانة') || s.role.contains('مقاول') || s.role.contains('فني')) &&
                   !s.role.contains('مستفيد') && !s.role.contains('مرفق') && !s.role.contains('عميل'),
            orElse: () => null,
          )?.signatureBase64;

    final pw.MemoryImage? engineerSigImage = safeSignatureImage(engSigBase64);

    final effectiveRepName = report.approvalStatement.beneficiaryRepName.isNotEmpty
        ? report.approvalStatement.beneficiaryRepName
        : report.facilityInfo.contactPerson;

    final benSigBase64 = (report.approvalStatement.beneficiarySignatureBase64 != null && report.approvalStatement.beneficiarySignatureBase64!.trim().isNotEmpty)
        ? report.approvalStatement.beneficiarySignatureBase64!.trim()
        : (report.signatures.cast<ReportSignature?>().firstWhere(
            (s) => s != null && s.signatureBase64 != null && s.signatureBase64!.trim().isNotEmpty &&
                   (s.role.contains('مستفيد') || s.role.contains('مرفق') || s.role.contains('مدير') || s.role.contains('عميل') || s.role.contains('إدارة') ||
                    (effectiveRepName.isNotEmpty && (s.signerName == effectiveRepName || s.signerName.contains(effectiveRepName)))) &&
                   !s.role.contains('مهندس') && !s.role.contains('صيانة') && !s.role.contains('مقاول'),
            orElse: () => null,
          )?.signatureBase64 ??
          report.attendanceList.cast<AttendanceRecord?>().firstWhere(
            (a) => a != null && a.signatureBase64 != null && a.signatureBase64!.trim().isNotEmpty &&
                   (a.role.contains('مدير') || a.role.contains('مستفيد') || a.role.contains('مرفق') || a.role.contains('مسؤول') ||
                    (effectiveRepName.isNotEmpty && (a.name == effectiveRepName || a.name.contains(effectiveRepName) || effectiveRepName.contains(a.name)))) &&
                   !a.role.contains('مهندس') && !a.role.contains('صيانة') && !a.role.contains('فني'),
            orElse: () => null,
          )?.signatureBase64);

    final pw.MemoryImage? beneficiarySigImage = safeSignatureImage(benSigBase64);

    final pw.MemoryImage? stampImage = safeMemoryImage(report.approvalStatement.stampBase64);

    // 3. Brand & Theme Colors matching the reference PDF
    final goldColor = PdfColor.fromHex('EAA023');
    final cyanColor = PdfColor.fromHex('009FE3');
    final darkNavyColor = PdfColor.fromHex('0B3A60');
    final tableHeaderBg = PdfColor.fromHex('DCE4EC');
    final borderGrey = PdfColor.fromHex('CBD5E1');
    final lightBeige = PdfColor.fromHex('FCEBB6');
    final lightCyanBg = PdfColor.fromHex('7CD5EC');
    final creamBg = PdfColor.fromHex('FFF9E6');

    pw.TextStyle textStyle({double size = 8.0, bool isBold = false, PdfColor color = PdfColors.black, double? lineSpacing}) {
      return pw.TextStyle(
        font: isBold ? ttfBold : ttfRegular,
        fontFallback: [ttfFallback],
        fontSize: size,
        color: color,
        lineSpacing: lineSpacing,
      );
    }

    // Vector checkmark to avoid font glyph dependency
    pw.Widget buildCheckmark({PdfColor color = PdfColors.green900, double size = 8.0}) {
      return pw.SizedBox(
        width: size,
        height: size,
        child: pw.CustomPaint(
          painter: (PdfGraphics canvas, PdfPoint pSize) {
            canvas.setColor(color);
            canvas.setLineWidth(1.3);
            canvas.moveTo(pSize.x * 0.15, pSize.y * 0.5);
            canvas.lineTo(pSize.x * 0.4, pSize.y * 0.2);
            canvas.lineTo(pSize.x * 0.85, pSize.y * 0.85);
            canvas.strokePath();
          },
        ),
      );
    }

    final effectiveVisitNum = report.visitNumber.isNotEmpty
        ? report.visitNumber
        : (report.facilityInfo.visitNumber.isNotEmpty ? report.facilityInfo.visitNumber : '');

    // Dynamic contractor branding (Report custom -> Project info -> Global branding -> Empty)
    final contractorAr = (report.contractorNameAr != null && report.contractorNameAr!.trim().isNotEmpty)
        ? report.contractorNameAr!.trim()
        : (report.projectInfo.implementingContractor.trim().isNotEmpty
            ? report.projectInfo.implementingContractor.trim()
            : branding.contractorNameAr.trim());

    final contractorSub = (report.contractorSubtitleAr != null && report.contractorSubtitleAr!.trim().isNotEmpty)
        ? report.contractorSubtitleAr!.trim()
        : branding.contractorSubtitleAr.trim();

    final contractorEn = (report.contractorNameEn != null && report.contractorNameEn!.trim().isNotEmpty)
        ? report.contractorNameEn!.trim()
        : branding.contractorNameEn.trim();

    // Dynamic ministry / entity branding
    final ministryAr = (report.ministryNameAr != null && report.ministryNameAr!.trim().isNotEmpty)
        ? report.ministryNameAr!.trim()
        : (report.projectInfo.ownerEntity.trim().isNotEmpty
            ? report.projectInfo.ownerEntity.trim()
            : branding.ministryNameAr.trim());

    final ministryEn = (report.ministryNameEn != null && report.ministryNameEn!.trim().isNotEmpty)
        ? report.ministryNameEn!.trim()
        : branding.ministryNameEn.trim();

    // Dynamic funder / right branding
    final showRight = report.showRightLogo ?? branding.showRightLogo;
    final rightEn = (report.funderNameEn != null && report.funderNameEn!.trim().isNotEmpty)
        ? report.funderNameEn!.trim()
        : branding.rightLogoNameEn.trim();

    final rightAr = (report.funderNameAr != null && report.funderNameAr!.trim().isNotEmpty)
        ? report.funderNameAr!.trim()
        : (report.projectInfo.funder.trim().isNotEmpty
            ? report.projectInfo.funder.trim()
            : branding.rightLogoNameAr.trim());

    final headerArabicBlue = PdfColor.fromHex('1565C0');
    final headerEnglishBlack = PdfColors.black;


    // Strictly vertical pages with extreme vertical density (42 items, 28 items, official signatures)
    // These pages must remain Portrait to prevent content truncation or PDF layout exceptions.
    const lockedPortraitPages = {1, 2, 3, 4, 5, 10, 11};

    String getPageMode(int pageNumber) {
      if (lockedPortraitPages.contains(pageNumber)) {
        return 'portrait';
      }
      // الصفحة 9: مصفوفة سلاسل التوليد وصناديق التجميع (أفقي، دفتري، أو عمودي عند قلة الصناديق)
      if (pageNumber == 9) {
        String? rawPref = report.pageOrientations[9];
        if (rawPref == null) {
          final dynamicMap = report.pageOrientations as dynamic;
          try {
            rawPref = dynamicMap['9']?.toString();
          } catch (_) {}
        }
        final pref = (rawPref ?? '').toLowerCase().trim();
        if (pref.contains('book') || pref.contains('rotated')) return 'book';
        if (pref.contains('portrait') || pref.contains('vertical')) {
          final activeCount = report.activeCombinerBoxes.isNotEmpty
              ? report.activeCombinerBoxes.length
              : 4;
          if (activeCount <= 8) return 'portrait';
        }
        if (pref.contains('landscape') || pref.contains('horizontal')) return 'landscape';
        return 'landscape';
      }
      String? rawPref = report.pageOrientations[pageNumber];
      if (rawPref == null) {
        final dynamicMap = report.pageOrientations as dynamic;
        try {
          rawPref = dynamicMap[pageNumber.toString()]?.toString();
        } catch (_) {}
      }
      final pref = (rawPref ?? '').toLowerCase().trim();
      if (pref.contains('book') || pref.contains('rotated')) return 'book';
      if (pref.contains('landscape') || pref.contains('horizontal')) return 'landscape';
      if (pref.contains('portrait') || pref.contains('vertical')) return 'portrait';
      // Default: pages 8 and 9 are True Landscape for pristine digital display on phones & WhatsApp
      return (pageNumber == 8 || pageNumber == 9) ? 'landscape' : 'portrait';
    }

    String getPageSize(int pageNumber) {
      // Document-wide paper size consistency check:
      // Ensures document never mixes A4 and A3 (preventing printer tray errors and scaling issues)
      final orientations = report.pageOrientations;
      bool hasA3 = false;
      for (final val in orientations.values) {
        if (val.toLowerCase().contains('a3')) {
          hasA3 = true;
          break;
        }
      }
      return hasA3 ? 'a3' : 'a4';
    }

    // Helper: Dynamically resolve page format and orientation based on engineer's choice (A4/A3, Portrait/Landscape/Book)
    PdfPageFormat resolvePageFormat(int pageNumber, {PdfPageFormat defaultFormat = PdfPageFormat.a4}) {
      final size = getPageSize(pageNumber);
      final mode = getPageMode(pageNumber);

      final isA3 = size == 'a3';
      final baseA3 = PdfPageFormat.a3;
      final baseA4 = PdfPageFormat.a4;

      // In book mode, physical page orientation is ALWAYS Portrait (A4 or A3), with content rotated inside!
      if (mode == 'book') {
        return isA3 ? baseA3 : baseA4;
      }

      // In landscape mode, physical page is Landscape
      if (mode == 'landscape') {
        return isA3 ? baseA3.landscape : baseA4.landscape;
      }

      // In portrait mode, physical page is Portrait
      return isA3 ? baseA3 : baseA4;
    }

    // Helper: Rotates content by 90 degrees inside a portrait page (Book Mode / التدوير الدفتري المعتمد)
    pw.Widget wrapWithBookModeRotation({
      required pw.Widget child,
      required double rotW,
      required double rotH,
      pw.EdgeInsets padding = const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 8),
    }) {
      return pw.Center(
        child: pw.Transform.rotateBox(
          unconstrained: true,
          angle: -math.pi / 2,
          child: pw.Container(
            width: rotW,
            height: rotH,
            padding: padding,
            child: child,
          ),
        ),
      );
    }

    // Helper: Formats lines under logos according to institutional typographic standards
    // Supports:
    // 1. Explicit line breaks (\n) if entered by the user (up to 3 lines).
    // 2. Intelligent, balanced word wrapping into 1, 2, or 3 lines when entered on a single line.
    // 3. Dynamic font scaling so that 1, 2, or 3 lines maintain clean visual balance and never overflow.
    // 4. Proper Arabic character shaping (_ar) per line.
    List<pw.Widget> buildHeaderLines(
      String rawText, {
      required bool isArabic,
      required PdfColor color,
      double? baseFontSize,
      bool isBold = false,
      double lineSpacing = 0.5,
      bool isLandscape = false,
    }) {
      final text = rawText.trim();
      if (text.isEmpty) return [];

      List<String> lines = [];

      // Check if user explicitly used newlines
      if (text.contains('\n')) {
        lines = text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .take(3)
            .toList();
      }

      if (lines.isEmpty) {
        // Single continuous string - determine optimal lines count (1, 2, or 3)
        final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final length = text.length;

        // Maximum single-line threshold calibrated to the full column width boundary
        // (170pt portrait allows ~42 Arabic / ~48 English chars; 205pt landscape allows ~50 Arabic / ~58 English chars)
        final int singleLineLimit = isLandscape
            ? (isArabic ? 50 : 58)
            : (isArabic ? 42 : 48);

        final int doubleLineLimit = singleLineLimit * 2;

        if (words.length <= 1 || length <= singleLineLimit) {
          // 1 line - fills up to the maximum column limit without premature breaking
          lines = [text];
        } else if (words.length == 2 || length <= doubleLineLimit) {
          // 2 balanced lines
          int bestSplit = 1;
          int minDiff = 99999;
          for (int i = 1; i < words.length; i++) {
            final l1 = words.sublist(0, i).join(' ');
            final l2 = words.sublist(i).join(' ');
            final diff = (l1.length - l2.length).abs();
            if (diff < minDiff) {
              minDiff = diff;
              bestSplit = i;
            }
          }
          lines = [
            words.sublist(0, bestSplit).join(' '),
            words.sublist(bestSplit).join(' '),
          ];
        } else {
          // 3 balanced lines
          int bestSplit1 = 1;
          int bestSplit2 = 2;
          double minVariance = 999999.0;
          for (int i = 1; i < words.length - 1; i++) {
            for (int j = i + 1; j < words.length; j++) {
              final len1 = words.sublist(0, i).join(' ').length.toDouble();
              final len2 = words.sublist(i, j).join(' ').length.toDouble();
              final len3 = words.sublist(j).join(' ').length.toDouble();
              final mean = (len1 + len2 + len3) / 3.0;
              final variance = ((len1 - mean) * (len1 - mean) +
                                (len2 - mean) * (len2 - mean) +
                                (len3 - mean) * (len3 - mean));
              if (variance < minVariance) {
                minVariance = variance;
                bestSplit1 = i;
                bestSplit2 = j;
              }
            }
          }
          lines = [
            words.sublist(0, bestSplit1).join(' '),
            words.sublist(bestSplit1, bestSplit2).join(' '),
            words.sublist(bestSplit2).join(' '),
          ];
        }
      }

      // Dynamic Font Scaling based on line count and language
      final lineCount = lines.length;
      final double defaultBaseSize = isArabic ? 6.8 : 5.2;
      double calcFontSize = baseFontSize ?? defaultBaseSize;

      if (lineCount == 2) {
        calcFontSize = (baseFontSize ?? defaultBaseSize) * (isArabic ? 0.92 : 0.94);
      } else if (lineCount >= 3) {
        calcFontSize = (baseFontSize ?? defaultBaseSize) * (isArabic ? 0.82 : 0.84);
      }

      // Safeguard for ultra-long lines: scale font down if longest line exceeds column width capacity
      int maxLineLength = 0;
      for (final l in lines) {
        if (l.length > maxLineLength) maxLineLength = l.length;
      }
      final int charThreshold = isLandscape
          ? (isArabic ? 50 : 58)
          : (isArabic ? 42 : 48);
      if (maxLineLength > charThreshold) {
        final scale = charThreshold / maxLineLength;
        calcFontSize = (calcFontSize * scale).clamp(3.8, calcFontSize);
      }

      final widgets = <pw.Widget>[];
      for (int i = 0; i < lines.length; i++) {
        final lineStr = isArabic ? _ar(lines[i]) : lines[i];
        if (i > 0) {
          widgets.add(pw.SizedBox(height: lineSpacing));
        }
        widgets.add(
          pw.Text(
            lineStr,
            textAlign: pw.TextAlign.center,
            style: textStyle(
              size: calcFontSize,
              isBold: isBold,
              color: color,
            ),
          ),
        );
      }
      return widgets;
    }

    // Helper: Institutional Running Header (Top of every page)
    pw.Widget buildRunningHeader({bool isLandscape = false}) {
      final logoColWidth = isLandscape ? 205.0 : 170.0;

      // 1. Left: Contractor Logo + English (Black) then Arabic (Blue)
      final contractorWidget = pw.SizedBox(
        width: logoColWidth,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoContractor != null)
              pw.Image(logoContractor, height: isLandscape ? 33 : 36, width: 95, fit: pw.BoxFit.contain)
            else
              pw.SizedBox(height: isLandscape ? 33 : 36, width: 95),
            pw.SizedBox(height: 1.5),
            // English Name in Black FIRST (supports 1, 2, or 3 lines)
            ...buildHeaderLines(
              contractorEn,
              isArabic: false,
              color: headerEnglishBlack,
              baseFontSize: 5.2,
              isBold: true,
              isLandscape: isLandscape,
            ),
            pw.SizedBox(height: 1.0),
            // Arabic Name in Blue SECOND (supports 1, 2, or 3 lines)
            ...buildHeaderLines(
              contractorAr,
              isArabic: true,
              color: headerArabicBlue,
              baseFontSize: 6.8,
              isBold: true,
              isLandscape: isLandscape,
            ),
            if (contractorSub.isNotEmpty) ...[
              pw.SizedBox(height: 0.5),
              ...buildHeaderLines(
                contractorSub,
                isArabic: true,
                color: headerArabicBlue,
                baseFontSize: 5.8,
                isBold: true,
                isLandscape: isLandscape,
              ),
            ],
          ],
        ),
      );

      // 2. Middle (or Right when 2 logos): Ministry / Facility Logo + English (Black) then Arabic (Blue)
      final ministryWidget = pw.SizedBox(
        width: logoColWidth,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoFacility != null)
              pw.Image(logoFacility, height: isLandscape ? 31 : 34, width: 85, fit: pw.BoxFit.contain)
            else
              pw.SizedBox(height: isLandscape ? 31 : 34, width: 85),
            pw.SizedBox(height: 1.5),
            // English Name in Black FIRST (supports 1, 2, or 3 lines)
            ...buildHeaderLines(
              ministryEn,
              isArabic: false,
              color: headerEnglishBlack,
              baseFontSize: 5.2,
              isBold: true,
              isLandscape: isLandscape,
            ),
            pw.SizedBox(height: 1.0),
            // Arabic Name in Blue SECOND (supports 1, 2, or 3 lines)
            ...buildHeaderLines(
              ministryAr,
              isArabic: true,
              color: headerArabicBlue,
              baseFontSize: 6.8,
              isBold: true,
              isLandscape: isLandscape,
            ),
          ],
        ),
      );

      // 3. Right: Funder Logo + English (Black) then Arabic (Blue)
      final rightWidget = pw.SizedBox(
        width: logoColWidth,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoUnops != null)
              pw.Image(logoUnops, height: isLandscape ? 26 : 28, width: 95, fit: pw.BoxFit.contain)
            else
              pw.SizedBox(height: isLandscape ? 26 : 28, width: 95),
            pw.SizedBox(height: 1.5),
            // English Name in Black FIRST (supports 1, 2, or 3 lines)
            ...buildHeaderLines(
              rightEn,
              isArabic: false,
              color: headerEnglishBlack,
              baseFontSize: 5.0,
              isBold: true,
              isLandscape: isLandscape,
            ),
            pw.SizedBox(height: 1.0),
            // Arabic Name in Blue SECOND (supports 1, 2, or 3 lines)
            ...buildHeaderLines(
              rightAr,
              isArabic: true,
              color: headerArabicBlue,
              baseFontSize: 6.8,
              isBold: true,
              isLandscape: isLandscape,
            ),
          ],
        ),
      );

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Left: Contractor Logo + Text
              contractorWidget,
              // Center / Right depending on showRight
              if (showRight) ...[
                ministryWidget,
                rightWidget,
              ] else ...[
                // When Right Logo is cancelled, the Ministry logo moves to the right
                ministryWidget,
              ],
            ],
          ),
          pw.SizedBox(height: 1.5),
          pw.Container(height: 1.2, color: goldColor),
          pw.SizedBox(height: 1.5),
          pw.Stack(
            children: [
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Periodic Maintenance Report for Solar Power Systems', style: textStyle(size: isLandscape ? 11 : 10.5, isBold: true)),
                    pw.SizedBox(height: 0.5),
                    pw.Text(_ar('تقرير الصيانة الدورية لمنظومة الطاقة الشمسية'), style: textStyle(size: isLandscape ? 9.5 : 9.0, isBold: true, color: cyanColor)),
                  ],
                ),
              ),
              pw.Positioned(
                left: 0,
                top: 1,
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      effectiveVisitNum.isNotEmpty ? '($effectiveVisitNum)' : '(       )',
                      style: textStyle(size: 7.5, isBold: true),
                    ),
                    pw.SizedBox(width: 3),
                    pw.Text(':', style: textStyle(size: 7.5, isBold: true)),
                    pw.SizedBox(width: 4),
                    pw.Text(_ar('رقم الزيارة'), style: textStyle(size: 7.5, isBold: true)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
        ],
      );
    }

    // Helper: Institutional Running Footer (Bottom of every page)
    pw.Widget buildRunningFooter(int pageNum, {bool hideBeneficiary = false}) {
      final facName = report.facilityInfo.facilityName.trim();
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 2),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Left: Page Pill + Engineer Signature
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: cyanColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Text('Page $pageNum', style: textStyle(size: 8, isBold: true, color: PdfColors.white)),
                    ),
                    pw.SizedBox(width: 8),
                    if (engineerSigImage != null) ...[
                      pw.Text('Engineer Signature: ', style: textStyle(size: 7.5)),
                      pw.Container(
                        height: 28,
                        width: 92,
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(color: cyanColor, width: 0.7),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                        ),
                        child: pw.Center(
                          child: pw.Image(engineerSigImage, fit: pw.BoxFit.contain, alignment: pw.Alignment.center),
                        ),
                      ),
                    ] else ...[
                      pw.Text('Engineer Signature ................................... ', style: textStyle(size: 7.5)),
                    ],
                    pw.Text(':', style: textStyle(size: 7.5, isBold: true)),
                    pw.SizedBox(width: 3),
                    pw.Text(_ar('توقيع مهندس الصيانة'), style: textStyle(size: 7.5, isBold: true)),
                  ],
                ),
                // Right: Beneficiary Approval (hidden on Needs page)
                if (!hideBeneficiary)
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (beneficiarySigImage != null) ...[
                        pw.Text('Beneficiary Approval: ', style: textStyle(size: 7.5)),
                        pw.Container(
                          height: 28,
                          width: 92,
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(color: goldColor, width: 0.7),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                          ),
                          child: pw.Center(
                            child: pw.Image(beneficiarySigImage, fit: pw.BoxFit.contain, alignment: pw.Alignment.center),
                          ),
                        ),
                      ] else ...[
                        pw.Text('Beneficiary Approval ................................... ', style: textStyle(size: 7.5)),
                      ],
                      pw.Text(':', style: textStyle(size: 7.5, isBold: true)),
                      pw.SizedBox(width: 3),
                      pw.Text(_ar('مصادقة المستفيد'), style: textStyle(size: 7.5, isBold: true)),
                    ],
                  )
                else
                  pw.SizedBox(),
              ],
            ),
            pw.SizedBox(height: 2),
            // Center-Right: Facility Name Box
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: cyanColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    if (facName.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 6),
                        child: pw.Text(_ar(facName), style: textStyle(size: 8, isBold: true)),
                      )
                    else
                      pw.Text('Facility Name ..............................................................', style: textStyle(size: 7.5)),
                    pw.SizedBox(width: 4),
                    pw.Text(':', style: textStyle(size: 8, isBold: true)),
                    pw.SizedBox(width: 4),
                    pw.Text(_ar('اسم المرفق الخدمي'), style: textStyle(size: 8, isBold: true)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Helper: Wrap content with the vertical gold stripe
    pw.Widget wrapWithPageFrame({required pw.Widget child, required pw.Context context}) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: 7,
            margin: const pw.EdgeInsets.only(right: 12),
            decoration: pw.BoxDecoration(
              color: goldColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.Expanded(
            child: child,
          ),
        ],
      );
    }

    // Helper: Build section cyan banner matching reference PDF (Right-aligned number and hyphen)
    pw.Widget buildSectionBanner(String number, String title, {double fontSize = 8.5}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.2, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: cyanColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Center(
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(_ar(title), style: textStyle(size: fontSize, isBold: true, color: PdfColors.white)),
              pw.SizedBox(width: 4),
              pw.Text(' - $number', style: textStyle(size: fontSize, isBold: true, color: PdfColors.white)),
            ],
          ),
        ),
      );
    }

    // Helper: Standard 6-Column Inspection Table Widget matching Reference PDF
    pw.Widget buildInspectionTable(InspectionGroup group) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            buildSectionBanner('${group.groupNumber}', group.title, fontSize: 8.5),
            pw.SizedBox(height: 1.5),
            pw.Table(
              border: pw.TableBorder.all(color: borderGrey, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.6), // ملاحظات (leftmost)
                1: pw.FixedColumnWidth(42), // مرفوض
                2: pw.FixedColumnWidth(42), // مقبول
                3: pw.FixedColumnWidth(42), // جيد
                4: pw.FlexColumnWidth(5.2), // الوصف
                5: pw.FixedColumnWidth(24), // م. (rightmost)
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: tableHeaderBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.8), child: pw.Center(child: pw.Text(_ar('ملاحظات'), style: textStyle(size: 8, isBold: true)))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.8), child: pw.Center(child: pw.Text(_ar('مرفوض'), style: textStyle(size: 8, isBold: true)))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.8), child: pw.Center(child: pw.Text(_ar('مقبول'), style: textStyle(size: 8, isBold: true)))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.8), child: pw.Center(child: pw.Text(_ar('جيد'), style: textStyle(size: 8, isBold: true)))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.8, horizontal: 4), child: pw.Center(child: pw.Text(_ar('الوصف'), style: textStyle(size: 8, isBold: true)))),
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1.8), child: pw.Center(child: pw.Text(_ar('م.'), style: textStyle(size: 8, isBold: true)))),
                  ],
                ),
                ...group.items.map((item) {
                  final isGood = item.status == InspectionStatus.good;
                  final isAcceptable = item.status == InspectionStatus.acceptable;
                  final isRejected = item.status == InspectionStatus.rejected || item.status == InspectionStatus.needsFollowup;

                  return pw.TableRow(
                    children: [
                      // ملاحظات (Right-aligned, wraps downwards)
                      pw.Container(
                        alignment: pw.Alignment.centerRight,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
                        child: pw.Text(_arNotes(item.notes, 28), style: textStyle(size: 7.0), textAlign: pw.TextAlign.right),
                      ),
                      // مرفوض
                      pw.Center(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: isRejected ? buildCheckmark(color: PdfColors.red900, size: 7.5) : pw.SizedBox(),
                        ),
                      ),
                      // مقبول
                      pw.Center(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: isAcceptable ? buildCheckmark(color: PdfColors.blue900, size: 7.5) : pw.SizedBox(),
                        ),
                      ),
                      // جيد
                      pw.Center(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: isGood ? buildCheckmark(color: PdfColors.green900, size: 7.5) : pw.SizedBox(),
                        ),
                      ),
                      // الوصف (Strictly aligned to the right!)
                      pw.Container(
                        alignment: pw.Alignment.centerRight,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
                        child: pw.Text(
                          _ar(item.description, 55),
                          style: textStyle(size: 7.2),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      // م.
                      pw.Center(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(1),
                          child: pw.Text('${item.serialNo}', style: textStyle(size: 7.5, isBold: true)),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      );
    }

    int currentPageNumber = 1;

    // ================= PAGE 1: Project & Facility & Solar Specs =================
    if (pagesToExport == null || pagesToExport.contains(1)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(1);
      final pMode = getPageMode(1);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;
      final isWide = isLandscape || isBookMode;
      final specRowH = isWide ? 21.0 : 35.0;
      final specLabelSize = isWide ? 8.0 : 9.5;
      final specValSize = isWide ? 8.5 : 10.0;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 8),
          build: (pw.Context context) {
            final otherRaw = report.systemSpecs.otherAppliances.trim();
            final hasOther = otherRaw.isNotEmpty;
            String otherType = '';
            String otherCap = '';
            String otherCount = '';
            String otherExtra = '';

            if (hasOther) {
              if (otherRaw.contains('مكيف')) {
                otherType = 'مكيف هواء';
                final tonMatch = RegExp(r'(\d+(?:\.\d+)?\s*طن)').firstMatch(otherRaw);
                otherCap = tonMatch?.group(1) ?? '';
                final countMatch = RegExp(r'عدد\s*(\d+)').firstMatch(otherRaw);
                otherCount = countMatch?.group(1) ?? '';
              } else {
                final parts = otherRaw.split(RegExp(r'[,،\n]|\s+عدد\s+'));
                otherType = parts.isNotEmpty ? parts[0].trim() : otherRaw;
                if (parts.length > 1) otherCount = parts[1].trim();
                if (parts.length > 2) otherCap = parts[2].trim();
              }
            }

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isWide),
                  // Warm Sand Project Info Box (NO orange border stroke matching ref PDF)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightBeige,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Column(
                      children: [
                        // Row 1: اسم المشروع
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                _ar(report.projectInfo.projectName),
                                style: textStyle(size: 9.5, isBold: true),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              width: 100,
                              padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 8),
                              decoration: pw.BoxDecoration(
                                color: cyanColor,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.Center(child: pw.Text(_ar('اسم المشروع'), style: textStyle(size: 9.5, isBold: true, color: PdfColors.white))),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 7),
                        // Row 2: رقم العقد
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                report.contractNumber,
                                style: textStyle(size: 9.5, isBold: true),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              width: 100,
                              padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 8),
                              decoration: pw.BoxDecoration(
                                color: cyanColor,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.Center(child: pw.Text(_ar('رقم العقد'), style: textStyle(size: 9.5, isBold: true, color: PdfColors.white))),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 7),
                        // Row 3: المنفّذ
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                _ar(report.projectInfo.funder),
                                style: textStyle(size: 9.5, isBold: true),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              width: 100,
                              padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 8),
                              decoration: pw.BoxDecoration(
                                color: cyanColor,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.Center(child: pw.Text(_ar('المنفّذ'), style: textStyle(size: 9.5, isBold: true, color: PdfColors.white))),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 7),
                        // Row 4: المقاول
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                _ar(contractorAr),
                                style: textStyle(size: 9.5, isBold: true),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              width: 100,
                              padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 8),
                              decoration: pw.BoxDecoration(
                                color: cyanColor,
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.Center(child: pw.Text(_ar('المقاول'), style: textStyle(size: 9.5, isBold: true, color: PdfColors.white))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  // Facility Info Section
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Row 1: بيانات المنشأة
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            _ar('المحافظة : ${report.effectiveGovernorate.isNotEmpty ? report.effectiveGovernorate : "            "} - المديرية : ${report.effectiveDistrict.isNotEmpty ? report.effectiveDistrict : "            "}'),
                            style: textStyle(size: 9.5, isBold: true),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Container(
                            width: 100,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 8),
                            decoration: pw.BoxDecoration(
                              color: cyanColor,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            child: pw.Center(child: pw.Text(_ar('بيانات المنشأة'), style: textStyle(size: 9.5, isBold: true, color: PdfColors.white))),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      // Row 2: اسم المنشأة
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            _ar(report.visitDate.isNotEmpty ? 'تاريخ الزيارة : ${report.visitDate} م' : 'تاريخ الزيارة :      /    / ${DateTime.now().year}  م'),
                            style: textStyle(size: 9, isBold: true),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  if (report.facilityInfo.facilityName.isNotEmpty)
                                    pw.Text(
                                      _ar(report.facilityInfo.facilityName),
                                      style: textStyle(size: 9.5, isBold: true),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  if (report.facilityInfo.facilityNameEn.isNotEmpty)
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(top: 2),
                                      child: pw.Text(
                                        ArabicReshaper.hasArabic(report.facilityInfo.facilityNameEn)
                                            ? _ar(report.facilityInfo.facilityNameEn)
                                            : report.facilityInfo.facilityNameEn,
                                        style: textStyle(size: 8, isBold: true, color: PdfColors.grey800),
                                        textAlign: pw.TextAlign.right,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          pw.Container(
                            width: 100,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 8),
                            decoration: pw.BoxDecoration(
                              color: cyanColor,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            child: pw.Center(child: pw.Text(_ar('اسم المنشأة'), style: textStyle(size: 9.5, isBold: true, color: PdfColors.white))),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      // Row 3: نوع المنشأة ورقم الزيارة
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text(
                                effectiveVisitNum.isNotEmpty ? '($effectiveVisitNum)' : '(           )',
                                style: textStyle(size: 9, isBold: true),
                              ),
                              pw.SizedBox(width: 3),
                              pw.Text(':', style: textStyle(size: 9, isBold: true)),
                              pw.SizedBox(width: 4),
                              pw.Text(_ar('رقم الزيارة'), style: textStyle(size: 9, isBold: true)),
                            ],
                          ),
                          pw.Row(
                            children: [
                              pw.Text(_ar(report.facilityInfo.category), style: textStyle(size: 9.5, isBold: true)),
                              pw.SizedBox(width: 10),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 14),
                                decoration: pw.BoxDecoration(
                                  color: cyanColor,
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                ),
                                child: pw.Center(child: pw.Text(_ar('الفئة'), style: textStyle(size: 9.5, isBold: true, color: PdfColors.white))),
                              ),
                              pw.SizedBox(width: 25),
                              pw.Text(_ar(report.facilityInfo.facilityType), style: textStyle(size: 10, isBold: true)),
                              pw.SizedBox(width: 8),
                              pw.Container(
                                width: 100,
                                padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 8),
                                decoration: pw.BoxDecoration(
                                  color: cyanColor,
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                ),
                                child: pw.Center(child: pw.Text(_ar('نوع المنشأة'), style: textStyle(size: 9.5, isBold: true, color: PdfColors.white))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 22),
                  // Solar System Specs Table matching ref_page_1.png 100%
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: cyanColor, width: 1),
                    ),
                    child: pw.Column(
                      children: [
                        // Top Header: بيانات منظومة الطاقة الشمسية
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8.5),
                          decoration: pw.BoxDecoration(
                            color: cyanColor,
                            borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(7)),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              _ar('بيانات منظومة الطاقة الشمسية'),
                              style: textStyle(size: 11.5, isBold: true, color: PdfColors.white),
                            ),
                          ),
                        ),
                        // 8 Rows with 3 sections (Left: Cream, Middle: Light Cyan, Right: 2 cols with cyan label)
                        pw.Table(
                          border: pw.TableBorder(
                            horizontalInside: pw.BorderSide(color: borderGrey, width: 0.4),
                            verticalInside: pw.BorderSide(color: borderGrey, width: 0.4),
                          ),
                          columnWidths: const {
                            0: pw.FlexColumnWidth(2.2), // Left (مكيف هواء)
                            1: pw.FlexColumnWidth(1.1), // Middle (النوع)
                            2: pw.FlexColumnWidth(1.8), // Right Value
                            3: pw.FlexColumnWidth(1.4), // Right Label (Cyan)
                          },
                          children: [
                            // Row 1: القدرة
                            pw.TableRow(
                              children: [
                                pw.Container(
                                  color: creamBg,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(otherType), style: textStyle(size: specLabelSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: lightCyanBg,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(hasOther ? 'النوع' : ''), style: textStyle(size: specLabelSize, isBold: true))),
                                ),
                                pw.Container(
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(report.systemSpecs.capacityKw), style: textStyle(size: specValSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: cyanColor,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar('القدرة'), style: textStyle(size: specLabelSize, isBold: true, color: PdfColors.white))),
                                ),
                              ],
                            ),
                            // Row 2: عدد الألواح
                            pw.TableRow(
                              children: [
                                pw.Container(
                                  color: creamBg,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(otherCap), style: textStyle(size: specLabelSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: lightCyanBg,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(hasOther ? 'القدرة' : ''), style: textStyle(size: specLabelSize, isBold: true))),
                                ),
                                pw.Container(
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(report.systemSpecs.panelsCountAndWatt), style: textStyle(size: specValSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: cyanColor,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar('عدد الألواح × القدرة'), style: textStyle(size: specLabelSize, isBold: true, color: PdfColors.white))),
                                ),
                              ],
                            ),
                            // Row 3: سعة وحدة تخزين الطاقة
                            pw.TableRow(
                              children: [
                                pw.Container(
                                  color: creamBg,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(otherCount), style: textStyle(size: specLabelSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: lightCyanBg,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(hasOther ? 'العدد' : ''), style: textStyle(size: specLabelSize, isBold: true))),
                                ),
                                pw.Container(
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(report.systemSpecs.batteryUnitsCapacity), style: textStyle(size: specValSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: cyanColor,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar('سعة وحدة تخزين الطاقة'), style: textStyle(size: specLabelSize, isBold: true, color: PdfColors.white))),
                                ),
                              ],
                            ),
                            // Row 4: عدد وحدات تخزين الطاقة
                            pw.TableRow(
                              children: [
                                pw.Container(
                                  color: creamBg,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(otherExtra), style: textStyle(size: specLabelSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: lightCyanBg,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(hasOther ? 'أخرى' : ''), style: textStyle(size: specLabelSize, isBold: true))),
                                ),
                                pw.Container(
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(report.systemSpecs.batteryUnitsCount), style: textStyle(size: specValSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: cyanColor,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar('عدد وحدات تخزين الطاقة'), style: textStyle(size: specLabelSize, isBold: true, color: PdfColors.white))),
                                ),
                              ],
                            ),
                            // Row 5: قدرة العاكس
                            pw.TableRow(
                              children: [
                                pw.Container(color: creamBg, height: specRowH),
                                pw.Container(color: lightCyanBg, height: specRowH),
                                pw.Container(
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(report.systemSpecs.invertersCapacity), style: textStyle(size: specValSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: cyanColor,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar('قدرة العاكس'), style: textStyle(size: specLabelSize, isBold: true, color: PdfColors.white))),
                                ),
                              ],
                            ),
                            // Row 6: عدد العواكس
                            pw.TableRow(
                              children: [
                                pw.Container(color: creamBg, height: specRowH),
                                pw.Container(color: lightCyanBg, height: specRowH),
                                pw.Container(
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(report.systemSpecs.invertersCount), style: textStyle(size: specValSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: cyanColor,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar('عدد العواكس'), style: textStyle(size: specLabelSize, isBold: true, color: PdfColors.white))),
                                ),
                              ],
                            ),
                            // Row 7: قدرة منظم الشحن
                            pw.TableRow(
                              children: [
                                pw.Container(color: creamBg, height: specRowH),
                                pw.Container(color: lightCyanBg, height: specRowH),
                                pw.Container(
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(report.systemSpecs.chargeControllersCapacity), style: textStyle(size: specValSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: cyanColor,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar('قدرة منظم الشحن'), style: textStyle(size: specLabelSize, isBold: true, color: PdfColors.white))),
                                ),
                              ],
                            ),
                            // Row 8: عدد منظمات الشحن
                            pw.TableRow(
                              children: [
                                pw.Container(color: creamBg, height: specRowH),
                                pw.Container(color: lightCyanBg, height: specRowH),
                                pw.Container(
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar(report.systemSpecs.chargeControllersCount), style: textStyle(size: specValSize, isBold: true))),
                                ),
                                pw.Container(
                                  color: cyanColor,
                                  height: specRowH,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                  child: pw.Center(child: pw.Text(_ar('عدد منظمات الشحن'), style: textStyle(size: specLabelSize, isBold: true, color: PdfColors.white))),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(
                child: pageContent,
                rotW: rotW,
                rotH: rotH,
                padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 8),
              );
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= PAGE 2: Inspection Groups 1, 2, 3 =================
    if (pagesToExport == null || pagesToExport.contains(2)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(2);
      final pMode = getPageMode(2);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;
      final isWide = isLandscape || isBookMode;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
          build: (pw.Context context) {
            InspectionGroup? g1;
            InspectionGroup? g2;
            InspectionGroup? g3;
            try {
              g1 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 1 || g.title.contains('الألواح'));
            } catch (_) {
              if (report.inspectionGroups.isNotEmpty) g1 = report.inspectionGroups[0];
            }
            try {
              g2 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 2 || g.title.contains('الكابل تري'));
            } catch (_) {
              if (report.inspectionGroups.length > 1) g2 = report.inspectionGroups[1];
            }
            try {
              g3 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 3 || g.title.contains('تجميع كابلات'));
            } catch (_) {
              if (report.inspectionGroups.length > 2) g3 = report.inspectionGroups[2];
            }

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isWide),
                  if (g1 != null) buildInspectionTable(g1),
                  if (g2 != null) buildInspectionTable(g2),
                  if (g3 != null) buildInspectionTable(g3),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(
                child: pageContent,
                rotW: rotW,
                rotH: rotH,
                padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
              );
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= PAGE 3: Inspection Group 4 (Single Master Table matching ref_page_3.png) =================
    if (pagesToExport == null || pagesToExport.contains(3)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(3);
      final pMode = getPageMode(3);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;
      final isWide = isLandscape || isBookMode;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 6, bottom: 6),
          build: (pw.Context context) {
            InspectionGroup? g4;
            try {
              g4 = report.inspectionGroups.firstWhere(
                (g) => g.groupNumber == 4 || g.title.contains('قواطع') || g.title.contains('التيار المستمر'),
              );
            } catch (_) {
              if (report.inspectionGroups.length > 3) {
                g4 = report.inspectionGroups[3];
              } else if (DefaultTemplates.defaultInspectionGroups.length > 3) {
                g4 = DefaultTemplates.defaultInspectionGroups[3];
              }
            }
            if (g4 == null || g4.items.isEmpty) {
              g4 = DefaultTemplates.defaultInspectionGroups[3];
            }

            final subcategoryTitles = [
              'صندوق قواطع البطاريات "تيار مستمر"',
              'صندوق قواطع العاكس "تيار مستمر"',
              'صندوق تجميع كابلات التيار المستمر',
              'صندوق دمج وقواطع حماية التيار المتردد',
              'لوحة التوزيع الرئيسية',
              'مفتاح تبديل يدوي لمصدر الطاقة',
            ];

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isWide),
                  // Cyan Header
                  buildSectionBanner('4', 'نموذج فحص لوحات قواطع التيار المستمر و المتردد و البزبارات ومفتاح التبديل لمصادر الطاقة', fontSize: 7.5),
                  pw.SizedBox(height: 1),
                  // Master Table wrapped in FittedBox for perfect auto-scaling in both portrait and book mode
                  pw.Expanded(
                    child: pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.topCenter,
                      child: pw.Container(
                        width: (isWide ? rotW : pFormat.width) - 47.0,
                        child: pw.Table(
                    border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(2.6), // ملاحظات
                      1: pw.FixedColumnWidth(42), // مرفوض
                      2: pw.FixedColumnWidth(42), // مقبول
                      3: pw.FixedColumnWidth(42), // جيد
                      4: pw.FlexColumnWidth(5.2), // الوصف
                      5: pw.FixedColumnWidth(22), // م.
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: tableHeaderBg),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 0.8), child: pw.Center(child: pw.Text(_ar('ملاحظات'), style: textStyle(size: 6.8, isBold: true)))),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 0.8), child: pw.Center(child: pw.Text(_ar('مرفوض'), style: textStyle(size: 6.8, isBold: true)))),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 0.8), child: pw.Center(child: pw.Text(_ar('مقبول'), style: textStyle(size: 6.8, isBold: true)))),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 0.8), child: pw.Center(child: pw.Text(_ar('جيد'), style: textStyle(size: 6.8, isBold: true)))),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 0.8), child: pw.Center(child: pw.Text(_ar('الوصف'), style: textStyle(size: 6.8, isBold: true)))),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 0.8), child: pw.Center(child: pw.Text(_ar('م.'), style: textStyle(size: 6.8, isBold: true)))),
                        ],
                      ),
                      // 6 Subcategories x 7 items = 42 items
                      ...List.generate(6, (subIdx) {
                        final subTitle = subcategoryTitles[subIdx];
                        var itemsForSub = g4!.items.where((it) => it.subcategory != null && (it.subcategory == subTitle || it.subcategory!.contains(subTitle) || subTitle.contains(it.subcategory!))).toList();
                        if (itemsForSub.isEmpty && g4.items.length >= (subIdx + 1) * 7) {
                          itemsForSub = g4.items.sublist(subIdx * 7, (subIdx + 1) * 7);
                        } else if (itemsForSub.isEmpty) {
                          final defaultG4 = DefaultTemplates.defaultInspectionGroups[3];
                          itemsForSub = defaultG4.items.where((it) => it.subcategory == subTitle).toList();
                          if (itemsForSub.isEmpty && defaultG4.items.length >= (subIdx + 1) * 7) {
                            itemsForSub = defaultG4.items.sublist(subIdx * 7, (subIdx + 1) * 7);
                          }
                        }

                        return [
                          // Shaded Subheader Row
                          pw.TableRow(
                            decoration: pw.BoxDecoration(color: tableHeaderBg),
                            children: [
                              pw.SizedBox(),
                              pw.SizedBox(),
                              pw.SizedBox(),
                              pw.SizedBox(),
                              pw.Container(
                                alignment: pw.Alignment.centerRight,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                child: pw.Text(_ar(subTitle), style: textStyle(size: 6.8, isBold: true), textAlign: pw.TextAlign.right),
                              ),
                              pw.Center(
                                child: pw.Padding(
                                  padding: const pw.EdgeInsets.all(0.5),
                                  child: pw.Text('${subIdx + 1}', style: textStyle(size: 6.8, isBold: true)),
                                ),
                              ),
                            ],
                          ),
                          // 7 Items under this subcategory
                          ...itemsForSub.map((item) {
                            return pw.TableRow(
                              children: [
                                pw.Container(
                                  alignment: pw.Alignment.centerRight,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.25),
                                  child: pw.Text(_arNotes(item.notes, 28), style: textStyle(size: 6.2), textAlign: pw.TextAlign.right),
                                ),
                                pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.2), child: item.status == InspectionStatus.rejected ? buildCheckmark(color: PdfColors.red900, size: 6.5) : pw.SizedBox())),
                                pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.2), child: item.status == InspectionStatus.acceptable ? buildCheckmark(color: PdfColors.blue900, size: 6.5) : pw.SizedBox())),
                                pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.2), child: item.status == InspectionStatus.good ? buildCheckmark(color: PdfColors.green900, size: 6.5) : pw.SizedBox())),
                                pw.Container(
                                  alignment: pw.Alignment.centerRight,
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.25),
                                  child: pw.Text(_ar(item.description, 55), style: textStyle(size: 6.5), textAlign: pw.TextAlign.right),
                                ),
                                pw.SizedBox(),
                              ],
                            );
                          }),
                        ];
                      }).expand((rows) => rows),
                    ],
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            buildRunningFooter(pNum),
          ],
        ),
      );

      if (isBookMode) {
        return wrapWithBookModeRotation(
          child: pageContent,
          rotW: rotW,
          rotH: rotH,
          padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 6, bottom: 6),
        );
      }

      return pageContent;
    },
  ),
);
}

    // ================= PAGE 4: Inspection Groups 5, 6, 7 =================
    if (pagesToExport == null || pagesToExport.contains(4)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(4);
      final pMode = getPageMode(4);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;
      final isWide = isLandscape || isBookMode;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
          build: (pw.Context context) {
            InspectionGroup? g5;
            InspectionGroup? g6;
            InspectionGroup? g7;
            try {
              g5 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 5 || g.title.contains('منظمات'));
            } catch (_) {
              if (report.inspectionGroups.length > 4) g5 = report.inspectionGroups[4];
            }
            try {
              g6 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 6 || g.title.contains('عواكس'));
            } catch (_) {
              if (report.inspectionGroups.length > 5) g6 = report.inspectionGroups[5];
            }
            try {
              g7 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 7 || g.title.contains('التهوية'));
            } catch (_) {
              if (report.inspectionGroups.length > 6) g7 = report.inspectionGroups[6];
            }

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isWide),
                  if (g5 != null) buildInspectionTable(g5),
                  if (g6 != null) buildInspectionTable(g6),
                  // Model 7 Master Table with 3 Subcategories
                  if (g7 != null) ...[
                    buildSectionBanner('7', 'نموذج فحص نظام التهوية – و نظام الانذار و الحماية ونظام المراقبة و المتابعة', fontSize: 8.0),
                    pw.SizedBox(height: 1.5),
                    pw.Table(
                      border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(2.6),
                        1: pw.FixedColumnWidth(42),
                        2: pw.FixedColumnWidth(42),
                        3: pw.FixedColumnWidth(42),
                        4: pw.FlexColumnWidth(5.2),
                        5: pw.FixedColumnWidth(22),
                      },
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Center(child: pw.Text(_ar('ملاحظات'), style: textStyle(size: 7.5, isBold: true)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Center(child: pw.Text(_ar('مرفوض'), style: textStyle(size: 7.5, isBold: true)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Center(child: pw.Text(_ar('مقبول'), style: textStyle(size: 7.5, isBold: true)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Center(child: pw.Text(_ar('جيد'), style: textStyle(size: 7.5, isBold: true)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Center(child: pw.Text(_ar('الوصف'), style: textStyle(size: 7.5, isBold: true)))),
                            pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Center(child: pw.Text(_ar('م.'), style: textStyle(size: 7.5, isBold: true)))),
                          ],
                        ),
                        // Subcategory 1: نظام التهوية (3 items)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: [
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
                              child: pw.Text(_ar('نظام التهوية'), style: textStyle(size: 7.2, isBold: true), textAlign: pw.TextAlign.right),
                            ),
                            pw.Center(child: pw.Text('1', style: textStyle(size: 7.2, isBold: true))),
                          ],
                        ),
                        ...g7.items.take(3).map((item) => pw.TableRow(
                          children: [
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
                              child: pw.Text(_arNotes(item.notes, 28), style: textStyle(size: 7.0), textAlign: pw.TextAlign.right),
                            ),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.rejected ? buildCheckmark(color: PdfColors.red900, size: 7.0) : pw.SizedBox())),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.acceptable ? buildCheckmark(color: PdfColors.blue900, size: 7.0) : pw.SizedBox())),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.good ? buildCheckmark(color: PdfColors.green900, size: 7.0) : pw.SizedBox())),
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
                              child: pw.Text(_ar(item.description, 55), style: textStyle(size: 7.0), textAlign: pw.TextAlign.right),
                            ),
                            pw.SizedBox(),
                          ],
                        )),
                        // Subcategory 2: نظام إنذار ومكافحة الحرائق (4 items)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: [
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
                              child: pw.Text(_ar('نظام إنذار ومكافحة الحرائق'), style: textStyle(size: 7.2, isBold: true), textAlign: pw.TextAlign.right),
                            ),
                            pw.Center(child: pw.Text('2', style: textStyle(size: 7.2, isBold: true))),
                          ],
                        ),
                        ...g7.items.skip(3).take(4).map((item) => pw.TableRow(
                          children: [
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
                              child: pw.Text(_arNotes(item.notes, 28), style: textStyle(size: 7.0), textAlign: pw.TextAlign.right),
                            ),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.rejected ? buildCheckmark(color: PdfColors.red900, size: 7.0) : pw.SizedBox())),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.acceptable ? buildCheckmark(color: PdfColors.blue900, size: 7.0) : pw.SizedBox())),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.good ? buildCheckmark(color: PdfColors.green900, size: 7.0) : pw.SizedBox())),
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
                              child: pw.Text(_ar(item.description, 55), style: textStyle(size: 7.0), textAlign: pw.TextAlign.right),
                            ),
                            pw.SizedBox(),
                          ],
                        )),
                        // Subcategory 3: نظام المراقبة والمتابعة (6 items)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: [
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.SizedBox(),
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
                              child: pw.Text(_ar('نظام المراقبة والمتابعة'), style: textStyle(size: 7.2, isBold: true), textAlign: pw.TextAlign.right),
                            ),
                            pw.Center(child: pw.Text('3', style: textStyle(size: 7.2, isBold: true))),
                          ],
                        ),
                        ...g7.items.skip(7).take(6).map((item) => pw.TableRow(
                          children: [
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
                              child: pw.Text(_arNotes(item.notes, 28), style: textStyle(size: 7.0), textAlign: pw.TextAlign.right),
                            ),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.rejected ? buildCheckmark(color: PdfColors.red900, size: 7.0) : pw.SizedBox())),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.acceptable ? buildCheckmark(color: PdfColors.blue900, size: 7.0) : pw.SizedBox())),
                            pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(0.5), child: item.status == InspectionStatus.good ? buildCheckmark(color: PdfColors.green900, size: 7.0) : pw.SizedBox())),
                            pw.Container(
                              alignment: pw.Alignment.centerRight,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 0.8),
                              child: pw.Text(_ar(item.description, 55), style: textStyle(size: 7.0), textAlign: pw.TextAlign.right),
                            ),
                            pw.SizedBox(),
                          ],
                        )),
                      ],
                    ),
                  ],
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(
                child: pageContent,
                rotW: rotW,
                rotH: rotH,
                padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
              );
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= PAGE 5: Inspection Groups 8, 9, 10 =================
    if (pagesToExport == null || pagesToExport.contains(5)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(5);
      final pMode = getPageMode(5);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;
      final isWide = isLandscape || isBookMode;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
          build: (pw.Context context) {
            InspectionGroup? g8;
            InspectionGroup? g9;
            InspectionGroup? g10;
            try {
              g8 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 8 || g.title.contains('كابلات') || g.title.contains('توصيلات'));
            } catch (_) {
              if (report.inspectionGroups.length > 7) g8 = report.inspectionGroups[7];
            }
            try {
              g9 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 9 || g.title.contains('تأريض'));
            } catch (_) {
              if (report.inspectionGroups.length > 8) g9 = report.inspectionGroups[8];
            }
            try {
              g10 = report.inspectionGroups.firstWhere((g) => g.groupNumber == 10 || g.title.contains('سلامة') || g.title.contains('بيئة'));
            } catch (_) {
              if (report.inspectionGroups.length > 9) g10 = report.inspectionGroups[9];
            }

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isWide),
                  if (g8 != null) buildInspectionTable(g8),
                  if (g9 != null) buildInspectionTable(g9),
                  if (g10 != null) buildInspectionTable(g10),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(
                child: pageContent,
                rotW: rotW,
                rotH: rotH,
                padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 8),
              );
            }

            return pageContent;
          },
        ),
      );
    }

    // Helper: 1-Group Battery Matrix Table (Spacious, large font, 24 rows for single active group)
    pw.Widget buildSingleGroupBatteryTable({
      required List<BatteryMeasurement> group,
      required String groupName,
      required String title,
    }) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: cyanColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Center(
              child: pw.Text(
                _ar('$title - $groupName'),
                style: textStyle(size: 9.5, isBold: true, color: PdfColors.white),
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(137), // الملاحظات — مقلص ومنضبط
              1: pw.FixedColumnWidth(230), // عزم براغي الربط — واسع ومريح
              2: pw.FixedColumnWidth(160), // الجهد — واسع وواضح
              3: pw.FixedColumnWidth(40),  // م
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: tableHeaderBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Center(child: pw.Text(_ar('الملاحظات'), style: textStyle(size: 8.5, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Center(child: pw.Text(_ar('عزم براغي الربط'), style: textStyle(size: 8.5, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Center(child: pw.Text(_ar('الجهد'), style: textStyle(size: 8.5, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Center(child: pw.Text(_ar('م'), style: textStyle(size: 8.5, isBold: true)))),
                ],
              ),
              ...List.generate(24, (i) {
                final cell = i < group.length ? group[i] : null;
                final notes = cell?.notes ?? '';
                final isAr = ArabicReshaper.hasArabic(notes);
                final torque = (cell != null && cell.boltTorque > 0) ? cell.boltTorque.toString() : '';
                final v = (cell != null && cell.voltage > 0) ? cell.voltage.toStringAsFixed(2) : '';

                return pw.TableRow(
                  children: [
                    notes.isEmpty
                        ? pw.SizedBox()
                        : pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            child: pw.Text(
                              isAr ? _arNotes(notes, 18) : notes,
                              style: textStyle(size: 7.5, isBold: true),
                              textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
                            ),
                          ),
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text(torque, style: textStyle(size: 7.8, isBold: true)))),
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text(v, style: textStyle(size: 8.2, isBold: true)))),
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text('${i + 1}', style: textStyle(size: 7.8, isBold: true)))),
                  ],
                );
              }),
            ],
          ),
        ],
      );
    }

    // Helper: 2-Group Battery Matrix Table (24 rows per page matching ref_page_6 & 7)
    pw.Widget buildDualGroupBatteryTable({
      required List<BatteryMeasurement> groupA,
      required List<BatteryMeasurement> groupB,
      required String groupAName,
      required String groupBName,
      required String title,
    }) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 10),
            decoration: pw.BoxDecoration(
              color: cyanColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Center(
              child: pw.Text(
                _ar(title),
                style: textStyle(size: 9.5, isBold: true, color: PdfColors.white),
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(85),  // الملاحظات — مقلص ومتناسق (85 pt)
              1: pw.FixedColumnWidth(128), // عزم براغي الربط (B) — كبير ومريح
              2: pw.FixedColumnWidth(85),  // الجهد (B) — واضح وكبير
              3: pw.FixedColumnWidth(28),  // م (B)
              4: pw.FixedColumnWidth(128), // عزم براغي الربط (A) — كبير ومريح
              5: pw.FixedColumnWidth(85),  // الجهد (A) — واضح وكبير
              6: pw.FixedColumnWidth(28),  // م (A)
            },
            children: [
              // Top Group Header Row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: tableHeaderBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Center(child: pw.Text(_ar('الملاحظات'), style: textStyle(size: 8, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Center(child: pw.Text(_ar(groupBName), style: textStyle(size: 8, isBold: true)))),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Center(child: pw.Text(_ar(groupAName), style: textStyle(size: 8, isBold: true)))),
                  pw.SizedBox(),
                  pw.SizedBox(),
                ],
              ),
              // Sub Header Row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: tableHeaderBg),
                children: [
                  pw.SizedBox(),
                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(_ar('عزم براغي الربط'), style: textStyle(size: 7.5, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(_ar('الجهد'), style: textStyle(size: 7.5, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(_ar('م'), style: textStyle(size: 7.5, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(_ar('عزم براغي الربط'), style: textStyle(size: 7.5, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(_ar('الجهد'), style: textStyle(size: 7.5, isBold: true)))),
                  pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(_ar('م'), style: textStyle(size: 7.5, isBold: true)))),
                ],
              ),
              // 24 Rows
              ...List.generate(24, (i) {
                final cellA = i < groupA.length ? groupA[i] : null;
                final cellB = i < groupB.length ? groupB[i] : null;

                final noteA = cellA?.notes ?? '';
                final noteB = cellB?.notes ?? '';
                final notes = noteA.isNotEmpty ? noteA : noteB;
                final isAr = ArabicReshaper.hasArabic(notes);

                final torqueB = (cellB != null && cellB.boltTorque > 0) ? cellB.boltTorque.toString() : '';
                final vB = (cellB != null && cellB.voltage > 0) ? cellB.voltage.toStringAsFixed(2) : '';

                final torqueA = (cellA != null && cellA.boltTorque > 0) ? cellA.boltTorque.toString() : '';
                final vA = (cellA != null && cellA.voltage > 0) ? cellA.voltage.toStringAsFixed(2) : '';

                return pw.TableRow(
                  children: [
                    // الملاحظات — محاذاة لليمين للعربي ولليسار للإنجليزي
                    notes.isEmpty
                        ? pw.SizedBox()
                        : pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                            child: pw.Text(
                              isAr ? _arNotes(notes, 12) : notes,
                              style: textStyle(size: 7.2, isBold: true),
                              textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
                            ),
                          ),
                    // Group B
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text(torqueB, style: textStyle(size: 7.2, isBold: true)))),
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text(vB, style: textStyle(size: 7.8, isBold: true)))),
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text('${i + 1}', style: textStyle(size: 7.2, isBold: true)))),
                    // Group A
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text(torqueA, style: textStyle(size: 7.2, isBold: true)))),
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text(vA, style: textStyle(size: 7.8, isBold: true)))),
                    pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.all(1.5), child: pw.Text('${i + 1}', style: textStyle(size: 7.2, isBold: true)))),
                  ],
                );
              }),
            ],
          ),
        ],
      );
    }

    List<BatteryMeasurement> getBatteryGroupCells(int groupNum) {
      final start = (groupNum - 1) * 24;
      if (report.batteryMeasurements.length >= start + 24) {
        return report.batteryMeasurements.sublist(start, start + 24);
      } else if (report.batteryMeasurements.length > start) {
        return report.batteryMeasurements.skip(start).toList();
      }
      return List.generate(24, (i) => BatteryMeasurement(cellNumber: start + i + 1, voltage: 0, boltTorque: 0));
    }

    final activeBatGroups = report.activeBatteryGroups.isNotEmpty
        ? report.activeBatteryGroups
        : [1, 2, 3, 4];

    // ================= BATTERY PAGE 1: First 1 or 2 active groups =================
    if ((pagesToExport == null || pagesToExport.contains(6)) && activeBatGroups.isNotEmpty) {
      final pNum = currentPageNumber++;
      final gaNum = activeBatGroups[0];
      final gbNum = activeBatGroups.length > 1 ? activeBatGroups[1] : null;
      final pFormat = resolvePageFormat(6);
      final pMode = getPageMode(6);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
          build: (pw.Context context) {
            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isLandscape || isBookMode),
                  if (gbNum != null)
                    buildDualGroupBatteryTable(
                      groupA: getBatteryGroupCells(gaNum),
                      groupB: getBatteryGroupCells(gbNum),
                      groupAName: 'المجموعة$gaNum',
                      groupBName: 'المجموعة$gbNum',
                      title: '10 - نموذج قياسات مصفوفة تخزين الطاقة (البطاريات)',
                    )
                  else
                    buildSingleGroupBatteryTable(
                      group: getBatteryGroupCells(gaNum),
                      groupName: 'المجموعة$gaNum',
                      title: '10 - نموذج قياسات مصفوفة تخزين الطاقة (البطاريات)',
                    ),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(child: pageContent, rotW: rotW, rotH: rotH);
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= BATTERY PAGE 2: Groups 3 and 4 (Only if more than 2 groups are active!) =================
    if ((pagesToExport == null || pagesToExport.contains(7)) && activeBatGroups.length > 2) {
      final pNum = currentPageNumber++;
      final gaNum = activeBatGroups[2];
      final gbNum = activeBatGroups.length > 3 ? activeBatGroups[3] : null;
      final pFormat = resolvePageFormat(7);
      final pMode = getPageMode(7);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
          build: (pw.Context context) {
            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isLandscape || isBookMode),
                  if (gbNum != null)
                    buildDualGroupBatteryTable(
                      groupA: getBatteryGroupCells(gaNum),
                      groupB: getBatteryGroupCells(gbNum),
                      groupAName: 'المجموعة$gaNum',
                      groupBName: 'المجموعة$gbNum',
                      title: 'تابع نموذج قياسات مصفوفة تخزين الطاقة (البطاريات)',
                    )
                  else
                    buildSingleGroupBatteryTable(
                      group: getBatteryGroupCells(gaNum),
                      groupName: 'المجموعة$gaNum',
                      title: 'تابع نموذج قياسات مصفوفة تخزين الطاقة (البطاريات)',
                    ),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(child: pageContent, rotW: rotW, rotH: rotH);
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= PAGE 8: Operational Data =================
    if (pagesToExport == null || pagesToExport.contains(8)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(8);
      final pMode = getPageMode(8);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final isPortrait = !isLandscape && !isBookMode;
      final rotW = pFormat.height;
      final rotH = pFormat.width;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: (isLandscape && !isBookMode) || isPortrait
              ? const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10)
              : pw.EdgeInsets.zero,
          build: (pw.Context context) {
            final invCount = int.tryParse(report.systemSpecs.invertersCount.trim()) ?? 0;
            final parsedCcCount = int.tryParse(report.systemSpecs.chargeControllersCount.trim()) ?? 0;
            final ccCount = parsedCcCount > 0 ? parsedCcCount : (report.activeCombinerBoxes.isNotEmpty ? report.activeCombinerBoxes.length : 0);

            String getOpVal(List<String> keys) {
              for (final k in keys) {
                final found = report.operationalData.firstWhere(
                  (op) => op.id.toLowerCase() == k.toLowerCase() || op.parameter.contains(k),
                  orElse: () => const OperationalData(id: '', parameter: '', unit: '', measuredValue: '', standardRange: ''),
                );
                if (found.measuredValue.trim().isNotEmpty) {
                  return found.measuredValue.trim();
                }
              }
              return '';
            }

            final invLoadVal = getOpVal(['op_load', 'الحمل على الإنفرتر', 'الحمل']);
            final invAcVal = getOpVal(['op_ac_v', 'فرق جهد الخرج (متردد)', 'فرق جهد الخرج']);
            final invDcVal = getOpVal(['op_dc_v', 'فرق جهد الدخول (مستمر)', 'فرق جهد الدخول']);

            final ccCurrentVal = getOpVal(['op_cc_i', 'التيار المنتج بمصفوفة الألواح', 'التيار المنتج']);
            final ccVoltageVal = getOpVal(['op_cc_v', 'فرق جهد مصفوفة الألواح']);

            // Monitoring screen status check from inspection
            final monitorScreenGood = report.inspectionGroups.any((g) =>
                g.items.any((item) => item.description.contains('المراقبة') && item.status == InspectionStatus.good));

            final effectivePageW = isBookMode ? rotW : pFormat.width;
            final effectivePageH = isBookMode ? rotH : pFormat.height;
            final availableTableWidth = effectivePageW - 28.0 - 19.0;

            // Dynamic columns calculation: if small site (<= 6 units) or portrait, provide spacious columns!
            final maxUnits = [invCount, ccCount, 1].reduce((a, b) => a > b ? a : b);
            final totalCols = isPortrait
                ? (maxUnits <= 6 ? (maxUnits < 2 ? 2 : maxUnits) : 6)
                : (maxUnits <= 6 ? (maxUnits < 3 ? 3 : maxUnits) : 13);
            final labelColWidth = availableTableWidth > 950 ? 250.0 : (isPortrait ? (availableTableWidth < 500 ? 160.0 : 185.0) : 200.0);
            final unitColWidth = (availableTableWidth - labelColWidth) / totalCols;
            final unitFontSize = availableTableWidth > 950 ? 9.5 : (isPortrait ? (totalCols <= 3 ? 9.5 : 8.0) : (totalCols <= 6 ? 9.0 : 8.0));
            final labelFontSize = availableTableWidth > 950 ? 9.5 : (isPortrait ? 8.5 : 8.2);
            final cellVPadding = isPortrait ? 7.5 : (isLandscape ? (effectivePageH > 650 ? 8.5 : 6.5) : 5.0);
            final cellPad = pw.EdgeInsets.symmetric(vertical: cellVPadding, horizontal: 3.5);

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: !isPortrait),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 10),
                    decoration: pw.BoxDecoration(
                      color: cyanColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        _ar('11 - نموذج بيانات التشغيل لمنظومة الطاقة الشمسية'),
                        style: textStyle(size: 10, isBold: true, color: PdfColors.white),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: isLandscape ? 6 : 4),
                  pw.Container(
                    width: availableTableWidth,
                    child: pw.Table(
                      border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                      columnWidths: {
                        ...Map.fromEntries(List.generate(totalCols, (i) => MapEntry(i, pw.FixedColumnWidth(unitColWidth)))),
                        totalCols: pw.FixedColumnWidth(labelColWidth), // Label (rightmost)
                      },
                      children: [
                        // Section 1: الانفرترات
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: [
                            ...List.generate(totalCols, (i) => pw.Center(child: pw.Padding(padding: cellPad, child: pw.Text('${totalCols - i}', style: textStyle(size: unitFontSize, isBold: true))))),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('الانفرترات : رقم الانفرتر'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            ...List.generate(totalCols, (i) {
                              final u = totalCols - i;
                              final uLoad = getOpVal(['op_load_$u', 'inv_load_$u']);
                              final displayVal = (u <= invCount && invCount > 0) ? (uLoad.isNotEmpty ? uLoad : (u == 1 ? invLoadVal : '')) : '';
                              return pw.Center(child: pw.Padding(padding: cellPad, child: pw.Text((u <= invCount && invCount > 0) ? _ar(displayVal) : '', style: textStyle(size: unitFontSize, isBold: true))));
                            }),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('الحمل على الإنفرتر (وات)'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            ...List.generate(totalCols, (i) {
                              final u = totalCols - i;
                              final uAc = getOpVal(['op_ac_v_$u', 'inv_ac_$u']);
                              final displayVal = (u <= invCount && invCount > 0) ? (uAc.isNotEmpty ? uAc : (u == 1 ? invAcVal : '')) : '';
                              return pw.Center(child: pw.Padding(padding: cellPad, child: pw.Text((u <= invCount && invCount > 0) ? _ar(displayVal) : '', style: textStyle(size: unitFontSize, isBold: true))));
                            }),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('فرق جهد الخرج (متردد) بالفولت'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            ...List.generate(totalCols, (i) {
                              final u = totalCols - i;
                              final uDc = getOpVal(['op_dc_v_$u', 'inv_dc_$u']);
                              final displayVal = (u <= invCount && invCount > 0) ? (uDc.isNotEmpty ? uDc : (u == 1 ? invDcVal : '')) : '';
                              return pw.Center(child: pw.Padding(padding: cellPad, child: pw.Text((u <= invCount && invCount > 0) ? _ar(displayVal) : '', style: textStyle(size: unitFontSize, isBold: true))));
                            }),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('فرق جهد الدخول (مستمر) بالفولت'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        // Section 2: منظمات الشحن
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: tableHeaderBg),
                          children: [
                            ...List.generate(totalCols, (i) => pw.Center(child: pw.Padding(padding: cellPad, child: pw.Text('${totalCols - i}', style: textStyle(size: unitFontSize, isBold: true))))),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('منظمات الشحن : رقم منظم الشحن'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            ...List.generate(totalCols, (i) {
                              final u = totalCols - i;
                              final uCcI = getOpVal(['op_cc_i_$u', 'cc_i_$u']);
                              final displayVal = (u <= ccCount && ccCount > 0) ? (uCcI.isNotEmpty ? uCcI : (u == 1 ? ccCurrentVal : '')) : '';
                              return pw.Center(child: pw.Padding(padding: cellPad, child: pw.Text((u <= ccCount && ccCount > 0) ? _ar(displayVal) : '', style: textStyle(size: unitFontSize, isBold: true))));
                            }),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('التيار المنتج بمصفوفة الألواح (أمبير)'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            ...List.generate(totalCols, (i) {
                              final u = totalCols - i;
                              final uCcV = getOpVal(['op_cc_v_$u', 'cc_v_$u']);
                              final displayVal = (u <= ccCount && ccCount > 0) ? (uCcV.isNotEmpty ? uCcV : (u == 1 ? ccVoltageVal : '')) : '';
                              return pw.Center(child: pw.Padding(padding: cellPad, child: pw.Text((u <= ccCount && ccCount > 0) ? _ar(displayVal) : '', style: textStyle(size: unitFontSize, isBold: true))));
                            }),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('فرق جهد مصفوفة الألواح (فولت)'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        // Section 3: شاشة المراقبة
                        pw.TableRow(
                          children: [
                            ...List.generate(totalCols, (i) {
                              final u = totalCols - i;
                              final uCcMon = getOpVal(['op_cc_mon_$u', 'cc_mon_$u']);
                              final isCcMon = (u <= ccCount && ccCount > 0) &&
                                  (uCcMon.isEmpty ? monitorScreenGood : (uCcMon == 'true' || uCcMon == '1' || uCcMon == 'نعم'));
                              return pw.Center(child: pw.Padding(padding: cellPad, child: isCcMon ? buildCheckmark(color: PdfColors.green900, size: 9) : pw.SizedBox()));
                            }),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('شاشة المراقبة : كل منظمات الشحن متصلة بشاشة المراقبة'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            ...List.generate(totalCols, (i) {
                              final u = totalCols - i;
                              final uInvMon = getOpVal(['op_inv_mon_$u', 'inv_mon_$u']);
                              final isInvMon = (u <= invCount && invCount > 0) &&
                                  (uInvMon.isEmpty ? monitorScreenGood : (uInvMon == 'true' || uInvMon == '1' || uInvMon == 'نعم'));
                              return pw.Center(child: pw.Padding(padding: cellPad, child: isInvMon ? buildCheckmark(color: PdfColors.green900, size: 9) : pw.SizedBox()));
                            }),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('كل أجهزة الإنفرترات متصلة بشاشة المراقبة'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            ...List.generate(totalCols, (i) {
                              final u = totalCols - i;
                              final uMatch = getOpVal(['op_mon_match', 'mon_match']);
                              final isMatched = ((u <= invCount && invCount > 0) || (u <= ccCount && ccCount > 0)) &&
                                  (uMatch.isEmpty ? monitorScreenGood : (uMatch == 'true' || uMatch == '1' || uMatch == 'نعم'));
                              return pw.Center(child: pw.Padding(padding: cellPad, child: isMatched ? buildCheckmark(color: PdfColors.green900, size: 9) : pw.SizedBox()));
                            }),
                            pw.Padding(padding: cellPad, child: pw.Text(_ar('مطابقة القراءات مع الواقع'), style: textStyle(size: labelFontSize, isBold: true), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(child: pageContent, rotW: rotW, rotH: rotH);
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= PAGE 9: PV Strings Performance (Active Combiner Boxes Only) =================
    if (pagesToExport == null || pagesToExport.contains(9)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(9);
      final pMode = getPageMode(9);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;
      final isWide = isLandscape || isBookMode;
      final isPortrait = !isWide;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 8),
          build: (pw.Context context) {
            // Only active and selected combiner boxes are displayed in the report
            final activeBoxes = List<int>.from(report.activeCombinerBoxes)..sort();
            if (activeBoxes.isEmpty) {
              activeBoxes.add(1);
            }

            // Organize active boxes into blocks/rows according to orientation & count
            List<List<int>> allBlocks = [];
            if (isPortrait) {
              if (activeBoxes.length <= 3) {
                allBlocks = [activeBoxes];
              } else {
                for (int i = 0; i < activeBoxes.length; i += 2) {
                  allBlocks.add(activeBoxes.sublist(i, math.min(i + 2, activeBoxes.length)));
                }
              }
            } else {
              // Landscape / Book Mode
              if (activeBoxes.length <= 4) {
                allBlocks = [activeBoxes];
              } else if (activeBoxes.length == 6) {
                allBlocks = [
                  activeBoxes.sublist(0, 3),
                  activeBoxes.sublist(3, 6),
                ];
              } else {
                for (int i = 0; i < activeBoxes.length; i += 4) {
                  allBlocks.add(activeBoxes.sublist(i, math.min(i + 4, activeBoxes.length)));
                }
              }
            }

            final totalBlocksCount = allBlocks.length;
            final maxBoxesInAnyBlock = allBlocks.map((b) => b.length).reduce(math.max);

            final effectivePageW = isBookMode ? rotW : pFormat.width;
            final effectivePageH = isBookMode ? rotH : pFormat.height;
            final availableTableWidth = effectivePageW - 28.0 - 19.0;
            final notesWidth = (availableTableWidth > 950)
                ? 75.0
                : (isPortrait ? 46.0 : 54.0);
            final metricWidth = (availableTableWidth > 950)
                ? 140.0
                : (isPortrait ? (maxBoxesInAnyBlock >= 3 ? 82.0 : 92.0) : 100.0);
            final availableBoxesWidth = availableTableWidth - notesWidth - metricWidth;
            final boxWidth = availableBoxesWidth / maxBoxesInAnyBlock;
            final stringSubColWidth = boxWidth / 4;

            // Accurate non-table overhead deduction:
            final nonTableOverhead = (effectivePageH > 750) ? 235.0 : 216.0;
            final availableTableHeight = (effectivePageH - nonTableOverhead).clamp(250.0, 700.0);
            final blockSpacing = (availableTableHeight > 500) ? 6.0 : 3.5;
            final totalBlockSpacing = (totalBlocksCount - 1) * blockSpacing;
            final blockHeight = ((availableTableHeight - totalBlockSpacing) / totalBlocksCount).clamp(68.0, isPortrait ? (totalBlocksCount <= 2 ? 145.0 : 120.0) : 135.0);

            final r1H = (blockHeight * 0.17).clamp(12.0, 24.0);
            final r2H = (blockHeight * 0.17).clamp(12.0, 24.0);
            final r3H = (blockHeight * 0.17).clamp(12.0, 24.0);
            final r4H = (blockHeight - (r1H + r2H + r3H)) / 2;
            final r5H = r4H;
            final headerBlankH = r1H + r2H + r3H;

            // Responsive typography based on column widths
            final strFontSize = stringSubColWidth > 45 ? 8.0 : (stringSubColWidth > 32 ? 7.0 : 6.2);
            final valFontSize = stringSubColWidth > 45 ? 9.5 : (stringSubColWidth > 32 ? 8.5 : 7.2);
            final boxTitleFontSize = boxWidth > 180 ? 9.5 : (boxWidth > 120 ? 8.5 : 7.5);
            final panelFontSize = boxWidth > 180 ? 8.5 : (boxWidth > 120 ? 7.5 : 6.8);
            final metricFontSize = metricWidth > 100 ? 8.5 : 7.2;
            final notesFontSize = notesWidth > 60 ? 8.0 : 7.0;

            pw.Widget buildBlock(List<int> boxes, int blockIndex) {
              final rowNotes = report.stringMeasurements
                  .where((s) => boxes.contains(((s.stringNumber - 1) ~/ 4) + 1) && s.notes.trim().isNotEmpty)
                  .map((s) => s.notes.trim())
                  .toSet()
                  .join(' ');
              final notesText = rowNotes.isNotEmpty
                  ? rowNotes
                  : (blockIndex < 2 ? 'الملاحظات' : '');

              final emptySlots = maxBoxesInAnyBlock - boxes.length;

              return pw.Container(
                height: blockHeight,
                margin: pw.EdgeInsets.only(bottom: blockSpacing),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderGrey, width: 0.5),
                  color: PdfColors.white,
                ),
                child: pw.Row(
                  children: [
                    // 1. Leftmost Column: Notes
                    pw.Container(
                      width: notesWidth,
                      height: blockHeight,
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          right: pw.BorderSide(color: borderGrey, width: 0.5),
                        ),
                      ),
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.all(2),
                      child: notesText.isNotEmpty
                          ? pw.Text(
                              _arNotes(notesText, notesWidth > 60 ? 20 : 14),
                              style: textStyle(size: rowNotes.isNotEmpty ? notesFontSize : (notesFontSize + 0.8), isBold: rowNotes.isEmpty),
                              textAlign: pw.TextAlign.center,
                            )
                          : pw.SizedBox(),
                    ),

                    // Empty slots spacer for grid alignment if a row has fewer boxes
                    if (emptySlots > 0)
                      pw.Container(
                        width: boxWidth * emptySlots,
                        height: blockHeight,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            right: pw.BorderSide(color: borderGrey, width: 0.5),
                          ),
                          color: PdfColors.grey50,
                        ),
                      ),

                    // 2. Active Combiner Boxes from Left to Right:
                    // In RTL, Box 1 is on the right, Box N on the left.
                    // So in LTR Row: Box N ... Box 1!
                    ...boxes.reversed.map((bNum) {
                      final boxPanels = report.getBoxPanelCount(bNum);
                      final panelText = boxPanels > 0 ? '$boxPanels' : '';

                      return pw.Container(
                        width: boxWidth,
                        height: blockHeight,
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            right: pw.BorderSide(color: borderGrey, width: 0.5),
                          ),
                        ),
                        child: pw.Column(
                          children: [
                            // Row 1: عدد الالواح في المصفوفة : (         )
                            pw.Container(
                              height: r1H,
                              width: boxWidth,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(
                                  bottom: pw.BorderSide(color: borderGrey, width: 0.5),
                                ),
                              ),
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                panelText.isNotEmpty
                                    ? _ar('عدد الالواح في المصفوفة : ( $panelText )')
                                    : _ar('عدد الالواح في المصفوفة : (         )'),
                                style: textStyle(size: panelFontSize, isBold: true, color: darkNavyColor),
                              ),
                            ),

                            // Row 2: صندوق تجميع $bNum
                            pw.Container(
                              height: r2H,
                              width: boxWidth,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(
                                  bottom: pw.BorderSide(color: borderGrey, width: 0.5),
                                ),
                              ),
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                _ar('صندوق تجميع $bNum'),
                                style: textStyle(size: boxTitleFontSize, isBold: true, color: darkNavyColor),
                              ),
                            ),

                            // Row 3: Strings: [السلسلة4, السلسلة3, السلسلة2, السلسلة1]
                            pw.Container(
                              height: r3H,
                              width: boxWidth,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(
                                  bottom: pw.BorderSide(color: borderGrey, width: 0.5),
                                ),
                              ),
                              child: pw.Row(
                                children: [4, 3, 2, 1].map((sNum) {
                                  return pw.Container(
                                    width: stringSubColWidth,
                                    height: r3H,
                                    decoration: pw.BoxDecoration(
                                      border: sNum > 1
                                          ? pw.Border(
                                              right: pw.BorderSide(color: borderGrey, width: 0.5),
                                            )
                                          : null,
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      _ar('السلسلة$sNum'),
                                      style: textStyle(size: strFontSize, isBold: true),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            // Row 4: Voltage (Voc)
                            pw.Container(
                              height: r4H,
                              width: boxWidth,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(
                                  bottom: pw.BorderSide(color: borderGrey, width: 0.5),
                                ),
                              ),
                              child: pw.Row(
                                children: [4, 3, 2, 1].map((sNum) {
                                  final gIdx = ((bNum - 1) * 4) + sNum;
                                  final sm = report.stringMeasurements.firstWhere(
                                    (s) => s.stringNumber == gIdx,
                                    orElse: () => const StringMeasurement(
                                      stringNumber: 0,
                                      openCircuitVoltageVoc: 0,
                                      shortCircuitCurrentIsc: 0,
                                    ),
                                  );
                                  final valText = (sm.stringNumber > 0 && sm.openCircuitVoltageVoc > 0)
                                      ? sm.openCircuitVoltageVoc.toStringAsFixed(1)
                                      : '';

                                  return pw.Container(
                                    width: stringSubColWidth,
                                    height: r4H,
                                    decoration: pw.BoxDecoration(
                                      border: sNum > 1
                                          ? pw.Border(
                                              right: pw.BorderSide(color: borderGrey, width: 0.5),
                                            )
                                          : null,
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      valText,
                                      style: textStyle(size: valFontSize),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            // Row 5: Current (Isc)
                            pw.Container(
                              height: r5H,
                              width: boxWidth,
                              child: pw.Row(
                                children: [4, 3, 2, 1].map((sNum) {
                                  final gIdx = ((bNum - 1) * 4) + sNum;
                                  final sm = report.stringMeasurements.firstWhere(
                                    (s) => s.stringNumber == gIdx,
                                    orElse: () => const StringMeasurement(
                                      stringNumber: 0,
                                      openCircuitVoltageVoc: 0,
                                      shortCircuitCurrentIsc: 0,
                                    ),
                                  );
                                  final valText = (sm.stringNumber > 0 && sm.shortCircuitCurrentIsc > 0)
                                      ? sm.shortCircuitCurrentIsc.toStringAsFixed(1)
                                      : '';

                                  return pw.Container(
                                    width: stringSubColWidth,
                                    height: r5H,
                                    decoration: pw.BoxDecoration(
                                      border: sNum > 1
                                          ? pw.Border(
                                              right: pw.BorderSide(color: borderGrey, width: 0.5),
                                            )
                                          : null,
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text(
                                      valText,
                                      style: textStyle(size: valFontSize),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // 3. Rightmost Column: Metric Labels
                    pw.Container(
                      width: metricWidth,
                      height: blockHeight,
                      child: pw.Column(
                        children: [
                          // Top Blank Header
                          pw.Container(
                            height: headerBlankH,
                            width: metricWidth,
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(color: borderGrey, width: 0.5),
                              ),
                            ),
                          ),

                          // Row 4: جهد سلسلة الالواح(فولت)
                          pw.Container(
                            height: r4H,
                            width: metricWidth,
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(color: borderGrey, width: 0.5),
                              ),
                            ),
                            alignment: pw.Alignment.center,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                            child: pw.Text(
                              _ar('جهد سلسلة الالواح(فولت)'),
                              style: textStyle(size: metricFontSize, isBold: true),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),

                          // Row 5: تيار سلسلة الالواح (أمبير)
                          pw.Container(
                            height: r5H,
                            width: metricWidth,
                            alignment: pw.Alignment.center,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                            child: pw.Text(
                              _ar('تيار سلسلة الالواح (أمبير)'),
                              style: textStyle(size: metricFontSize, isBold: true),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isWide),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 10),
                    decoration: pw.BoxDecoration(
                      color: cyanColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        _ar('12 - نموذج قياسات اداء الالواح'),
                        style: textStyle(size: 10, isBold: true, color: PdfColors.white),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  // Master Grid of Combiner Blocks spanning full available width
                  pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Container(
                      width: availableTableWidth,
                      child: pw.Column(
                        children: allBlocks.asMap().entries.map((entry) {
                          return buildBlock(entry.value, entry.key);
                        }).toList(),
                      ),
                    ),
                  ),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(
                child: pageContent,
                rotW: rotW,
                rotH: rotH,
                padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 8),
              );
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= PAGE 10: Official Attendance Statement matching ref_page_10.png =================
    if (pagesToExport == null || pagesToExport.contains(10)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(10);
      final pMode = getPageMode(10);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;
      final isWide = isLandscape || isBookMode;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
          build: (pw.Context context) {
            // Clean facility name resolution to prevent contractor duplication
            final rawFacNameAr = report.facilityInfo.facilityName.trim();
            final hasFacNameAr = rawFacNameAr.isNotEmpty &&
                rawFacNameAr != contractorAr &&
                !rawFacNameAr.contains('......');
            final facNameAr = hasFacNameAr ? rawFacNameAr : '';
            final facDisplayAr = hasFacNameAr ? facNameAr : '.....................................................';

            final rawFacNameEn = report.facilityInfo.facilityNameEn.trim();
            final hasFacNameEn = rawFacNameEn.isNotEmpty &&
                rawFacNameEn != contractorEn &&
                !rawFacNameEn.contains('Al-Etqan') &&
                !rawFacNameEn.contains('......') &&
                !ArabicReshaper.hasArabic(rawFacNameEn);
            final facNameEn = hasFacNameEn ? rawFacNameEn : '';
            final facDisplayEn = hasFacNameEn ? facNameEn : '.....................................................';

            final currentYear = DateTime.now().year;
            final dateText = report.visitDate.isNotEmpty ? report.visitDate : '....../....../$currentYear';
            final installDateStr = report.facilityInfo.installationDate.trim();
            final installDateDisplay = installDateStr.isNotEmpty ? installDateStr : '                            ';

            final repName = report.approvalStatement.beneficiaryRepName.isNotEmpty
                ? report.approvalStatement.beneficiaryRepName
                : report.facilityInfo.contactPerson;
            final repRole = report.approvalStatement.beneficiaryRepRole.isNotEmpty
                ? report.approvalStatement.beneficiaryRepRole
                : 'مدير المنشأة';

            final repNameEnText = report.approvalStatement.beneficiaryRepNameEn.trim();
            final repRoleEnText = report.approvalStatement.beneficiaryRepRoleEn.trim();

            final hasFunder = showRight && (rightAr.isNotEmpty || rightEn.isNotEmpty);
            final funderSuffixAr = (hasFunder && rightAr.isNotEmpty)
                ? '، والتي تم تمويلها من قبل $rightAr.'
                : '.';
            final funderSuffixEn = (hasFunder && rightEn.isNotEmpty)
                ? ', which was funded by $rightEn.'
                : '.';

            final fullStatementAr = 'تؤكد إدارة $facDisplayAr أن مندوب $contractorAr قام بزيارة الموقع للصيانة الوقائية الدورية لمنظومة الطاقة الشمسية المركبة بتاريخ ($installDateDisplay). وخلال هذه الزيارة قاموا بإتمام كافة أعمال الصيانة الوقائية اللازمة لمنظومة الطاقة الشمسية$funderSuffixAr';
            final fullStatementEn = 'The management of $facDisplayEn certifies that a representative from $contractorEn made the periodic preventive maintenance visit for the solar system installed on ($installDateDisplay). During this visit, they completed all the necessary preventive maintenance work for the solar system$funderSuffixEn';

            final effectivePageW = isWide ? (isLandscape ? pFormat.width : rotW) : pFormat.width;
            final availableContentWidth = effectivePageW - 47.0;
            final stmtFontSize = isWide ? (effectivePageW > 900 ? 12.5 : 11.0) : 10.0;
            final stmtLineSpacing = isWide ? (effectivePageW > 900 ? 6.5 : 5.0) : 4.0;
            final sigBlockWidth = isWide ? ((availableContentWidth - 110) / 2) : 200.0;
            final sigFontSize = isWide ? (effectivePageW > 900 ? 11.0 : 10.0) : 9.5;
            final sigRowGap = isWide ? 12.0 : 8.0;

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isWide),
                  // Banner: Attendance statement إفادة حضور
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 14),
                    decoration: pw.BoxDecoration(
                      color: cyanColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Attendance statement', style: textStyle(size: 10, isBold: true, color: PdfColors.white)),
                        pw.Text(_ar('إفادة حضور'), style: textStyle(size: 10.5, isBold: true, color: PdfColors.white)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: isLandscape ? 18 : 22),
                  // Arabic statement (Full continuous margin-to-margin dynamic width wrapping)
                  pw.Text(
                    wrapArabicByWidth(fullStatementAr, availableContentWidth, stmtFontSize, ttfRegular.getFont(context)),
                    style: textStyle(size: stmtFontSize, lineSpacing: stmtLineSpacing),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: isLandscape ? 16 : 22),
                  // English statement (natural LTR wrap)
                  pw.Text(
                    fullStatementEn,
                    style: textStyle(size: stmtFontSize, lineSpacing: stmtLineSpacing),
                    textAlign: pw.TextAlign.left,
                  ),
                  pw.Spacer(),
                  // Dual Signatures matching ref_kidney_page_10.png (Clean dotted lines, no grey boxes)
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // English block (Left)
                      pw.Container(
                        width: sigBlockWidth,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.Text(
                                  'Management ',
                                  style: textStyle(size: sigFontSize + 0.5, isBold: true),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    hasFacNameEn
                                        ? rawFacNameEn
                                        : '................................................................',
                                    style: textStyle(size: sigFontSize),
                                    maxLines: 1,
                                    overflow: pw.TextOverflow.clip,
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: sigRowGap),
                            pw.Row(
                              children: [
                                pw.Text('Name:  ', style: textStyle(size: sigFontSize, isBold: true)),
                                pw.Expanded(
                                  child: pw.Text(
                                    repNameEnText.isNotEmpty ? repNameEnText : '................................................................',
                                    style: textStyle(size: sigFontSize),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: sigRowGap),
                            pw.Row(
                              children: [
                                pw.Text('Title:  ', style: textStyle(size: sigFontSize, isBold: true)),
                                pw.Expanded(
                                  child: pw.Text(
                                    repRoleEnText.isNotEmpty ? repRoleEnText : '................................................................',
                                    style: textStyle(size: sigFontSize),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: sigRowGap),
                            pw.Row(
                              children: [
                                pw.Text('Date:  ', style: textStyle(size: sigFontSize, isBold: true)),
                                pw.Expanded(
                                  child: pw.Text(
                                    (dateText.isNotEmpty && !dateText.contains('......')) ? dateText : '................................................................',
                                    style: textStyle(size: sigFontSize),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: sigRowGap),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text('Signature: ', style: textStyle(size: sigFontSize, isBold: true)),
                                if (beneficiarySigImage != null)
                                  pw.Container(
                                    height: isLandscape ? 38 : 32,
                                    width: isLandscape ? 110 : 90,
                                     alignment: pw.Alignment.center,
                                     child: pw.Center(
                                       child: pw.Image(beneficiarySigImage, fit: pw.BoxFit.contain, alignment: pw.Alignment.center),
                                     ),
                                  )
                                else
                                  pw.Expanded(
                                    child: pw.Text('................................................................', style: textStyle(size: sigFontSize)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Center Stamp if present
                      if (stampImage != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                          child: pw.Column(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Container(
                                width: isWide ? 85 : 75,
                                height: isWide ? 85 : 75,
                                 alignment: pw.Alignment.center,
                                 child: pw.Center(
                                   child: pw.Image(stampImage, fit: pw.BoxFit.contain, alignment: pw.Alignment.center),
                                 ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(_ar('الختم الرسمي للمنشأة'), style: textStyle(size: 7.5, color: PdfColors.grey700)),
                            ],
                          ),
                        ),

                      // Arabic block (Right)
                      pw.Container(
                        width: sigBlockWidth,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              _ar(hasFacNameAr
                                  ? (facNameAr.startsWith('إدارة') || facNameAr.startsWith('ادارة') ? facNameAr : 'ادارة $facNameAr')
                                  : 'ادارة ................................................................'),
                              style: textStyle(size: sigFontSize + 0.5, isBold: true),
                              textAlign: pw.TextAlign.right,
                            ),
                            pw.SizedBox(height: sigRowGap),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    (repName.isNotEmpty && repName != '.....................................................')
                                        ? _ar(repName)
                                        : '................................................................',
                                    style: textStyle(size: sigFontSize),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                                pw.SizedBox(width: 4),
                                pw.Text(_ar('الاسم:'), style: textStyle(size: sigFontSize, isBold: true)),
                              ],
                            ),
                            pw.SizedBox(height: sigRowGap),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    (repRole.isNotEmpty && repRole != '.....................................................')
                                        ? _ar(repRole)
                                        : '................................................................',
                                    style: textStyle(size: sigFontSize),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                                pw.SizedBox(width: 4),
                                pw.Text(_ar('المنصب:'), style: textStyle(size: sigFontSize, isBold: true)),
                              ],
                            ),
                            pw.SizedBox(height: sigRowGap),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    (dateText.isNotEmpty && !dateText.contains('......'))
                                        ? dateText
                                        : '................................................................',
                                    style: textStyle(size: sigFontSize),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ),
                                pw.SizedBox(width: 4),
                                pw.Text(_ar('التاريخ:'), style: textStyle(size: sigFontSize, isBold: true)),
                              ],
                            ),
                            pw.SizedBox(height: sigRowGap),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.end,
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                if (beneficiarySigImage != null)
                                  pw.Container(
                                     alignment: pw.Alignment.center,
                                    height: isWide ? 44 : 38,
                                    width: isWide ? 120 : 100,
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.white,
                                      border: pw.Border.all(color: cyanColor, width: 0.8),
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                    ),
                                     child: pw.Center(
                                       child: pw.Image(beneficiarySigImage, fit: pw.BoxFit.contain, alignment: pw.Alignment.center),
                                     ),
                                  )
                                else
                                  pw.Expanded(
                                    child: pw.Text('................................................................', style: textStyle(size: sigFontSize), textAlign: pw.TextAlign.right),
                                  ),
                                pw.SizedBox(width: 4),
                                pw.Text(_ar('التوقيع:'), style: textStyle(size: sigFontSize, isBold: true)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(
                child: pageContent,
                rotW: rotW,
                rotH: rotH,
                padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
              );
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= PAGE 11: Team Attendance Sheet matching ref_page_11.png =================
    if (pagesToExport == null || pagesToExport.contains(11)) {
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(11);
      final pMode = getPageMode(11);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;
      final isWide = isLandscape || isBookMode;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
          build: (pw.Context context) {
            final projNameEn = report.projectInfo.projectName.isNotEmpty
                ? (ArabicReshaper.hasArabic(report.projectInfo.projectName)
                    ? _ar(report.projectInfo.projectName)
                    : report.projectInfo.projectName)
                : '';

            final currentYear = DateTime.now().year;

            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isWide),
                  // Top Metadata Box with Dark Navy Blue Header (LTR Layout matching ref_page_11)
                  pw.Table(
                    border: pw.TableBorder.all(color: darkNavyColor, width: 0.8),
                    columnWidths: const {
                      0: pw.FixedColumnWidth(125), // Label (Col 0, Left)
                      1: pw.FlexColumnWidth(3.8),   // Value (Col 1, Right)
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: darkNavyColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: pw.Text('Project Name', style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)),
                          ),
                          pw.Container(
                            color: darkNavyColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: pw.Text(projNameEn, style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: darkNavyColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: pw.Text('Report Description', style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)),
                          ),
                          pw.Container(
                            color: darkNavyColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: pw.Text("Maintenance team's attendance", style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            color: darkNavyColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: pw.Text('Contract NO', style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)),
                          ),
                          pw.Container(
                            color: darkNavyColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: pw.Text(report.contractNumber, style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  // Date and Day (LTR)
                  pw.Row(
                    children: [
                      pw.Text('Date : ${report.visitDate.isNotEmpty ? report.visitDate : "..... / ..... / $currentYear"}', style: textStyle(size: 8.5, isBold: true)),
                      pw.SizedBox(width: 40),
                      pw.Text('Day : .....................', style: textStyle(size: 8.5, isBold: true)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('We confirm that the following persons and representatives from our side have come for', style: textStyle(size: 8, isBold: true)),
                  pw.SizedBox(height: 6),
                  (() {
                    final attCellPad = isWide ? const pw.EdgeInsets.symmetric(vertical: 6.5, horizontal: 6) : const pw.EdgeInsets.all(3.5);
                    final attHeaderPad = isWide ? const pw.EdgeInsets.symmetric(vertical: 7.0, horizontal: 6) : const pw.EdgeInsets.all(4);
                    final attFontSize = isWide ? 8.8 : 7.5;
                    final targetRowCount = isWide ? 8 : 4;

                    final validAttendance = report.attendanceList.where((a) =>
                      a.name.trim().isNotEmpty || (a.signatureBase64 != null && a.signatureBase64!.trim().isNotEmpty)
                    ).toList();

                    // Team Table (LTR Layout: NO | Trainee Name | Signature | Role)
                    return pw.Table(
                      border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                      columnWidths: const {
                        0: pw.FixedColumnWidth(35), // NO
                        1: pw.FlexColumnWidth(3.5), // Trainee Name
                        2: pw.FlexColumnWidth(2.5), // Signature
                        3: pw.FlexColumnWidth(2.5), // Role
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: darkNavyColor),
                          children: [
                            pw.Padding(padding: attHeaderPad, child: pw.Center(child: pw.Text('NO', style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)))),
                            pw.Padding(padding: attHeaderPad, child: pw.Center(child: pw.Text('Trainee Name', style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)))),
                            pw.Padding(padding: attHeaderPad, child: pw.Center(child: pw.Text('Signature', style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)))),
                            pw.Padding(padding: attHeaderPad, child: pw.Center(child: pw.Text('Role', style: textStyle(size: 8.5, isBold: true, color: PdfColors.white)))),
                          ],
                        ),
                        ...validAttendance.asMap().entries.map((entry) {
                          final attIdx = entry.key;
                          final att = entry.value;
                          final attSigImg = safeSignatureImage(att.signatureBase64);
                          return pw.TableRow(
                            children: [
                              pw.Padding(padding: attCellPad, child: pw.Center(child: pw.Text('${attIdx + 1}', style: textStyle(size: attFontSize, isBold: true)))),
                              pw.Padding(padding: attCellPad, child: pw.Center(child: pw.Text(_ar(att.name), style: textStyle(size: attFontSize + 0.5, isBold: true)))),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(2.5),
                                child: pw.Center(
                                  child: attSigImg != null
                                      ? pw.Container(
                                           alignment: pw.Alignment.center,
                                           height: isWide ? 34 : 28,
                                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: pw.BoxDecoration(
                                            color: PdfColors.white,
                                            border: pw.Border.all(color: PdfColor.fromHex('#2E7D32'), width: 0.8),
                                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                          ),
                                           child: pw.Center(
                                             child: pw.Image(attSigImg, fit: pw.BoxFit.contain, alignment: pw.Alignment.center),
                                           ),
                                        )
                                      : pw.Container(
                                          height: isWide ? 30 : 24,
                                          alignment: pw.Alignment.center,
                                          child: pw.Column(
                                            mainAxisAlignment: pw.MainAxisAlignment.center,
                                            children: [
                                              pw.Text('................................', style: textStyle(size: 6, color: PdfColors.grey500)),
                                              pw.SizedBox(height: 1),
                                              pw.Text(_ar('التوقيع اليدوي / Signature'), style: textStyle(size: 5.5, color: PdfColors.grey600)),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              pw.Padding(
                                padding: attCellPad,
                                child: pw.Center(
                                  child: pw.Text(
                                    _ar(att.role.isNotEmpty ? att.role : (att.notes.isNotEmpty ? att.notes : '')),
                                    style: textStyle(size: attFontSize),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        ...List.generate(
                          (targetRowCount - validAttendance.length).clamp(0, targetRowCount),
                          (padIdx) {
                            final rowNo = validAttendance.length + padIdx + 1;
                            return pw.TableRow(
                              children: [
                                pw.Padding(padding: attCellPad, child: pw.Center(child: pw.Text('$rowNo', style: textStyle(size: attFontSize, isBold: true)))),
                                pw.Padding(padding: attCellPad, child: pw.Center(child: pw.Text('', style: textStyle(size: attFontSize + 0.5)))),
                                pw.Padding(padding: attCellPad, child: pw.Center(child: pw.Text('', style: textStyle(size: attFontSize)))),
                                pw.Padding(padding: attCellPad, child: pw.Center(child: pw.Text('', style: textStyle(size: attFontSize)))),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  })(),
                  pw.Spacer(),
                  buildRunningFooter(pNum),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(
                child: pageContent,
                rotW: rotW,
                rotH: rotH,
                padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
              );
            }

            return pageContent;
          },
        ),
      );
    }

    // ================= OPTIONAL PAGE 12+: Field Photos Appendix =================
    if (report.photos.isNotEmpty && (pagesToExport == null || pagesToExport.contains(12))) {
      final validPhotos = <ReportPhoto>[];
      final photoImages = <String, pw.MemoryImage>{};
      for (final photo in report.photos) {
        final origBytes = photo.getBytesSync();
        if (origBytes != null && origBytes.isNotEmpty) {
          Uint8List bytes = origBytes;
          try {
            final decoded = image_pkg.decodeImage(bytes);
            if (decoded != null) {
              final isActuallyLandscape = decoded.width > decoded.height;
              if (photo.displaySize == PhotoDisplaySize.fullWidth && !isActuallyLandscape) {
                // Requested full-width landscape, but image is portrait -> rotate 90°
                final rotated = image_pkg.copyRotate(decoded, angle: 90);
                bytes = Uint8List.fromList(image_pkg.encodeJpg(rotated, quality: 85));
              }
            }
            final img = pw.MemoryImage(bytes);
            photoImages[photo.id] = img;
            validPhotos.add(photo);
          } catch (_) {
            try {
              final img = pw.MemoryImage(bytes);
              photoImages[photo.id] = img;
              validPhotos.add(photo);
            } catch (_) {}
          }
        }
      }

      if (validPhotos.isNotEmpty) {
        // Build visual rows based on PhotoDisplaySize
        final photoRows = <_PhotoRowData>[];
        var pendingPhotos = <ReportPhoto>[];
        var pendingType = PhotoDisplaySize.halfWidth;

        void flushPending() {
          if (pendingPhotos.isEmpty) return;
          final isCompact = pendingType == PhotoDisplaySize.compact;
          photoRows.add(_PhotoRowData(
            List<ReportPhoto>.from(pendingPhotos),
            isCompact ? 0.68 : 1.0,
          ));
          pendingPhotos.clear();
        }

        for (final p in validPhotos) {
          final isFull = p.displaySize == PhotoDisplaySize.fullWidth || p.widthFactor >= 0.85;
          final isComp = p.displaySize == PhotoDisplaySize.compact || p.widthFactor <= 0.40;
          if (isFull) {
            flushPending();
            photoRows.add(_PhotoRowData([p], 1.0));
          } else if (isComp) {
            if (pendingPhotos.isNotEmpty && pendingType != PhotoDisplaySize.compact) {
              flushPending();
            }
            pendingType = PhotoDisplaySize.compact;
            pendingPhotos.add(p);
            if (pendingPhotos.length == 3) {
              flushPending();
            }
          } else {
            // halfWidth, 67% or beforeAfter
            if (pendingPhotos.isNotEmpty && pendingType == PhotoDisplaySize.compact) {
              flushPending();
            }
            pendingType = PhotoDisplaySize.halfWidth;
            pendingPhotos.add(p);
            if (pendingPhotos.length == 2) {
              flushPending();
            }
          }
        }
        flushPending();

        // Pack rows into pages (Max weight per page ~2.05)
        final photoPages = <List<_PhotoRowData>>[];
        var currentPageRows = <_PhotoRowData>[];
        double currentPageWeight = 0.0;

        for (final row in photoRows) {
          if (currentPageRows.isNotEmpty && (currentPageWeight + row.heightWeight > 2.05)) {
            photoPages.add(currentPageRows);
            currentPageRows = [row];
            currentPageWeight = row.heightWeight;
          } else {
            currentPageRows.add(row);
            currentPageWeight += row.heightWeight;
          }
        }
        if (currentPageRows.isNotEmpty) {
          photoPages.add(currentPageRows);
        }

        pw.Widget buildPhotoCard(ReportPhoto photo, {bool isFullWidth = false, bool isCompact = false}) {
          final img = photoImages[photo.id];
          if (img == null) return pw.SizedBox();

          final isBeforeAfter = photo.displaySize == PhotoDisplaySize.beforeAfter;
          final isAfter = photo.beforeAfterStage == 'after';

          PdfColor cardBorderColor = borderGrey;
          double cardBorderWidth = 0.6;
          if (isBeforeAfter) {
            cardBorderColor = isAfter ? PdfColor.fromHex('#2E7D32') : PdfColor.fromHex('#E65100');
            cardBorderWidth = 1.2;
          } else if (isFullWidth) {
            cardBorderColor = PdfColor.fromHex('#00838F');
            cardBorderWidth = 1.0;
          }

          final titleText = photo.title.isNotEmpty
              ? photo.title
              : (photo.caption.isNotEmpty ? photo.caption : 'صورة توثيقية');
          final subText = photo.location.isNotEmpty
              ? (photo.title.isNotEmpty && photo.caption.isNotEmpty ? '${photo.location} - ${photo.caption}' : photo.location)
              : (photo.title.isNotEmpty ? photo.caption : '');

          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: cardBorderColor, width: cardBorderWidth),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 5,
              verticalRadius: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Top Before / After Badge
                  if (isBeforeAfter)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
                      decoration: pw.BoxDecoration(
                        color: isAfter ? PdfColor.fromHex('#E8F5E9') : PdfColor.fromHex('#FFF3E0'),
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: isAfter ? PdfColor.fromHex('#A5D6A7') : PdfColor.fromHex('#FFCC80'),
                            width: 0.6,
                          ),
                        ),
                      ),
                      child: pw.Text(
                        _ar(isAfter ? 'بعد الصيانة / After Maintenance' : 'قبل الصيانة / Before Maintenance'),
                        style: textStyle(
                          size: 8,
                          isBold: true,
                          color: isAfter ? PdfColor.fromHex('#1B5E20') : PdfColor.fromHex('#BF360C'),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),

                  // Photo Image
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(
                        child: pw.ClipRRect(
                          horizontalRadius: 3,
                          verticalRadius: 3,
                          child: pw.Image(img, fit: pw.BoxFit.contain),
                        ),
                      ),
                    ),
                  ),

                  // Caption / Title Footer
                  pw.Container(
                    padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: isCompact ? 2 : 3),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
                      ),
                    ),
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          _ar(titleText),
                          style: textStyle(
                            size: isCompact ? 7.5 : (isFullWidth ? 9.5 : 8.5),
                            isBold: true,
                            color: darkNavyColor,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 1,
                        ),
                        if (subText.isNotEmpty && !isCompact) ...[
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            _ar(subText),
                            style: textStyle(size: 7.0, color: PdfColors.grey700),
                            textAlign: pw.TextAlign.center,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        pw.Widget buildRowWidget(_PhotoRowData row) {
          final isCompact = row.photos.any((p) => p.displaySize == PhotoDisplaySize.compact);
          final isFullWidth = row.photos.length == 1 && row.photos[0].displaySize == PhotoDisplaySize.fullWidth;

          if (isFullWidth) {
            return pw.Expanded(
              flex: (row.heightWeight * 100).round(),
              child: buildPhotoCard(row.photos[0], isFullWidth: true),
            );
          } else if (isCompact) {
            final widgets = <pw.Widget>[];
            for (int i = 0; i < 3; i++) {
              if (i < row.photos.length) {
                widgets.add(pw.Expanded(
                  child: buildPhotoCard(row.photos[i], isCompact: true),
                ));
              } else {
                widgets.add(pw.Expanded(child: pw.SizedBox()));
              }
              if (i < 2) {
                widgets.add(pw.SizedBox(width: 6));
              }
            }
            return pw.Expanded(
              flex: (row.heightWeight * 100).round(),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: widgets,
              ),
            );
          } else {
            final widgets = <pw.Widget>[];
            for (int i = 0; i < 2; i++) {
              if (i < row.photos.length) {
                widgets.add(pw.Expanded(
                  child: buildPhotoCard(row.photos[i]),
                ));
              } else {
                widgets.add(pw.Expanded(child: pw.SizedBox()));
              }
              if (i < 1) {
                widgets.add(pw.SizedBox(width: 8));
              }
            }
            return pw.Expanded(
              flex: (row.heightWeight * 100).round(),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: widgets,
              ),
            );
          }
        }

        final totalPhotoPages = photoPages.length;
        for (int pIdx = 0; pIdx < totalPhotoPages; pIdx++) {
          final pNum = currentPageNumber++;
          final pageRows = photoPages[pIdx];

          final bannerTitle = totalPhotoPages > 1
              ? 'ملحق التوثيق الفوتوغرافي للموقع والمنظومة (${pIdx + 1} / $totalPhotoPages)'
              : 'ملحق التوثيق الفوتوغرافي للموقع والمنظومة';

          final pFormat = resolvePageFormat(12);
          final pMode = getPageMode(12);
          final isLandscape = pFormat.width > pFormat.height;
          final isBookMode = pMode == 'book';
          final rotW = pFormat.height;
          final rotH = pFormat.width;
          final isWide = isLandscape || isBookMode;

          final rowWidgets = <pw.Widget>[];
          for (int r = 0; r < pageRows.length; r++) {
            rowWidgets.add(buildRowWidget(pageRows[r]));
            if (r < pageRows.length - 1) {
              rowWidgets.add(pw.SizedBox(height: 8));
            }
          }
          double totalWeightOnPage = pageRows.fold(0.0, (sum, r) => sum + r.heightWeight);
          if (totalWeightOnPage < 1.5) {
            rowWidgets.add(pw.Expanded(flex: 100, child: pw.SizedBox()));
          }

          pdf.addPage(
            pw.Page(
              pageFormat: pFormat,
              margin: isBookMode
                  ? pw.EdgeInsets.zero
                  : const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
              build: (pw.Context context) {
                final pageContent = wrapWithPageFrame(
                  context: context,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      buildRunningHeader(isLandscape: isWide),
                      buildSectionBanner('12', bannerTitle),
                      pw.SizedBox(height: 8),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: rowWidgets,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      buildRunningFooter(pNum),
                    ],
                  ),
                );

                if (isBookMode) {
                  return wrapWithBookModeRotation(
                    child: pageContent,
                    rotW: rotW,
                    rotH: rotH,
                    padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
                  );
                }

                return pageContent;
              },
            ),
          );
        }
      }
    }

    // --- Section 13: Next Visit Materials & Spare Parts Requisition (Optional Official Annex) ---
    final needsToPrint = report.requestedNeeds.where((n) => n.includeInPdf).toList();
    if (report.showNeedsInReport &&
        needsToPrint.isNotEmpty &&
        (pagesToExport == null || pagesToExport.contains(13))) {
      final nextVisitNum = ((int.tryParse(effectiveVisitNum) ?? 1) + 1).toString();
      final pNum = currentPageNumber++;
      final pFormat = resolvePageFormat(13);
      final pMode = getPageMode(13);
      final isLandscape = pFormat.width > pFormat.height;
      final isBookMode = pMode == 'book';
      final rotW = pFormat.height;
      final rotH = pFormat.width;

      pdf.addPage(
        pw.Page(
          pageFormat: pFormat,
          margin: isBookMode
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
          build: (pw.Context context) {
            final pageContent = wrapWithPageFrame(
              context: context,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  buildRunningHeader(isLandscape: isLandscape || isBookMode),
                  buildSectionBanner('13', 'جدول الاحتياجات والمواد المقترحة للزيارة القادمة (الزيارة رقم $nextVisitNum)'),
                  pw.SizedBox(height: 6),
                  // Explanatory Banner
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: cyanColor.withAlpha(0.1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Required Materials & Spare Parts for Next Visit ($nextVisitNum)',
                          style: textStyle(size: 8, isBold: true),
                        ),
                        pw.Text(
                          _ar('سجل بالمواد وقطع الغيار الواجب توفيرها واستكمالها في الزيارة الميدانية التالية'),
                          style: textStyle(size: 8, isBold: true),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  // Table of Needs
                  pw.Expanded(
                    child: pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
                      columnWidths: const {
                        0: pw.FlexColumnWidth(1.4), // ملاحظات وسبب الطلب
                        1: pw.FlexColumnWidth(0.7), // الأولوية
                        2: pw.FlexColumnWidth(0.7), // الكمية والوحدة
                        3: pw.FlexColumnWidth(1.1), // التصنيف
                        4: pw.FlexColumnWidth(1.8), // اسم المادة والمواصفة
                        5: pw.FixedColumnWidth(22), // م
                      },
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: darkNavyColor),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Center(child: pw.Text(_ar('سبب الطلب والملاحظات'), style: textStyle(size: 7.5, isBold: true, color: PdfColors.white))),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Center(child: pw.Text(_ar('الأولوية'), style: textStyle(size: 7.5, isBold: true, color: PdfColors.white))),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Center(child: pw.Text(_ar('الكمية'), style: textStyle(size: 7.5, isBold: true, color: PdfColors.white))),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Center(child: pw.Text(_ar('التصنيف'), style: textStyle(size: 7.5, isBold: true, color: PdfColors.white))),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Center(child: pw.Text(_ar('اسم المادة / قطعة الغيار'), style: textStyle(size: 7.5, isBold: true, color: PdfColors.white))),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Center(child: pw.Text(_ar('م'), style: textStyle(size: 7.5, isBold: true, color: PdfColors.white))),
                            ),
                          ],
                        ),
                        // Data rows
                        ...needsToPrint.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final need = entry.value;
                          final isEven = idx % 2 == 0;
                          final priorityColor = need.priority == NeedPriority.critical
                              ? PdfColors.red800
                              : (need.priority == NeedPriority.urgent ? PdfColors.orange800 : PdfColors.green800);

                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: isEven ? PdfColors.grey100 : PdfColors.white,
                            ),
                            children: [
                              // Col 0: سبب الطلب والملاحظات (Aligned to the Right)
                              pw.Container(
                                alignment: pw.Alignment.centerRight,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                                child: pw.Text(
                                  _arNotes(need.reason.isNotEmpty ? need.reason : '-', 28),
                                  style: textStyle(size: 7.5),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              // Col 1: الأولوية
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Center(
                                  child: pw.Text(_ar(need.priority.labelAr), style: textStyle(size: 7.5, isBold: true, color: priorityColor)),
                                ),
                              ),
                              // Col 2: الكمية والوحدة
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Center(
                                  child: pw.Text(
                                    _ar('${need.quantity % 1 == 0 ? need.quantity.toInt() : need.quantity} ${need.unit}'),
                                    style: textStyle(size: 7.5, isBold: true),
                                  ),
                                ),
                              ),
                              // Col 3: التصنيف
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Center(child: pw.Text(_ar(need.category), style: textStyle(size: 7.5))),
                              ),
                              // Col 4: اسم المادة / قطعة الغيار (Aligned to the Right)
                              pw.Container(
                                alignment: pw.Alignment.centerRight,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                                child: pw.Text(
                                  _arNotes(need.name, 35),
                                  style: textStyle(size: 7.5, isBold: true),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                              // Col 5: م
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Center(child: pw.Text('$idx', style: textStyle(size: 7.5, isBold: true))),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  // Procurement & Handover Sign-off Box
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: pw.BoxDecoration(
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(_ar('مسؤول المشتريات والمخازن'), style: textStyle(size: 7.5, isBold: true)),
                            pw.SizedBox(height: 18),
                            pw.Text(_ar('التوقيع: ............................'), style: textStyle(size: 7)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(_ar('مهندس الصيانة المسؤول'), style: textStyle(size: 7.5, isBold: true)),
                            pw.SizedBox(height: 18),
                            pw.Text(_ar('التوقيع: ............................'), style: textStyle(size: 7)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(_ar('اعتماد مدير المشروع'), style: textStyle(size: 7.5, isBold: true)),
                            pw.SizedBox(height: 18),
                            pw.Text(_ar('التوقيع والختم: ............................'), style: textStyle(size: 7)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  buildRunningFooter(pNum, hideBeneficiary: true),
                ],
              ),
            );

            if (isBookMode) {
              return wrapWithBookModeRotation(
                child: pageContent,
                rotW: rotW,
                rotH: rotH,
                padding: const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
              );
            }

            return pageContent;
          },
        ),
      );
    }

    return pdf.save();
  }
}

class _PhotoRowData {
  final List<ReportPhoto> photos;
  final double heightWeight;
  const _PhotoRowData(this.photos, this.heightWeight);
}
