import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inspection_item.dart';
import '../../../models/report.dart';
import '../../../services/camera_service.dart';

class ObservationsSectionWidget extends StatelessWidget {
  final Report report;
  final ValueChanged<Report> onReportUpdated;
  final VoidCallback? onOpenSession;

  const ObservationsSectionWidget({
    super.key,
    required this.report,
    required this.onReportUpdated,
    this.onOpenSession,
  });

  List<({InspectionGroup group, InspectionItem item, int groupIndex, int itemIndex})> get _itemsWithPhotos {
    final list = <({InspectionGroup group, InspectionItem item, int groupIndex, int itemIndex})>[];
    for (int gIdx = 0; gIdx < report.inspectionGroups.length; gIdx++) {
      final group = report.inspectionGroups[gIdx];
      for (int iIdx = 0; iIdx < group.items.length; iIdx++) {
        final item = group.items[iIdx];
        if (item.photoBase64 != null && item.photoBase64!.trim().isNotEmpty) {
          list.add((group: group, item: item, groupIndex: gIdx, itemIndex: iIdx));
        }
      }
    }
    return list;
  }

  void _updateItem(int groupIndex, int itemIndex, InspectionItem updatedItem) {
    final updatedGroups = List<InspectionGroup>.from(report.inspectionGroups);
    final group = updatedGroups[groupIndex];
    final updatedItems = List<InspectionItem>.from(group.items);
    updatedItems[itemIndex] = updatedItem;
    updatedGroups[groupIndex] = group.copyWith(items: updatedItems);

    onReportUpdated(report.copyWith(
      inspectionGroups: updatedGroups,
      updatedAt: DateTime.now(),
    ));
  }

  void _toggleAllIncludeInPdf(bool includeAll) {
    HapticFeedback.lightImpact();
    final updatedGroups = report.inspectionGroups.map((g) {
      final updatedItems = g.items.map((it) {
        if (it.photoBase64 != null && it.photoBase64!.trim().isNotEmpty) {
          return it.copyWith(includeInPdf: includeAll);
        }
        return it;
      }).toList();
      return g.copyWith(items: updatedItems);
    }).toList();

    onReportUpdated(report.copyWith(
      inspectionGroups: updatedGroups,
      showObservationsInReport: includeAll ? true : report.showObservationsInReport,
      updatedAt: DateTime.now(),
    ));
  }

  void _showImagePreviewDialog(BuildContext context, String photoBase64, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.primaryNavy,
              child: Row(
                children: [
                  const Icon(Icons.photo_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.65,
                maxWidth: MediaQuery.sizeOf(context).width * 0.9,
              ),
              child: Image.memory(
                base64Decode(photoBase64),
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق المعاينة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNotesDialog(BuildContext context, int groupIndex, int itemIndex, InspectionItem item) {
    final controller = TextEditingController(text: item.notes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppTheme.primaryNavy, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تعديل ملاحظة البند #${item.serialNo}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.description,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب الملاحظات الفنية للمهندس حول هذا البند...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateItem(groupIndex, itemIndex, item.copyWith(notes: controller.text.trim()));
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('حفظ الملاحظة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsWithPhotos = _itemsWithPhotos;
    final totalPhotos = itemsWithPhotos.length;
    final includedInPdfCount = itemsWithPhotos.where((e) => e.item.includeInPdf).length;
    final isAllIncluded = totalPhotos > 0 && includedInPdfCount == totalPhotos;

    final rejectedCount = itemsWithPhotos.where((e) => e.item.status == InspectionStatus.rejected).length;
    final followupCount = itemsWithPhotos.where((e) => e.item.status == InspectionStatus.needsFollowup).length;
    final acceptableCount = itemsWithPhotos.where((e) => e.item.status == InspectionStatus.acceptable).length;
    final goodCount = itemsWithPhotos.where((e) => e.item.status == InspectionStatus.good).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Master PDF Visibility Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: report.showObservationsInReport
                  ? AppTheme.primaryNavy.withValues(alpha: 0.3)
                  : AppTheme.borderSubtle,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: report.showObservationsInReport
                      ? AppTheme.primaryNavy.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fact_check_rounded,
                  color: report.showObservationsInReport ? AppTheme.primaryNavy : AppTheme.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تضمين سجل توثيق الملاحظات في تقرير الـ PDF',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.showObservationsInReport
                          ? 'سيتم توليد ملحق رسمي (صفحة 14) يعرض صور الأعطال والملاحظات الهندسية لكل بند.'
                          : 'الملحق محجوب من الـ PDF — محفوظ كبيانات داخلية لفريق الصيانة والمتابعة.',
                      style: TextStyle(
                        fontSize: 11,
                        color: report.showObservationsInReport ? AppTheme.brandCyan : AppTheme.textMuted,
                        fontWeight: report.showObservationsInReport ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: report.showObservationsInReport,
                activeThumbColor: AppTheme.solarGold,
                activeTrackColor: AppTheme.primaryNavy,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  onReportUpdated(report.copyWith(
                    showObservationsInReport: val,
                    updatedAt: DateTime.now(),
                  ));
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. Metrics & Bulk Actions Bar
        if (totalPhotos > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.collections_bookmark_rounded, size: 18, color: AppTheme.primaryNavy),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'إجمالي الملاحظات المصورة: $totalPhotos بند ($includedInPdfCount مشمول بالتقرير)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: Icon(
                        isAllIncluded ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: AppTheme.brandCyan,
                      ),
                      label: Text(
                        isAllIncluded ? 'استبعاد الكل' : 'تحديد الكل للـ PDF',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                      ),
                      onPressed: () => _toggleAllIncludeInPdf(!isAllIncluded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatPill('مرفوض / خلل', rejectedCount, const Color(0xFFFEF2F2), const Color(0xFFB91C1C)),
                    _buildStatPill('يحتاج متابعة', followupCount, const Color(0xFFFFFBEB), const Color(0xFFB45309)),
                    _buildStatPill('مقبول', acceptableCount, const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
                    _buildStatPill('سليم / مطابق', goodCount, const Color(0xFFECFDF5), const Color(0xFF065F46)),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // 3. Observations List or Empty State
        if (totalPhotos == 0)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 40,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد صور ملاحظات مسجلة حتى الآن',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'يمكنك التقاط الصور التوثيقية فورياً بالكاميرا أثناء المرور بالأصناف في جلسة الفحص الميداني، وستظهر تلقائياً هنا في هذا السجل.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                if (onOpenSession != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('فتح جلسة الفحص الميداني 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: onOpenSession,
                  ),
                ],
              ],
            ),
          )
        else
          ...itemsWithPhotos.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final itemRecord = entry.value;
            final item = itemRecord.item;
            final group = itemRecord.group;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: item.includeInPdf ? AppTheme.primaryNavy.withValues(alpha: 0.2) : AppTheme.borderSubtle,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card Top: Item Identity & Inclusion Toggle
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$idx',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'بند #${item.serialNo}: ${item.description}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${group.title}${item.subcategory != null ? " • ${item.subcategory}" : ""}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Include in PDF switch
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.includeInPdf ? 'في الـ PDF' : 'مستبعد',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: item.includeInPdf ? AppTheme.primaryNavy : AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Switch.adaptive(
                              value: item.includeInPdf,
                              activeThumbColor: AppTheme.brandCyan,
                              activeTrackColor: AppTheme.primaryNavy.withValues(alpha: 0.3),
                              onChanged: (val) {
                                HapticFeedback.lightImpact();
                                _updateItem(itemRecord.groupIndex, itemRecord.itemIndex, item.copyWith(includeInPdf: val));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Divider(height: 16),

                    // Card Body: Photo Thumbnail + Details & Notes
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo Thumbnail with zoom button
                        GestureDetector(
                          onTap: () => _showImagePreviewDialog(
                            context,
                            item.photoBase64!,
                            'صورة بند #${item.serialNo}: ${item.description}',
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(item.photoBase64!),
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Status & Notes
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Badge
                              _buildStatusBadge(item.status),
                              const SizedBox(height: 8),
                              // Notes box
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: Text(
                                  item.notes.isNotEmpty ? item.notes : 'لا توجد ملاحظات نصية مكتوبة (توثيق فوتوغرافي فقط)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: item.notes.isNotEmpty ? AppTheme.textDark : AppTheme.textMuted,
                                    fontStyle: item.notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Card Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Retake / Replace photo
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.brandCyan,
                            side: const BorderSide(color: AppTheme.borderSubtle),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('استبدال الصورة', style: TextStyle(fontSize: 11.5)),
                          onPressed: () async {
                            final bytes = await CameraService.capturePhotoFromCamera();
                            if (bytes != null) {
                              final b64 = base64Encode(bytes);
                              _updateItem(itemRecord.groupIndex, itemRecord.itemIndex, item.copyWith(photoBase64: b64));
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        // Edit Notes
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryNavy,
                            side: const BorderSide(color: AppTheme.borderSubtle),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 16),
                          label: const Text('تعديل الملاحظة', style: TextStyle(fontSize: 11.5)),
                          onPressed: () => _showEditNotesDialog(context, itemRecord.groupIndex, itemRecord.itemIndex, item),
                        ),
                        const SizedBox(width: 8),
                        // Delete photo button
                        IconButton(
                          tooltip: 'حذف الصورة من البند',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: const Color(0xFFDC2626),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _updateItem(itemRecord.groupIndex, itemRecord.itemIndex, item.copyWith(photoBase64: ''));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStatPill(String label, int count, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(InspectionStatus status) {
    Color bg;
    Color fg;
    IconData icon;
    String text;

    switch (status) {
      case InspectionStatus.good:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        icon = Icons.check_circle_outline;
        text = 'مطابق / سليم';
        break;
      case InspectionStatus.acceptable:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        icon = Icons.thumb_up_alt_outlined;
        text = 'مقبول';
        break;
      case InspectionStatus.needsFollowup:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        icon = Icons.warning_amber_outlined;
        text = 'يحتاج متابعة';
        break;
      case InspectionStatus.rejected:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.cancel_outlined;
        text = 'مرفوض / خلل';
        break;
      case InspectionStatus.notApplicable:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.remove_circle_outline;
        text = 'غير منطبق';
        break;
      case InspectionStatus.uninspected:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        icon = Icons.help_outline;
        text = 'لم يُفحص';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }
}
