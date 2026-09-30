import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inspection_item.dart';
import '../models/session_question.dart';

class SessionCompletionDialog {
  /// Shows a warning if there are any unchecked or skipped questions
  static void showIncompleteWarning({
    required BuildContext context,
    required List<SessionQuestion> remainingQuestions,
    required ValueChanged<int> onJumpToQuestion,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.up,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 26),
            SizedBox(width: 8),
            Text(
              'الجلسة لم تكتمل بعد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'لا يمكن إنهاء الجلسة أو اعتماد التقرير إلا بعد التشييك على جميع أسئلة الفحص الميداني.',
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textDark),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'يوجد (${remainingQuestions.length}) سؤال تم تخطيه أو لم يتم فحصه بعد.',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'أول الأسئلة المتبقية للمراجعة:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            ...remainingQuestions.take(3).map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سؤال ${q.globalIndex + 1} (${q.group.title}): ${q.item.description}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('إغلاق والمتابعة لاحقاً'),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('الانتقال لأول سؤال متبقي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              if (remainingQuestions.isNotEmpty) {
                onJumpToQuestion(remainingQuestions.first.globalIndex);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Shows celebratory completion modal when all items are 100% checked
  static void showCompletedSuccess({
    required BuildContext context,
    required List<SessionQuestion> questions,
    required VoidCallback onOpenEditor,
    required VoidCallback onSaveAndFinish,
    required VoidCallback onPreviewPdf,
  }) {
    final goodCount = questions.where((q) => q.item.status == InspectionStatus.good).length;
    final acceptableCount = questions.where((q) => q.item.status == InspectionStatus.acceptable).length;
    final followupCount = questions.where((q) => q.item.status == InspectionStatus.needsFollowup).length;
    final rejectedCount = questions.where((q) => q.item.status == InspectionStatus.rejected).length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebratory Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.statusGood.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.statusGood, size: 52),
              ),
              const SizedBox(height: 14),

              const Text(
                'اكتمل الفحص الميداني بنجاح!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'تم التشييك والتحقق من كافة بنود المنظومة بنسبة 100%. يمكنك المتابعة لإدخال القياسات والتواقيع أو تصدير التقرير.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Statistics Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'إجمالي البنود المفحوصة:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${questions.length} / ${questions.length} بند (100%)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.statusGood),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('سليم (جيد)', goodCount, AppTheme.statusGood),
                        _buildStatItem('مقبول', acceptableCount, AppTheme.statusAcceptable),
                        _buildStatItem('متابعة', followupCount, const Color(0xFFD97706)),
                        _buildStatItem('مرفوض', rejectedCount, AppTheme.statusRejected),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Actions
              // 1. الخيار الأساسي: الانتقال للمحرر لإكمال القياسات والتواقيع (Single FilledButton)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.solarGold),
                  label: const Text(
                    'متابعة القياسات والتواقيع (المحرر) 📝',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onOpenEditor();
                  },
                ),
              ),
              const SizedBox(height: 8),

              // 2. خيار معاينة وتصدير PDF (OutlinedButton)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 18, color: AppTheme.primaryNavy),
                  label: const Text('معاينة وتصدير PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onPreviewPdf();
                  },
                ),
              ),
              const SizedBox(height: 8),

              // 3. حفظ وخروج (TextButton)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onSaveAndFinish();
                },
                child: const Text('حفظ والخروج للرئيسية', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
      ],
    );
  }
}
