import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../../core/theme/app_theme.dart';
import '../../../models/report_photo.dart';
import '../../../services/camera_service.dart';
import '../../../services/storage_service.dart';

class PhotoSectionWidget extends StatelessWidget {
  final String reportId;
  final List<ReportPhoto> photos;
  final ValueChanged<List<ReportPhoto>> onChanged;

  const PhotoSectionWidget({
    super.key,
    this.reportId = '',
    required this.photos,
    required this.onChanged,
  });

  Future<void> _processAndAddPhoto(BuildContext context, Uint8List rawBytes) async {
    Uint8List processedBytes = rawBytes;
    bool detectedLandscape = false;
    try {
      // Compress and resize image to prevent memory exhaustion on mobile
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        detectedLandscape = decoded.width > decoded.height;
        img.Image resized = decoded;
        if (decoded.width > 1280 || decoded.height > 1280) {
          if (decoded.width > decoded.height) {
            resized = img.copyResize(decoded, width: 1280);
          } else {
            resized = img.copyResize(decoded, height: 1280);
          }
        }
        processedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
      }
    } catch (e) {
      debugPrint('[ReportCraft] Image compression fallback: $e');
    }

    final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
    // Save photo physically to disk in app's photos directory to avoid memory bloat
    String? savedPath;
    try {
      savedPath = await StorageService().savePhotoFile(
        reportId: reportId.isNotEmpty ? reportId : 'temp',
        bytes: processedBytes,
      );
    } catch (e) {
      debugPrint('[ReportCraft] Failed to save photo to disk, falling back: $e');
    }

    final newPhoto = ReportPhoto(
      id: photoId,
      filePath: savedPath,
      base64Data: savedPath != null ? '' : base64Encode(processedBytes),
      title: 'صورة توثيقية ${photos.length + 1}',
      caption: 'معاينة وفحص منظومة الطاقة الشمسية الميدانية',
      location: 'غرفة المنظومة / موقع الألواح',
      timestamp: DateTime.now().toString().substring(0, 16),
      isLandscape: detectedLandscape,
      displaySize: detectedLandscape ? PhotoDisplaySize.fullWidth : PhotoDisplaySize.halfWidth,
    );
    onChanged([...photos, newPhoto]);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة الصورة بنمط ${detectedLandscape ? "عرض كامل (100%)" : "مزدوج (50%)"} — يمكنك تغيير نمطها أو مقارنتها مباشرة',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _captureFromCamera(BuildContext context) async {
    try {
      final bytes = await CameraService.capturePhotoFromCamera();
      if (bytes != null && context.mounted) {
        await _processAndAddPhoto(context, bytes);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التقاط الصورة بالكاميرا: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final bytes = await CameraService.pickImageFromGallery();
      if (bytes != null && context.mounted) {
        await _processAndAddPhoto(context, bytes);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اختيار الصورة من المعرض: $e')),
        );
      }
    }
  }

  void _showAddPhotoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إضافة صورة توثيقية للملحق',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text('التقاط فوري بالكاميرا', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _captureFromCamera(context);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brandCyan,
                  side: const BorderSide(color: AppTheme.brandCyan),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('اختيار من ألبوم الصور (الاستوديو)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickFromGallery(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deletePhoto(int index) {
    final list = List<ReportPhoto>.from(photos);
    final removed = list.removeAt(index);
    if (removed.filePath != null && removed.filePath!.isNotEmpty) {
      try {
        final f = File(removed.filePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    onChanged(list);
  }

  void _movePhotoUp(int index) {
    if (index <= 0) return;
    final list = List<ReportPhoto>.from(photos);
    final item = list.removeAt(index);
    list.insert(index - 1, item);
    onChanged(list);
  }

  void _movePhotoDown(int index) {
    if (index >= photos.length - 1) return;
    final list = List<ReportPhoto>.from(photos);
    final item = list.removeAt(index);
    list.insert(index + 1, item);
    onChanged(list);
  }

  void _setWidthFactor(int index, double factor) {
    final list = List<ReportPhoto>.from(photos);
    final current = list[index];
    final clampedFactor = factor.clamp(0.33, 1.0);

    PhotoDisplaySize newDisplay;
    if (clampedFactor >= 0.85) {
      newDisplay = PhotoDisplaySize.fullWidth;
    } else if (clampedFactor <= 0.40) {
      newDisplay = PhotoDisplaySize.compact;
    } else {
      newDisplay = PhotoDisplaySize.halfWidth;
    }

    if (current.displaySize == PhotoDisplaySize.beforeAfter && clampedFactor < 0.85) {
      newDisplay = PhotoDisplaySize.beforeAfter;
    }

    list[index] = current.copyWith(
      widthFactor: clampedFactor,
      displaySize: newDisplay,
      isLandscape: newDisplay == PhotoDisplaySize.fullWidth,
    );
    onChanged(list);
  }

  void _toggleBeforeAfter(int index) {
    HapticFeedback.lightImpact();
    final list = List<ReportPhoto>.from(photos);
    final current = list[index];
    final isBA = current.displaySize == PhotoDisplaySize.beforeAfter;
    if (isBA) {
      list[index] = current.copyWith(
        displaySize: PhotoDisplaySize.halfWidth,
        widthFactor: 0.5,
        beforeAfterStage: 'none',
      );
    } else {
      list[index] = current.copyWith(
        displaySize: PhotoDisplaySize.beforeAfter,
        widthFactor: 0.5,
        beforeAfterStage: current.beforeAfterStage == 'none' || current.beforeAfterStage.isEmpty ? 'before' : current.beforeAfterStage,
      );
    }
    onChanged(list);
  }

  void _setBeforeAfterStage(int index, String stage) {
    final list = List<ReportPhoto>.from(photos);
    final current = list[index];
    list[index] = current.copyWith(
      displaySize: PhotoDisplaySize.beforeAfter,
      beforeAfterStage: stage,
    );
    onChanged(list);
  }

  Future<void> _rotatePhoto(BuildContext context, int index) async {
    final list = List<ReportPhoto>.from(photos);
    final current = list[index];
    final bytes = await current.getBytes();
    if (bytes == null || bytes.isEmpty) return;

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      // Rotate 90 degrees clockwise
      final rotated = img.copyRotate(decoded, angle: 90);
      final newBytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 85));

      String? savedPath = current.filePath;
      if (savedPath != null && savedPath.isNotEmpty) {
        final f = File(savedPath);
        await f.writeAsBytes(newBytes);
        await FileImage(f).evict();
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Automatically flip orientation to match the new image aspect ratio
      final newIsLandscape = rotated.width > rotated.height;

      list[index] = current.copyWith(
        filePath: savedPath,
        base64Data: savedPath != null ? '' : base64Encode(newBytes),
        isLandscape: newIsLandscape,
      );
      onChanged(list);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تدوير الصورة 90° (${newIsLandscape ? "أفقياً" : "عمودياً"})',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ReportCraft] Failed to rotate photo: $e');
    }
  }

  void _editPhotoDetails(BuildContext context, int index) {
    final p = photos[index];
    final titleCtrl = TextEditingController(text: p.title);
    final captionCtrl = TextEditingController(text: p.caption);
    final locationCtrl = TextEditingController(text: p.location);
    PhotoDisplaySize displaySize = p.displaySize;
    String beforeAfterStage = p.beforeAfterStage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppTheme.primaryNavy),
                SizedBox(width: 8),
                Text('تفاصيل الصورة وتنسيق العرض', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'عنوان الصورة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: captionCtrl,
                    decoration: const InputDecoration(labelText: 'الوصف / البيان التوثيقي'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'الموقع الميداني'),
                  ),
                  const SizedBox(height: 14),
                  const Text('حجم ونمط العرض في التقرير:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.view_column_rounded, size: 16),
                        label: const Text('مزدوج (50%)'),
                        selected: displaySize == PhotoDisplaySize.halfWidth,
                        selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.15),
                        onSelected: (val) {
                          if (val) setState(() => displaySize = PhotoDisplaySize.halfWidth);
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.crop_landscape_rounded, size: 16),
                        label: const Text('عرض كامل (100%)'),
                        selected: displaySize == PhotoDisplaySize.fullWidth,
                        selectedColor: AppTheme.brandCyan.withValues(alpha: 0.2),
                        onSelected: (val) {
                          if (val) setState(() => displaySize = PhotoDisplaySize.fullWidth);
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.view_week_rounded, size: 16),
                        label: const Text('مصغر (33%)'),
                        selected: displaySize == PhotoDisplaySize.compact,
                        selectedColor: Colors.deepPurple.withValues(alpha: 0.15),
                        onSelected: (val) {
                          if (val) setState(() => displaySize = PhotoDisplaySize.compact);
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.compare_arrows_rounded, size: 16),
                        label: const Text('مقارنة (قبل / بعد)'),
                        selected: displaySize == PhotoDisplaySize.beforeAfter,
                        selectedColor: Colors.orange.withValues(alpha: 0.2),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              displaySize = PhotoDisplaySize.beforeAfter;
                              if (beforeAfterStage == 'none') beforeAfterStage = 'before';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (displaySize == PhotoDisplaySize.beforeAfter) ...[
                    const SizedBox(height: 12),
                    const Text('مرحلة التوثيق للمقارنة:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                            label: const Text('قبل الصيانة', style: TextStyle(fontSize: 11)),
                            selected: beforeAfterStage == 'before',
                            selectedColor: Colors.orange.withValues(alpha: 0.25),
                            onSelected: (val) {
                              if (val) setState(() => beforeAfterStage = 'before');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            avatar: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                            label: const Text('بعد الصيانة', style: TextStyle(fontSize: 11)),
                            selected: beforeAfterStage == 'after',
                            selectedColor: Colors.green.withValues(alpha: 0.25),
                            onSelected: (val) {
                              if (val) setState(() => beforeAfterStage = 'after');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
                onPressed: () {
                  final list = List<ReportPhoto>.from(photos);
                  ReportPhoto updated = p.copyWith(
                    title: titleCtrl.text.trim(),
                    caption: captionCtrl.text.trim(),
                    location: locationCtrl.text.trim(),
                    displaySize: displaySize,
                    isLandscape: displaySize == PhotoDisplaySize.fullWidth,
                    beforeAfterStage: displaySize == PhotoDisplaySize.beforeAfter ? beforeAfterStage : 'none',
                  );
                  list[index] = updated;
                  onChanged(list);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullWidthCount = photos.where((p) => p.displaySize == PhotoDisplaySize.fullWidth).length;
    final compactCount = photos.where((p) => p.displaySize == PhotoDisplaySize.compact).length;
    final beforeAfterCount = photos.where((p) => p.displaySize == PhotoDisplaySize.beforeAfter).length;
    final halfWidthCount = photos.length - fullWidthCount - compactCount - beforeAfterCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryNavy, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الصور والتوثيق الميداني للموقع (${photos.length})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.textDark),
                    ),
                    Text(
                      photos.isNotEmpty
                          ? 'أنماط العرض: $halfWidthCount مزدوج • $fullWidthCount عريض • $compactCount مصغر • $beforeAfterCount مقارنة'
                          : 'تظهر كافة الصور في ملحق التقرير المعتمد لتأكيد حالة المنظومة',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                label: const Text('إضافة صورة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddPhotoSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (photos.isEmpty)
            InkWell(
              onTap: () => _showAddPhotoSheet(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                    const SizedBox(height: 8),
                    const Text(
                      'لم يتم إرفاق أي صور بعد',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'اضغط هنا أو على زر "إضافة صورة" لاختيار صور المنظومة من الكاميرا أو المعرض.\nيدعم التقرير إضافة عدد غير محدود من الصور وتوزيعها على صفحات الملحق تلقائياً.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photos.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final p = photos[idx];
                final isBeforeAfter = p.displaySize == PhotoDisplaySize.beforeAfter;
                final isFullWidth = p.displaySize == PhotoDisplaySize.fullWidth;
                final isCompact = p.displaySize == PhotoDisplaySize.compact;

                Color borderColor;
                double borderWidth = 1.0;
                if (isBeforeAfter) {
                  if (p.beforeAfterStage == 'after') {
                    borderColor = Colors.green.shade600;
                    borderWidth = 1.6;
                  } else {
                    borderColor = Colors.orange.shade700;
                    borderWidth = 1.6;
                  }
                } else if (isFullWidth) {
                  borderColor = AppTheme.brandCyan;
                  borderWidth = 1.5;
                } else if (isCompact) {
                  borderColor = Colors.deepPurple.shade300;
                  borderWidth = 1.2;
                } else {
                  borderColor = AppTheme.borderSubtle;
                }

                // Determine badge style
                Color badgeColor;
                IconData badgeIcon;
                String badgeText;
                switch (p.displaySize) {
                  case PhotoDisplaySize.fullWidth:
                    badgeColor = AppTheme.brandCyan;
                    badgeIcon = Icons.crop_landscape_rounded;
                    badgeText = 'عرض كامل 100%';
                    break;
                  case PhotoDisplaySize.compact:
                    badgeColor = Colors.deepPurple;
                    badgeIcon = Icons.view_week_rounded;
                    badgeText = 'مصغر 33%';
                    break;
                  case PhotoDisplaySize.beforeAfter:
                    if (p.beforeAfterStage == 'after') {
                      badgeColor = Colors.green.shade700;
                      badgeIcon = Icons.check_circle_rounded;
                      badgeText = 'بعد الصيانة ✅';
                    } else {
                      badgeColor = Colors.orange.shade800;
                      badgeIcon = Icons.warning_amber_rounded;
                      badgeText = 'قبل الصيانة ⚠️';
                    }
                    break;
                  case PhotoDisplaySize.halfWidth:
                    badgeColor = AppTheme.primaryNavy;
                    badgeIcon = Icons.view_column_rounded;
                    badgeText = 'مزدوج 50%';
                    break;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Preview with Live Dynamic Scaling
                      SizedBox(
                        height: 145.0 + ((p.widthFactor.clamp(0.33, 1.0) - 0.33) / 0.67) * 75.0,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: const Color(0xFF0F172A),
                              child: Center(
                                child: Builder(builder: (context) {
                                  if (p.filePath != null && p.filePath!.isNotEmpty) {
                                    final file = File(p.filePath!);
                                    if (file.existsSync()) {
                                      return Image.file(
                                        file,
                                        fit: BoxFit.contain,
                                        key: ValueKey('${p.filePath}_${p.displaySize.name}_${p.beforeAfterStage}_${p.widthFactor}'),
                                      );
                                    }
                                  }
                                  if (p.base64Data.isNotEmpty) {
                                    try {
                                      return Image.memory(
                                        base64Decode(p.base64Data),
                                        fit: BoxFit.contain,
                                        key: ValueKey('${p.id}_${p.displaySize.name}_${p.beforeAfterStage}_${p.widthFactor}'),
                                      );
                                    } catch (_) {}
                                  }
                                  return const Center(
                                    child: Icon(Icons.broken_image_outlined, size: 36, color: AppTheme.textMuted),
                                  );
                                }),
                              ),
                            ),
                            // Top overlay: Display Mode Badge on Right
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(badgeIcon, size: 13, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      badgeText,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Top overlay: Actions & Reordering on Left
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (idx > 0)
                                    Tooltip(
                                      message: 'تقديم الصورة للأعلى',
                                      child: Material(
                                        color: Colors.black54,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => _movePhotoUp(idx),
                                          child: const Padding(
                                            padding: EdgeInsets.all(5),
                                            child: Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (idx > 0 && idx < photos.length - 1)
                                    const SizedBox(width: 4),
                                  if (idx < photos.length - 1)
                                    Tooltip(
                                      message: 'تأخير الصورة للأسفل',
                                      child: Material(
                                        color: Colors.black54,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () => _movePhotoDown(idx),
                                          child: const Padding(
                                            padding: EdgeInsets.all(5),
                                            child: Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message: 'تدوير 90°',
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _rotatePhoto(context, idx),
                                        child: const Padding(
                                          padding: EdgeInsets.all(5),
                                          child: Icon(Icons.rotate_right_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message: 'حذف الصورة',
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _deletePhoto(idx),
                                        child: const Padding(
                                          padding: EdgeInsets.all(5),
                                          child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Interactive Drag Sizer Panel
                      Container(
                        margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            // Top Row: Drag Title, Live Percentage Badge & Before/After Toggle
                            Row(
                              children: [
                                const Icon(Icons.open_in_full_rounded, size: 14, color: AppTheme.primaryNavy),
                                const SizedBox(width: 6),
                                const Text(
                                  'تحجيم بالسحب:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${(p.widthFactor * 100).round()}%',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor),
                                  ),
                                ),
                                const Spacer(),
                                // Quick Before/After Comparison Mode Toggle
                                InkWell(
                                  onTap: () => _toggleBeforeAfter(idx),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isBeforeAfter ? Colors.orange.shade50 : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isBeforeAfter ? Colors.orange.shade800 : AppTheme.borderSubtle,
                                        width: isBeforeAfter ? 1.4 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.compare_arrows_rounded,
                                          size: 13,
                                          color: isBeforeAfter ? Colors.orange.shade900 : AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'مقارنة قبل/بعد',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: isBeforeAfter ? FontWeight.bold : FontWeight.normal,
                                            color: isBeforeAfter ? Colors.orange.shade900 : AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Interactive Drag Slider with Live Feedback & Snapping
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 5,
                                activeTrackColor: AppTheme.primaryNavy,
                                inactiveTrackColor: const Color(0xFFCBD5E1),
                                thumbColor: AppTheme.brandCyan,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                                overlayColor: AppTheme.brandCyan.withValues(alpha: 0.2),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                              ),
                              child: Slider(
                                value: p.widthFactor.clamp(0.33, 1.0),
                                min: 0.33,
                                max: 1.0,
                                onChanged: (val) {
                                  // Snapping logic to key engineering ratios
                                  double snappedVal = val;
                                  if ((val - 0.33).abs() < 0.05) {
                                    snappedVal = 0.33;
                                  } else if ((val - 0.50).abs() < 0.05) {
                                    snappedVal = 0.50;
                                  } else if ((val - 0.67).abs() < 0.05) {
                                    snappedVal = 0.67;
                                  } else if (val > 0.88) {
                                    snappedVal = 1.0;
                                  }
                                  _setWidthFactor(idx, snappedVal);
                                },
                              ),
                            ),
                            // Quick Snap Tap Stops
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () => _setWidthFactor(idx, 0.33),
                                    child: Text(
                                      '33% مصغر',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: p.widthFactor <= 0.4 ? FontWeight.bold : FontWeight.normal,
                                        color: p.widthFactor <= 0.4 ? Colors.deepPurple : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _setWidthFactor(idx, 0.50),
                                    child: Text(
                                      '50% مزدوج',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: (p.widthFactor > 0.4 && p.widthFactor <= 0.6) ? FontWeight.bold : FontWeight.normal,
                                        color: (p.widthFactor > 0.4 && p.widthFactor <= 0.6) ? AppTheme.primaryNavy : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _setWidthFactor(idx, 0.67),
                                    child: Text(
                                      '67% بارز',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: (p.widthFactor > 0.6 && p.widthFactor < 0.85) ? FontWeight.bold : FontWeight.normal,
                                        color: (p.widthFactor > 0.6 && p.widthFactor < 0.85) ? AppTheme.primaryNavy : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _setWidthFactor(idx, 1.0),
                                    child: Text(
                                      '100% كامل',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: p.widthFactor >= 0.85 ? FontWeight.bold : FontWeight.normal,
                                        color: p.widthFactor >= 0.85 ? AppTheme.brandCyan : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Direct Horizontal Drag Handle
                            const SizedBox(height: 5),
                            GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                final deltaFactor = details.primaryDelta != null ? details.primaryDelta! / 250.0 : 0.0;
                                final newFactor = (p.widthFactor + deltaFactor).clamp(0.33, 1.0);
                                _setWidthFactor(idx, newFactor);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.drag_indicator_rounded, size: 13, color: AppTheme.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      'اسحب هنا مباشرة لتكبير أو تصغير العرض ↔',
                                      style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Before / After stage sub-bar
                      if (isBeforeAfter)
                        Container(
                          margin: const EdgeInsets.fromLTRB(10, 2, 10, 4),
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _setBeforeAfterStage(idx, 'before'),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: p.beforeAfterStage == 'before' ? Colors.orange.shade800 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 13,
                                          color: p.beforeAfterStage == 'before' ? Colors.white : Colors.orange.shade900,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'قبل الصيانة (Before)',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: p.beforeAfterStage == 'before' ? Colors.white : Colors.orange.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _setBeforeAfterStage(idx, 'after'),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: p.beforeAfterStage == 'after' ? Colors.green.shade700 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 13,
                                          color: p.beforeAfterStage == 'after' ? Colors.white : Colors.green.shade900,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'بعد الصيانة (After)',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: p.beforeAfterStage == 'after' ? Colors.white : Colors.green.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Details and Controls Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title.isNotEmpty ? p.title : 'صورة بدون عنوان',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    p.caption.isNotEmpty ? p.caption : 'لا يوجد وصف مدخل',
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (p.location.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.brandCyan),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            p.location,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.primaryNavy),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Quick Action Buttons
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.rotate_right_rounded, size: 16),
                              label: const Text('تدوير 90°', style: TextStyle(fontSize: 11)),
                              onPressed: () => _rotatePhoto(context, idx),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.edit_note_rounded, size: 16),
                              label: const Text('تعديل', style: TextStyle(fontSize: 11)),
                              onPressed: () => _editPhotoDetails(context, idx),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

