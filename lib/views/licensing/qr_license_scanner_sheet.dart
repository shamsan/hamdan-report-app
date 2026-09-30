/**
 * ══════════════════════════════════════════════════════════════
 *  QR License Scanner Sheet (High-Speed Mobile Camera)
 *  ReportCraft Enterprise Mobile UI
 * ══════════════════════════════════════════════════════════════
 *  مسح رمز QR لمفتاح الترخيص فورياً وتلقائياً دون كتابة يدوية
 */

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';

class QrLicenseScannerSheet extends StatefulWidget {
  const QrLicenseScannerSheet({super.key});

  /// إظهار الماسح كـ Modal مخصص
  static Future<String?> scan(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const QrLicenseScannerSheet(),
    );
  }

  @override
  State<QrLicenseScannerSheet> createState() => _QrLicenseScannerSheetState();
}

class _QrLicenseScannerSheetState extends State<QrLicenseScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _hasScanned = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue != null && rawValue.isNotEmpty) {
        _hasScanned = true;
        // إغلاق الماسح وإرجاع القيمة المقروءة
        Navigator.of(context).pop(rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = (size.width * 0.7).clamp(220.0, 300.0);

    return Container(
      height: size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF061A2B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // ─── 1. كاميرا المسح ───
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: MobileScanner(
              controller: _controller,
              onDetect: _onBarcodeDetected,
            ),
          ),

          // ─── 2. قناع داكن حول منطقة المسح (Vignette Mask) ───
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(
                scanAreaSize: scanAreaSize,
                borderColor: AppTheme.brandCyan,
              ),
            ),
          ),

          // ─── 3. Header & Controls ───
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // شريط العنوان وأزرار التحكم العلوية
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Text(
                        'مسح رمز QR للترخيص',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: _isTorchOn ? Colors.amber : Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                        onPressed: () async {
                          await _controller.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        },
                      ),
                    ],
                  ),

                  // إرشادات سفلية
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, color: AppTheme.brandCyan, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'وجه الكاميرا نحو رمز QR على شاشة لوحة التحكم',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final Color borderColor;

  _ScannerOverlayPainter({required this.scanAreaSize, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)));

    final combinedPath = Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(combinedPath, backgroundPaint);

    // رسم زوايا الإطار
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    const cornerLength = 26.0;
    const radius = 16.0;

    // Top-Left
    canvas.drawLine(Offset(left, top + radius + cornerLength), Offset(left, top + radius), borderPaint);
    canvas.drawArc(Rect.fromLTWH(left, top, radius * 2, radius * 2), 3.14159, 1.57079, false, borderPaint);
    canvas.drawLine(Offset(left + radius, top), Offset(left + radius + cornerLength, top), borderPaint);

    // Top-Right
    final right = left + scanAreaSize;
    canvas.drawLine(Offset(right - radius - cornerLength, top), Offset(right - radius, top), borderPaint);
    canvas.drawArc(Rect.fromLTWH(right - radius * 2, top, radius * 2, radius * 2), 4.71238, 1.57079, false, borderPaint);
    canvas.drawLine(Offset(right, top + radius), Offset(right, top + radius + cornerLength), borderPaint);

    // Bottom-Left
    final bottom = top + scanAreaSize;
    canvas.drawLine(Offset(left, bottom - radius - cornerLength), Offset(left, bottom - radius), borderPaint);
    canvas.drawArc(Rect.fromLTWH(left, bottom - radius * 2, radius * 2, radius * 2), 1.57079, 1.57079, false, borderPaint);
    canvas.drawLine(Offset(left + radius, bottom), Offset(left + radius + cornerLength, bottom), borderPaint);

    // Bottom-Right
    canvas.drawLine(Offset(right - radius - cornerLength, bottom), Offset(right - radius, bottom), borderPaint);
    canvas.drawArc(Rect.fromLTWH(right - radius * 2, bottom - radius * 2, radius * 2, radius * 2), 0, 1.57079, false, borderPaint);
    canvas.drawLine(Offset(right, bottom - radius), Offset(right, bottom - radius - cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
