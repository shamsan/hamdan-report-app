import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
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

  Color _penColor = const Color(0xFF0A369D); // الأزرق الملكي المعتمد
  double _strokeWidth = 3.4;

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

    // Calculate bounding box of the drawn signature to crop tight with equal padding
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
      minX = 0; minY = 0; maxX = 200; maxY = 100;
    }

    // Add clean symmetric padding around signature
    const pad = 14.0;
    final strokeW = maxX - minX;
    final strokeH = maxY - minY;

    final outWidth = max(24.0, strokeW + pad * 2);
    final outHeight = max(24.0, strokeH + pad * 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Shift canvas origin so cropped signature has exactly equal padding on all sides
    final extraX = (outWidth - (strokeW + pad * 2)) / 2.0;
    final extraY = (outHeight - (strokeH + pad * 2)) / 2.0;
    canvas.translate(-minX + pad + extraX, -minY + pad + extraY);

    // Deep smooth pen ink rendering with Bezier curves
    final strokePaint = Paint()
      ..color = _penColor
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = _penColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    for (final line in _lines) {
      if (line.isEmpty) continue;
      if (line.length == 1) {
        canvas.drawCircle(line.first, _strokeWidth / 2, dotPaint);
      } else if (line.length == 2) {
        canvas.drawLine(line[0], line[1], strokePaint);
      } else {
        final path = Path();
        path.moveTo(line[0].dx, line[0].dy);
        for (int i = 1; i < line.length - 1; i++) {
          final p0 = line[i];
          final p1 = line[i + 1];
          final midX = (p0.dx + p1.dx) / 2.0;
          final midY = (p0.dy + p1.dy) / 2.0;
          path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
        }
        path.lineTo(line.last.dx, line.last.dy);
        canvas.drawPath(path, strokePaint);
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
        var rawBytes = res.files.first.bytes!;
        try {
          final decoded = img.decodeImage(rawBytes);
          if (decoded != null) {
            img.Image trimmed;
            if (decoded.hasAlpha) {
              trimmed = img.trim(decoded, mode: img.TrimMode.transparent, padding: 8);
            } else {
              trimmed = img.trim(decoded, mode: img.TrimMode.topLeftColor, fuzzy: 0.08, padding: 8);
            }
            if (trimmed.width > 0 && trimmed.height > 0) {
              rawBytes = Uint8List.fromList(img.encodePng(trimmed));
            }
          }
        } catch (_) {}
        final b64 = base64Encode(rawBytes);
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.draw_rounded, color: AppTheme.primaryNavy, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'التوقيع الرقمي: ${widget.role}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark),
                              maxLines: 1,
                            ),
                          ),
                          if (widget.signerName.isNotEmpty)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'المعتمد: ${widget.signerName}',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                maxLines: 1,
                              ),
                            ),
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

                // Pen Controls: Color & Stroke Width
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'سُمك الخط:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          const SizedBox(width: 6),
                          _buildWidthPill(2.8, 'رفيع'),
                          const SizedBox(width: 4),
                          _buildWidthPill(3.6, 'معياري'),
                          const SizedBox(width: 4),
                          _buildWidthPill(4.8, 'عريض'),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'لون الحبر:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          const SizedBox(width: 6),
                          _buildColorDot(const Color(0xFF0A369D), 'أزرق ملكي'),
                          const SizedBox(width: 6),
                          _buildColorDot(const Color(0xFF1E293B), 'أسود رسمي'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Canvas Area (Enhanced height 220dp with natural bezier curves)
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderSubtle, width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      // Subtle guide baseline
                      Positioned(
                        bottom: 50,
                        left: 24,
                        right: 24,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'خط توقيع ${widget.role}',
                                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_lines.isEmpty && _existingBytes != null && !_existingDismissed)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: Image.memory(_existingBytes!, height: 95, fit: BoxFit.contain),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                              Icon(Icons.gesture_rounded, color: AppTheme.textMuted.withValues(alpha: 0.4), size: 32),
                              const SizedBox(height: 6),
                              Text(
                                'قم بالتوقيع هنا بإصبعك أو القلم الرقمي',
                                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'المنحنيات الانسيابية الذكية مفعّلة تلقائياً',
                                style: TextStyle(fontSize: 10, color: AppTheme.textMuted.withValues(alpha: 0.5)),
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
                          painter: _SignatureCanvasPainter(
                            _lines,
                            penColor: _penColor,
                            strokeWidth: _strokeWidth,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Auxiliary Actions: Image Pick / Clear Existing
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.brandCyan,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('إرفاق صورة توقيع', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: _pickSignatureImage,
                    ),
                    if (widget.onCleared != null || (_existingBytes != null && !_existingDismissed))
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.statusRejected,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('حذف التوقيع', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          widget.onCleared?.call();
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Primary Bottom Controls Row: Clear, Undo, Save
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        side: const BorderSide(color: AppTheme.borderSubtle),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      label: const Text('مسح', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _lines.clear();
                          _existingDismissed = true;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textMuted,
                        side: const BorderSide(color: AppTheme.borderSubtle),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('تراجع', style: TextStyle(fontSize: 12)),
                      onPressed: _lines.isNotEmpty
                          ? () {
                              HapticFeedback.lightImpact();
                              setState(() => _lines.removeLast());
                            }
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: const Text(
                          'اعتماد التوقيع',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _exportSignature();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color, String tooltip) {
    final isSelected = _penColor == color;
    return GestureDetector(
      onTap: () => setState(() => _penColor = color),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppTheme.solarGold : Colors.white,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: isSelected
              ? const Center(
                  child: Icon(Icons.check, size: 12, color: Colors.white),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildWidthPill(double width, String label) {
    final isSelected = (_strokeWidth - width).abs() < 0.2;
    return GestureDetector(
      onTap: () => setState(() => _strokeWidth = width),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNavy : AppTheme.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _SignatureCanvasPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final Color penColor;
  final double strokeWidth;

  _SignatureCanvasPainter(
    this.lines, {
    this.penColor = const Color(0xFF0A369D),
    this.strokeWidth = 3.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = penColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = penColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.length == 1) {
        canvas.drawCircle(line.first, strokeWidth / 2, dotPaint);
      } else if (line.length == 2) {
        canvas.drawLine(line[0], line[1], strokePaint);
      } else {
        // Natural smooth Quadratic Bezier curve interpolation
        final path = Path();
        path.moveTo(line[0].dx, line[0].dy);
        for (int i = 1; i < line.length - 1; i++) {
          final p0 = line[i];
          final p1 = line[i + 1];
          final midX = (p0.dx + p1.dx) / 2.0;
          final midY = (p0.dy + p1.dy) / 2.0;
          path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
        }
        path.lineTo(line.last.dx, line.last.dy);
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureCanvasPainter oldDelegate) => true;
}
