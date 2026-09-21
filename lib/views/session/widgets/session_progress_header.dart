import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SessionProgressHeader extends StatelessWidget {
  final String facilityName;
  final String reportNumber;
  final int currentIndex;
  final int totalQuestions;
  final int inspectedCount;
  final int skippedCount;
  final String groupTitle;
  final int groupNumber;
  final String? subcategory;
  final VoidCallback onOpenOverview;

  const SessionProgressHeader({
    super.key,
    required this.facilityName,
    required this.reportNumber,
    required this.currentIndex,
    required this.totalQuestions,
    required this.inspectedCount,
    required this.skippedCount,
    required this.groupTitle,
    required this.groupNumber,
    this.subcategory,
    required this.onOpenOverview,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalQuestions > 0 ? (inspectedCount / totalQuestions).clamp(0.0, 1.0) : 0.0;
    final remainingCount = totalQuestions - inspectedCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Bar with Facility Info and Overview Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facilityName.isNotEmpty ? facilityName : 'جلسة صيانة دورية',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تقرير: $reportNumber • فحص خطوة بخطوة',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: AppTheme.primaryNavy, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                  label: Text('الفهرس ($totalQuestions)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: onOpenOverview,
                ),
              ],
            ),
          ),

          // Progress Bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? AppTheme.statusGood : AppTheme.solarGold,
            ),
            minHeight: 4,
          ),

          // Counters and Group Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'السؤال ${currentIndex + 1} من $totalQuestions',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
                const Spacer(),
                // Counter Badges
                _buildBadge(
                  label: '$inspectedCount منجز',
                  color: AppTheme.statusGood,
                  bgColor: const Color(0xFFECFDF5),
                ),
                if (skippedCount > 0) ...[
                  const SizedBox(width: 6),
                  _buildBadge(
                    label: '$skippedCount معلق',
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                ],
                const SizedBox(width: 6),
                _buildBadge(
                  label: '$remainingCount متبقي',
                  color: AppTheme.textMuted,
                  bgColor: const Color(0xFFF1F5F9),
                ),
              ],
            ),
          ),

          // Group Title Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'نموذج $groupNumber',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    groupTitle,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subcategory != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 12, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Text(
                          subcategory!,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
