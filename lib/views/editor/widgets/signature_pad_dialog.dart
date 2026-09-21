import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';

class SignaturePadDialog extends StatefulWidget {
  final String role;
  final String signerName;
  final ValueChanged<String> onSaved;
  final String? existingSignatureBase64;
  final VoidCallback? onCleared;

  const SignaturePadDialog({
    super.key,
    required this.role,
    required this.signerName,
    required this.onSaved,
    this.existingSignatureBase64,
    this.onCleared,
  });

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<List<Offset>> _lines = [];
  Uint8List? _existingBytes;
  bool _existingDismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSignatureBase64 != null && widget.existingSignatureBase64!.isNotEmpty) {
      _existingBytes = UiHelpers.safeDecodeBase64(widget.existingSignatureBase64);
    }
  }

  Future<void> _exportSignature() async {
    if (_lines.isEmpty) {
      if (_existingBytes != null && !_existingDismissed) {
        // Kept existing signature without modifications
        Navigator.pop(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى رسم التوقيع أولاً أو اختيار صورة توقيع جاهزة')),
      );
      return;
    }

    // Calculate bounding box of the drawn signature to crop tight with padding
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final line in _lines) {
      for (final p in line) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
    }

    if (minX.isInfinite || maxX.isInfinite) {
      minX = 0; minY = 0; maxX = 350; maxY = 180;
    }

    // Add padding around signature
    const pad = 14.0;
    final srcRect = Rect.fromLTRB(
      max(0.0, minX - pad),
      max(0.0, minY - pad),
      min(360.0, maxX + pad),
      min(200.0, maxY + pad),
    );

    final outWidth = max(60.0, srcRect.width);
    final outHeight = max(40.0, srcRect.height);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Shift canvas origin so cropped signature is top-left
    canvas.translate(-srcRect.left, -srcRect.top);

    // Deep elegant blue pen ink
    final strokePaint = Paint()
      ..color = const Color(0xFF0A369D)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF0A369D)
      ..style = PaintingStyle.fill;

    for (final line in _lines) {
      if (line.isEmpty) continue;
      if (line.length == 1) {
        canvas.drawCircle(line.first, 1.8, dotPaint);
      } else {
        for (int i = 0; i < line.length - 1; i++) {
          canvas.drawLine(line[i], line[i + 1], strokePaint);
        }
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(outWidth.toInt(), outHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final base64String = base64Encode(byteData.buffer.asUint8List());
      widget.onSaved(base64String);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickSignatureImage() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
        final b64 = base64Encode(res.files.first.bytes!);
        widget.onSaved(b64);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرفاق صورة التوقيع بنجاح')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الصورة: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 390,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.draw_rounded, color: AppTheme.primaryNavy, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التوقيع الرقمي: ${widget.role}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark),
                      ),
                      if (widget.signerName.isNotEmpty)
                        Text('المعتمد: ${widget.signerName}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle, width: 1.5),
              ),
              child: Stack(
                children: [
                  // Subtle guide baseline
                  Positioned(
                    bottom: 45,
                    left: 24,
                    right: 24,
                    child: Container(
                      height: 1,
                      color: Colors.grey.shade300,
                    ),
                  ),
                  if (_lines.isEmpty && _existingBytes != null && !_existingDismissed)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Image.memory(_existingBytes!, height: 85, fit: BoxFit.contain),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text(
                              'توقيع معتمد حالياً — ارسم فوقه للتعديل أو اضغط حذف بالأسفل',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_lines.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gesture_rounded, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 28),
                          const SizedBox(height: 4),
                          Text(
                            'قم بالتوقيع هنا بإصبعك أو القلم',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _existingDismissed = true;
                        _lines.add([details.localPosition]);
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        if (_lines.isNotEmpty) {
                          _lines.last.add(details.localPosition);
                        }
                      });
                    },
                    child: CustomPaint(
                      painter: _SignatureCanvasPainter(_lines),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.brandCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('إرفاق صورة توقيع من الهاتف', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: _pickSignatureImage,
                ),
                if (widget.onCleared != null || (_existingBytes != null && !_existingDismissed))
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.statusRejected,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('إلغاء / حذف التوقيع', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      widget.onCleared?.call();
                      if (mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('مسح', style: TextStyle(fontSize: 12)),
                  onPressed: () => setState(() {
                    _lines.clear();
                    _existingDismissed = true;
                  }),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('تراجع', style: TextStyle(fontSize: 12)),
                  onPressed: _lines.isNotEmpty
                      ? () => setState(() => _lines.removeLast())
                      : null,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('اعتماد التوقيع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _exportSignature,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignatureCanvasPainter extends CustomPainter {
  final List<List<Offset>> lines;
  _SignatureCanvasPainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A369D)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF0A369D)
      ..style = PaintingStyle.fill;

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.length == 1) {
        canvas.drawCircle(line.first, 1.8, dotPaint);
      } else {
        for (int i = 0; i < line.length - 1; i++) {
          canvas.drawLine(line[i], line[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureCanvasPainter oldDelegate) => true;
}

