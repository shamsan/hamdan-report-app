import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
    );
    onChanged([...photos, newPhoto]);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة الصورة باتجاه ${detectedLandscape ? "أفقي (عرض كامل)" : "عمودي (نصف صفحة)"} — يمكنك تغييره مباشرة',
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

  Future<void> _toggleOrientation(BuildContext context, int index) async {
    final current = photos[index];
    await _setOrientation(context, index, !current.isLandscape);
  }

  Future<void> _setOrientation(BuildContext context, int index, bool isLandscape) async {
    final list = List<ReportPhoto>.from(photos);
    final current = list[index];
    if (current.isLandscape == isLandscape) return;

    final bytes = await current.getBytes();
    if (bytes != null && bytes.isNotEmpty) {
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final isActuallyLandscape = decoded.width > decoded.height;
          if (isLandscape != isActuallyLandscape) {
            // Physically rotate image 90° so it actually matches the requested orientation!
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

            list[index] = current.copyWith(
              filePath: savedPath,
              base64Data: savedPath != null ? '' : base64Encode(newBytes),
              isLandscape: isLandscape,
            );
            onChanged(list);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isLandscape
                        ? 'تم تدوير الصورة وعرضها أفقياً'
                        : 'تم تدوير الصورة وعرضها عمودياً',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('[ReportCraft] Failed to rotate in _setOrientation: $e');
      }
    }

    list[index] = current.copyWith(isLandscape: isLandscape);
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
    bool isLandscape = p.isLandscape;

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
                Text('تفاصيل الصورة والاتجاه', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                  const Text('طريقة العرض في تقرير الـ PDF:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.crop_portrait_rounded, size: 16),
                              SizedBox(width: 4),
                              Text('عمودي (نصف صفحة)', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          selected: !isLandscape,
                          selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.15),
                          onSelected: (val) {
                            if (val) setState(() => isLandscape = false);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.crop_landscape_rounded, size: 16),
                              SizedBox(width: 4),
                              Text('أفقي (عرض كامل)', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                          selected: isLandscape,
                          selectedColor: AppTheme.brandCyan.withValues(alpha: 0.2),
                          onSelected: (val) {
                            if (val) setState(() => isLandscape = true);
                          },
                        ),
                      ),
                    ],
                  ),
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
                onPressed: () async {
                  final list = List<ReportPhoto>.from(photos);
                  ReportPhoto updated = p.copyWith(
                    title: titleCtrl.text.trim(),
                    caption: captionCtrl.text.trim(),
                    location: locationCtrl.text.trim(),
                    isLandscape: isLandscape,
                  );

                  if (p.isLandscape != isLandscape) {
                    final bytes = await p.getBytes();
                    if (bytes != null && bytes.isNotEmpty) {
                      try {
                        final decoded = img.decodeImage(bytes);
                        if (decoded != null && (decoded.width > decoded.height) != isLandscape) {
                          final rotated = img.copyRotate(decoded, angle: 90);
                          final newBytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 85));
                          String? savedPath = p.filePath;
                          if (savedPath != null && savedPath.isNotEmpty) {
                            final f = File(savedPath);
                            await f.writeAsBytes(newBytes);
                            await FileImage(f).evict();
                          }
                          PaintingBinding.instance.imageCache.clear();
                          PaintingBinding.instance.imageCache.clearLiveImages();
                          updated = updated.copyWith(
                            filePath: savedPath,
                            base64Data: savedPath != null ? '' : base64Encode(newBytes),
                          );
                        }
                      } catch (_) {}
                    }
                  }

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
    final landscapeCount = photos.where((p) => p.isLandscape).length;
    final portraitCount = photos.length - landscapeCount;

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
                          ? 'تظهر في ملحق التقرير: $landscapeCount أفقي (عرض كامل) • $portraitCount عمودي (شبكي)'
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
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: p.isLandscape ? AppTheme.brandCyan.withValues(alpha: 0.4) : AppTheme.borderSubtle,
                      width: p.isLandscape ? 1.5 : 1,
                    ),
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
                      // Photo Preview
                      SizedBox(
                        height: p.isLandscape ? 200 : 170,
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
                                        key: ValueKey('${p.filePath}_${p.isLandscape}'),
                                      );
                                    }
                                  }
                                  if (p.base64Data.isNotEmpty) {
                                    try {
                                      return Image.memory(
                                        base64Decode(p.base64Data),
                                        fit: BoxFit.contain,
                                        key: ValueKey('${p.id}_${p.isLandscape}'),
                                      );
                                    } catch (_) {}
                                  }
                                  return const Center(
                                    child: Icon(Icons.broken_image_outlined, size: 36, color: AppTheme.textMuted),
                                  );
                                }),
                              ),
                            ),
                            // Top overlay: Orientation Badge (Right) & Delete Button (Left)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () => _toggleOrientation(context, idx),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: p.isLandscape ? AppTheme.brandCyan : AppTheme.primaryNavy,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        p.isLandscape ? Icons.crop_landscape_rounded : Icons.crop_portrait_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        p.isLandscape ? 'أفقي (عرض أفقي عريض)' : 'عمودي (عرض رأسي)',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.sync_alt, size: 12, color: Colors.white70),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: 'تدوير 90°',
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _rotatePhoto(context, idx),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.rotate_right_rounded, size: 18, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'حذف الصورة',
                                    child: Material(
                                      color: Colors.black54,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _deletePhoto(idx),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white),
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
                      // Orientation Segmented Selector Bar
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _setOrientation(context, idx, false),
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(vertical: 6.5),
                                  decoration: BoxDecoration(
                                    color: !p.isLandscape ? AppTheme.primaryNavy : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: !p.isLandscape
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.crop_portrait_rounded,
                                        size: 15,
                                        color: !p.isLandscape ? Colors.white : AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'عمودي (عرض رأسي)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: !p.isLandscape ? FontWeight.bold : FontWeight.normal,
                                          color: !p.isLandscape ? Colors.white : AppTheme.textDark,
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
                                onTap: () => _setOrientation(context, idx, true),
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(vertical: 6.5),
                                  decoration: BoxDecoration(
                                    color: p.isLandscape ? AppTheme.brandCyan : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: p.isLandscape
                                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.crop_landscape_rounded,
                                        size: 15,
                                        color: p.isLandscape ? Colors.white : AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'أفقي (عرض أفقي عريض)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: p.isLandscape ? FontWeight.bold : FontWeight.normal,
                                          color: p.isLandscape ? Colors.white : AppTheme.textDark,
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
