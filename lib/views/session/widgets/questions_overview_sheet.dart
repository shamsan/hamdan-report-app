import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inspection_item.dart';
import '../models/session_question.dart';

class QuestionsOverviewSheet extends StatefulWidget {
  final List<SessionQuestion> questions;
  final int currentIndex;
  final ValueChanged<int> onSelectQuestion;

  const QuestionsOverviewSheet({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.onSelectQuestion,
  });

  @override
  State<QuestionsOverviewSheet> createState() => _QuestionsOverviewSheetState();
}

class _QuestionsOverviewSheetState extends State<QuestionsOverviewSheet> {
  String _selectedFilter = 'all';
  bool _isListView = false;

  @override
  Widget build(BuildContext context) {
    final skippedList = widget.questions.where((q) => q.isSkipped).toList();
    final uninspectedList = widget.questions.where((q) => q.item.status == InspectionStatus.uninspected && !q.isSkipped).toList();
    final rejectedList = widget.questions.where((q) => q.item.status == InspectionStatus.rejected).toList();
    final goodList = widget.questions.where((q) => (q.item.status == InspectionStatus.good || q.item.status == InspectionStatus.acceptable) && !q.isSkipped).toList();

    List<SessionQuestion> displayed;
    switch (_selectedFilter) {
      case 'skipped':
        displayed = skippedList;
        break;
      case 'uninspected':
        displayed = uninspectedList;
        break;
      case 'rejected':
        displayed = rejectedList;
        break;
      case 'good':
        displayed = goodList;
        break;
      default:
        displayed = widget.questions;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: AppTheme.primaryNavy, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'فهرس أسئلة الفحص الميداني',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_isListView ? Icons.grid_view_rounded : Icons.view_list_rounded, color: AppTheme.primaryNavy, size: 20),
                  tooltip: _isListView ? 'عرض الشبكة الرقمية' : 'عرض قائمة الصناديق والبنود',
                  onPressed: () => setState(() => _isListView = !_isListView),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('الكل (${widget.questions.length})', 'all'),
                const SizedBox(width: 6),
                _buildFilterChip('معلق / متخطى (${skippedList.length})', 'skipped', color: const Color(0xFFD97706)),
                const SizedBox(width: 6),
                _buildFilterChip('متبقي (${uninspectedList.length})', 'uninspected', color: AppTheme.textMuted),
                const SizedBox(width: 6),
                _buildFilterChip('مرفوض (${rejectedList.length})', 'rejected', color: AppTheme.statusRejected),
                const SizedBox(width: 6),
                _buildFilterChip('سليم (${goodList.length})', 'good', color: AppTheme.statusGood),
              ],
            ),
          ),

          const Divider(height: 16),

          // Questions Content (Grid or Box-Aware List)
          Expanded(
            child: displayed.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد أسئلة تطابق هذا الفلتر',
                      style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  )
                : _isListView
                    ? ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        itemCount: displayed.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final q = displayed[idx];
                          final isCurrent = q.globalIndex == widget.currentIndex;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectQuestion(q.globalIndex);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCurrent ? AppTheme.primaryNavy.withValues(alpha: 0.05) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent
                                      ? AppTheme.primaryNavy
                                      : (q.isSkipped ? const Color(0xFFF59E0B) : AppTheme.borderSubtle),
                                  width: isCurrent ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: q.isSkipped
                                          ? const Color(0xFFFEF3C7)
                                          : AppTheme.primaryNavy.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${q.globalIndex + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: q.isSkipped ? const Color(0xFFD97706) : AppTheme.primaryNavy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (q.subcategory != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.inventory_2_outlined, size: 11, color: Color(0xFF1D4ED8)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  q.subcategory!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Text(
                                            'نموذج ${q.group.groupNumber}: ${q.group.title}',
                                            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        Text(
                                          q.item.description,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: q.isSkipped
                                          ? const Color(0xFFFEF3C7)
                                          : q.item.status.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: q.isSkipped ? const Color(0xFFF59E0B) : q.item.status.color,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      q.isSkipped ? 'معلق' : q.item.status.labelAr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: q.isSkipped ? const Color(0xFFD97706) : q.item.status.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: displayed.length,
                        itemBuilder: (context, idx) {
                          final q = displayed[idx];
                          final isCurrent = q.globalIndex == widget.currentIndex;

                          Color btnColor;
                          Color textColor;
                          Border? border;

                          if (q.isSkipped) {
                            btnColor = const Color(0xFFFEF3C7);
                            textColor = const Color(0xFFB45309);
                            border = Border.all(color: const Color(0xFFF59E0B), width: 1.5);
                          } else if (q.item.status == InspectionStatus.uninspected) {
                            btnColor = const Color(0xFFF1F5F9);
                            textColor = const Color(0xFF64748B);
                            border = Border.all(color: const Color(0xFFCBD5E1));
                          } else if (q.item.status == InspectionStatus.rejected) {
                            btnColor = const Color(0xFFFEE2E2);
                            textColor = const Color(0xFFB91C1C);
                            border = Border.all(color: const Color(0xFFEF4444));
                          } else if (q.item.status == InspectionStatus.needsFollowup) {
                            btnColor = const Color(0xFFFFFBEB);
                            textColor = const Color(0xFFD97706);
                            border = Border.all(color: const Color(0xFFF59E0B));
                          } else {
                            btnColor = const Color(0xFFECFDF5);
                            textColor = const Color(0xFF047857);
                            border = Border.all(color: const Color(0xFF10B981));
                          }

                          if (isCurrent) {
                            border = Border.all(color: AppTheme.primaryNavy, width: 2.5);
                          }

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelectQuestion(q.globalIndex);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: btnColor,
                                borderRadius: BorderRadius.circular(10),
                                border: border,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${q.globalIndex + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    'ن${q.group.groupNumber}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, {Color? color}) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (color ?? AppTheme.textDark))),
      selected: isSelected,
      selectedColor: color ?? AppTheme.primaryNavy,
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(color: isSelected ? (color ?? AppTheme.primaryNavy) : AppTheme.borderSubtle),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }
}
