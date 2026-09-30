import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inspection_item.dart';
import '../../../services/preset_notes_service.dart';

class InspectionTableWidget extends StatefulWidget {
  final InspectionGroup group;
  final ValueChanged<InspectionGroup> onChanged;

  const InspectionTableWidget({
    super.key,
    required this.group,
    required this.onChanged,
  });

  @override
  State<InspectionTableWidget> createState() => _InspectionTableWidgetState();
}

class _InspectionTableWidgetState extends State<InspectionTableWidget> {
  InspectionStatus? _filterStatus;
  int _notesRevision = 0;

  void _updateItem(int index, InspectionItem updated) {
    final newItems = List<InspectionItem>.from(widget.group.items);
    newItems[index] = updated;
    widget.onChanged(widget.group.copyWith(items: newItems));
  }

  void _setAllStatus(InspectionStatus status) {
    final newItems = widget.group.items.map((i) => i.copyWith(status: status)).toList();
    widget.onChanged(widget.group.copyWith(items: newItems));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تعيين جميع البنود إلى: ${status.labelAr}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.group.items;
    final displayedItems = _filterStatus == null
        ? items
        : items.where((i) => i.status == _filterStatus).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title, count, and fast actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.group.groupNumber}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.group.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Fast Bulk Action Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.tune, size: 18, color: AppTheme.primaryNavy),
                tooltip: 'إجراءات سريعة',
                onSelected: (val) {
                  if (val == 'all_good') _setAllStatus(InspectionStatus.good);
                  if (val == 'all_acceptable') _setAllStatus(InspectionStatus.acceptable);
                  if (val == 'filter_issues') {
                    setState(() {
                      _filterStatus = _filterStatus == null ? InspectionStatus.needsFollowup : null;
                    });
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'all_good',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.statusGood, size: 18),
                        SizedBox(width: 8),
                        Text('تعيين الكل: جيد'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'all_acceptable',
                    child: Row(
                      children: [
                        Icon(Icons.thumb_up, color: AppTheme.statusAcceptable, size: 18),
                        SizedBox(width: 8),
                        Text('تعيين الكل: مقبول'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'filter_issues',
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, size: 18),
                        const SizedBox(width: 8),
                        Text(_filterStatus == null ? 'عرض ما يحتاج متابعة فقط' : 'عرض جميع البنود'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Inspection Items
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          primary: false,
          itemCount: displayedItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final item = displayedItems[idx];
            final realIndex = items.indexOf(item);

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
                        child: Text(
                          '${item.serialNo}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.primaryNavy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.subcategory != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.inventory_2_outlined, size: 10, color: Color(0xFF1D4ED8)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          item.subcategory!,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Text(
                              item.description,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Status Chips (Ultra-Fast & Stable Custom Chips)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    child: Row(
                      children: InspectionStatus.values
                          .where((s) => s != InspectionStatus.uninspected)
                          .map((st) {
                        final isSelected = item.status == st;
                        return _buildStatusChip(
                          status: st,
                          isSelected: isSelected,
                          onTap: () => _updateItem(realIndex, item.copyWith(status: st)),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Notes input
                  TextFormField(
                    key: ValueKey('${item.id}_r$_notesRevision'),
                    initialValue: item.notes,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'ملاحظات الفحص على هذا البند...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: Icon(Icons.edit_note, size: 18, color: AppTheme.textMuted),
                    ),
                    onChanged: (val) {
                      _updateItem(realIndex, item.copyWith(notes: val));
                    },
                  ),
                  const SizedBox(height: 6),
                  // Quick suggestion chips row
                  Builder(
                    builder: (context) {
                      final quickList = PresetNotesService.getContextualDefaults(
                        questionId: item.id,
                        subcategory: item.subcategory,
                        description: item.description,
                      );
                      final displayChips = {
                        if (quickList.isNotEmpty) ...quickList.take(3),
                        'سليم 100%',
                        'تم الفحص والمعاينة',
                        'لا توجد ملاحظات',
                        'يحتاج متابعة',
                      }.toList();

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        primary: false,
                        child: Row(
                          children: displayChips.map((phrase) {
                            final isSelected = item.notes.contains(phrase);
                            return _buildQuickPhraseChip(
                              phrase: phrase,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() => _notesRevision++);
                                final current = item.notes.trim();
                                final newNotes = current.isEmpty
                                    ? phrase
                                    : (current.contains(phrase) ? current : '$current - $phrase');
                                _updateItem(realIndex, item.copyWith(notes: newNotes));
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        // Bottom Group Quick Phrases Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'صف شرائح الجمل السريعة للجدول:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                child: Row(
                  children: [
                    'سليم 100% وخالٍ من أي عيوب',
                    'تمت الصيانة الوقائية والشد بنجاح',
                    'تم الفحص والمطابقة مع المواصفات الفنية',
                    'يحتاج متابعة وصيانة في الزيارة القادمة',
                    'غير متوفر بالموقع (غير منطبق)',
                  ].map((phrase) {
                    return _buildQuickPhraseChip(
                      phrase: phrase,
                      isSelected: false,
                      customIcon: Icons.add_circle_outline,
                      customIconColor: AppTheme.brandCyan,
                      onTap: () {
                        // Apply to the first unannotated item or notify
                        final unannotatedIdx = items.indexWhere((it) => it.notes.trim().isEmpty);
                        if (unannotatedIdx != -1) {
                          _updateItem(unannotatedIdx, items[unannotatedIdx].copyWith(notes: phrase));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمت إضافة "$phrase" للبند رقم ${items[unannotatedIdx].serialNo}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('جميع البنود تحتوي على ملاحظات بالفعل: "$phrase"'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  (Color bg, Color fg) _getStatusColors(InspectionStatus s, bool isSelected) {
    switch (s) {
      case InspectionStatus.good:
        return isSelected
            ? (const Color(0xFFECFDF5), const Color(0xFF065F46))
            : (const Color(0xFFF8FAFC), const Color(0xFF64748B));
      case InspectionStatus.acceptable:
        return isSelected
            ? (const Color(0xFFE0F2FE), const Color(0xFF0369A1))
            : (const Color(0xFFF8FAFC), const Color(0xFF64748B));
      case InspectionStatus.needsFollowup:
        return isSelected
            ? (const Color(0xFFFFFBEB), const Color(0xFFB45309))
            : (const Color(0xFFF8FAFC), const Color(0xFF64748B));
      case InspectionStatus.rejected:
        return isSelected
            ? (const Color(0xFFFEF2F2), const Color(0xFFB91C1C))
            : (const Color(0xFFF8FAFC), const Color(0xFF64748B));
      case InspectionStatus.notApplicable:
      case InspectionStatus.uninspected:
        return isSelected
            ? (const Color(0xFFF1F5F9), const Color(0xFF334155))
            : (const Color(0xFFF8FAFC), const Color(0xFF64748B));
    }
  }

  Widget _buildStatusChip({
    required InspectionStatus status,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final (bg, fg) = _getStatusColors(status, isSelected);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 44, minWidth: 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? fg : const Color(0xFFE2E8F0),
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: 15, color: fg),
                const SizedBox(width: 5),
                Text(
                  status.labelAr,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPhraseChip({
    required String phrase,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? customIcon,
    Color? customIconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: isSelected ? AppTheme.statusGood.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.statusGood.withValues(alpha: 0.4) : AppTheme.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  customIcon ?? (isSelected ? Icons.check : Icons.add),
                  size: 13,
                  color: customIconColor ?? (isSelected ? AppTheme.statusGood : AppTheme.brandCyan),
                ),
                const SizedBox(width: 4),
                Text(
                  phrase,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primaryNavy : AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
