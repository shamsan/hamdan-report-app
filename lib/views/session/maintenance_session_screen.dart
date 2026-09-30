import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inspection_item.dart';
import '../../models/maintenance_need.dart';
import '../../models/report.dart';
import '../../state/reports_provider.dart';
import '../preview/pdf_preview_screen.dart';
import '../editor/report_editor_screen.dart';
import 'models/session_question.dart';
import 'widgets/question_card_widget.dart';
import 'widgets/questions_overview_sheet.dart';
import 'widgets/session_completion_dialog.dart';
import 'widgets/session_progress_header.dart';

class MaintenanceSessionScreen extends ConsumerStatefulWidget {
  final String reportId;
  final int initialQuestionIndex;

  const MaintenanceSessionScreen({
    super.key,
    required this.reportId,
    this.initialQuestionIndex = 0,
  });

  @override
  ConsumerState<MaintenanceSessionScreen> createState() => _MaintenanceSessionScreenState();
}

class _MaintenanceSessionScreenState extends ConsumerState<MaintenanceSessionScreen> {
  late PageController _pageController;
  late Report _report;
  bool _isLoaded = false;
  int _currentIndex = 0;
  bool _smartNavigation = true; // القفز التكيفي الذكي للبنود المعلقة
  bool _autoAdvanceOnGood = true; // التقدم التلقائي عند تقييم البند بالسليم
  final Set<int> _skippedIndices = <int>{};
  List<SessionQuestion> _questions = [];
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialQuestionIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadReport();

    // حفظ فوري للتقرير عند مغادرة التطبيق أو ورود مكالمة
    _lifecycleListener = AppLifecycleListener(
      onPause: () => ref.read(reportsProvider.notifier).updateReport(_report),
      onInactive: () => ref.read(reportsProvider.notifier).updateReport(_report),
      onDetach: () => ref.read(reportsProvider.notifier).updateReport(_report),
      onHide: () => ref.read(reportsProvider.notifier).updateReport(_report),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _loadReport() {
    final reports = ref.read(reportsProvider);
    final found = reports.firstWhere(
      (r) => r.id == widget.reportId,
      orElse: () => reports.first,
    );
    _report = found;
    _refreshQuestions();
    _isLoaded = true;
  }

  void _refreshQuestions() {
    _questions = SessionQuestion.buildList(_report, _skippedIndices);
  }

  /// Calculates the next target index based on smart adaptive mode vs sequential mode
  int _findNextTargetIndex({bool smart = true}) {
    if (!smart) {
      if (_currentIndex < _questions.length - 1) {
        return _currentIndex + 1;
      }
      return -1; // End reached in sequential mode
    }

    // 1. Look ahead after _currentIndex for uninspected or skipped items
    for (int i = _currentIndex + 1; i < _questions.length; i++) {
      if (!_questions[i].isInspected) {
        return i;
      }
    }

    // 2. Wrap around: check if any uninspected/skipped items remain before _currentIndex
    for (int i = 0; i < _currentIndex; i++) {
      if (!_questions[i].isInspected) {
        return i;
      }
    }

    // 3. All items in the session are inspected!
    return -1;
  }

  void _goToQuestion(int targetIndex) {
    if (targetIndex >= 0 && targetIndex < _questions.length) {
      setState(() {
        _currentIndex = targetIndex;
      });
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onItemUpdated(InspectionItem updatedItem) {
    final currentQ = _questions[_currentIndex];

    final updatedGroups = List<InspectionGroup>.from(_report.inspectionGroups);
    final group = updatedGroups[currentQ.groupIndex];
    final updatedItems = List<InspectionItem>.from(group.items);
    updatedItems[currentQ.itemIndex] = updatedItem;

    updatedGroups[currentQ.groupIndex] = group.copyWith(items: updatedItems);

    final updatedReport = _report.copyWith(
      inspectionGroups: updatedGroups,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _report = updatedReport;
      if (updatedItem.status != InspectionStatus.uninspected) {
        _skippedIndices.remove(currentQ.globalIndex);
        HapticFeedback.lightImpact();
      }
      _refreshQuestions();
    });

    ref.read(reportsProvider.notifier).updateReport(updatedReport);
  }

  void _onNeedAdded(MaintenanceNeedItem need) {
    final existingIdx = _report.requestedNeeds.indexWhere((n) => n.id == need.id);
    final updatedNeeds = List<MaintenanceNeedItem>.from(_report.requestedNeeds);
    if (existingIdx >= 0) {
      updatedNeeds[existingIdx] = need;
    } else {
      updatedNeeds.add(need);
    }
    final updated = _report.copyWith(
      requestedNeeds: updatedNeeds,
      updatedAt: DateTime.now(),
    );
    setState(() {
      _report = updated;
    });
    ref.read(reportsProvider.notifier).updateReport(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تسجيل "${need.name}" لاحتياجات الزيارة القادمة'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onNeedDeleted(String needId) {
    final updatedNeeds = _report.requestedNeeds.where((n) => n.id != needId).toList();
    final updated = _report.copyWith(
      requestedNeeds: updatedNeeds,
      updatedAt: DateTime.now(),
    );
    setState(() {
      _report = updated;
    });
    ref.read(reportsProvider.notifier).updateReport(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف المادة من قائمة الاحتياجات'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleNext() {
    final currentQ = _questions[_currentIndex];

    // If inspected, ensure unskipped
    if (currentQ.item.status != InspectionStatus.uninspected) {
      _skippedIndices.remove(currentQ.globalIndex);
      _refreshQuestions();
    }

    final targetIndex = _findNextTargetIndex(smart: _smartNavigation);

    if (targetIndex != -1) {
      // Provide clean feedback if jumping past completed items
      if (_smartNavigation && targetIndex > _currentIndex + 1) {
        final jumpedCount = targetIndex - _currentIndex - 1;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'قفز ذكي: تجاوز $jumpedCount بنداً مكتملاً والانتقال للبند المعلق (${targetIndex + 1})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 1600),
            backgroundColor: AppTheme.primaryNavy,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (_smartNavigation && targetIndex < _currentIndex) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.replay_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'العودة للبند المعلق السابق رقم (${targetIndex + 1}) لإكماله',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 1600),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _goToQuestion(targetIndex);
    } else {
      // All items completed!
      _attemptFinishSession();
    }
  }

  void _handleSkip() {
    final currentQ = _questions[_currentIndex];
    setState(() {
      _skippedIndices.add(currentQ.globalIndex);
      _refreshQuestions();
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم تخطي السؤال (${_currentIndex + 1}). يجب العودة إليه لاحقاً لاعتماد الجلسة.',
          style: const TextStyle(fontSize: 12.5),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Smart navigation: find the next uninspected item after _currentIndex
    int targetIndex = -1;
    if (_smartNavigation) {
      for (int i = _currentIndex + 1; i < _questions.length; i++) {
        if (!_questions[i].isInspected) {
          targetIndex = i;
          break;
        }
      }
      if (targetIndex == -1) {
        // Wrap around
        for (int i = 0; i < _currentIndex; i++) {
          if (!_questions[i].isInspected) {
            targetIndex = i;
            break;
          }
        }
      }
    } else {
      if (_currentIndex < _questions.length - 1) {
        targetIndex = _currentIndex + 1;
      }
    }

    if (targetIndex != -1 && targetIndex != _currentIndex) {
      _goToQuestion(targetIndex);
    } else {
      _attemptFinishSession();
    }
  }

  /// تخطي باقي أسئلة هذا الصندوق / المكون بالكامل والقفز للقسم التالي
  void _skipRemainingInSubcategory() {
    if (_questions.isEmpty) return;
    final currentQ = _questions[_currentIndex];
    final subcat = currentQ.subcategory;
    final groupIdx = currentQ.groupIndex;
    final String targetName = (subcat != null && subcat.isNotEmpty)
        ? subcat
        : currentQ.group.title;

    final toSkip = <int>[];
    int nextTarget = -1;

    for (int i = _currentIndex; i < _questions.length; i++) {
      final q = _questions[i];
      final isSame = (subcat != null && subcat.isNotEmpty)
          ? (q.groupIndex == groupIdx && q.subcategory == subcat)
          : (q.groupIndex == groupIdx);
      if (isSame) {
        if (!q.isInspected) {
          toSkip.add(q.globalIndex);
        }
      } else {
        nextTarget = i;
        break;
      }
    }

    if (toSkip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بنود متبقية للتخطي في هذا القسم')),
      );
      return;
    }

    setState(() {
      _skippedIndices.addAll(toSkip);
      _refreshQuestions();
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم تخطي ${toSkip.length} بنداً في "$targetName"',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (nextTarget == -1) {
      nextTarget = _findNextTargetIndex(smart: _smartNavigation);
    }

    if (nextTarget != -1 && nextTarget != _currentIndex) {
      _goToQuestion(nextTarget);
    } else {
      _attemptFinishSession();
    }
  }

  /// تخطي ما تبقى من أسئلة النموذج بالكامل والقفز للنموذج التالي
  void _skipRemainingInGroup() {
    if (_questions.isEmpty) return;
    final currentQ = _questions[_currentIndex];
    final groupIdx = currentQ.groupIndex;
    final groupTitle = currentQ.group.title;

    final toSkip = <int>[];
    int nextTarget = -1;

    for (int i = _currentIndex; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.groupIndex == groupIdx) {
        if (!q.isInspected) {
          toSkip.add(q.globalIndex);
        }
      } else {
        nextTarget = i;
        break;
      }
    }

    if (toSkip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بنود متبقية للتخطي في هذا النموذج')),
      );
      return;
    }

    setState(() {
      _skippedIndices.addAll(toSkip);
      _refreshQuestions();
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.tab_unselected_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم تخطي ${toSkip.length} بنداً في "$groupTitle"',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (nextTarget == -1) {
      nextTarget = _findNextTargetIndex(smart: _smartNavigation);
    }

    if (nextTarget != -1 && nextTarget != _currentIndex) {
      _goToQuestion(nextTarget);
    } else {
      _attemptFinishSession();
    }
  }

  /// تطبيق حالة جماعية لكل بنود هذا الصندوق أو النموذج (مثل: غير منطبق N/A أو سليم)
  void _applyBulkStatusToSubcategory(InspectionStatus status, {String? defaultNotes}) {
    if (_questions.isEmpty) return;
    final currentQ = _questions[_currentIndex];
    final subcat = currentQ.subcategory;
    final groupIdx = currentQ.groupIndex;
    final String targetName = (subcat != null && subcat.isNotEmpty)
        ? subcat
        : currentQ.group.title;

    final updatedGroups = List<InspectionGroup>.from(_report.inspectionGroups);
    final group = updatedGroups[groupIdx];
    final updatedItems = group.items.map((item) {
      final matches = (subcat != null && subcat.isNotEmpty)
          ? item.subcategory == subcat
          : true;
      if (matches) {
        return item.copyWith(
          status: status,
          notes: (defaultNotes != null && defaultNotes.isNotEmpty) ? defaultNotes : item.notes,
        );
      }
      return item;
    }).toList();

    updatedGroups[groupIdx] = group.copyWith(items: updatedItems);

    final updatedReport = _report.copyWith(
      inspectionGroups: updatedGroups,
      updatedAt: DateTime.now(),
    );

    // إلغاء تعليق البنود التي تم فحصها جماعياً
    final affectedGlobals = _questions
        .where((q) => (subcat != null && subcat.isNotEmpty)
            ? (q.groupIndex == groupIdx && q.subcategory == subcat)
            : (q.groupIndex == groupIdx))
        .map((q) => q.globalIndex)
        .toSet();

    setState(() {
      _report = updatedReport;
      _skippedIndices.removeAll(affectedGlobals);
      _refreshQuestions();
    });

    ref.read(reportsProvider.notifier).updateReport(updatedReport);
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(status.icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم تعيين جميع بنود "$targetName" كـ: ${status.labelAr}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: status.color,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // البحث عن أول سؤال يقع بعد هذا القسم
    int nextTarget = -1;
    for (int i = _currentIndex; i < _questions.length; i++) {
      final q = _questions[i];
      final isSame = (subcat != null && subcat.isNotEmpty)
          ? (q.groupIndex == groupIdx && q.subcategory == subcat)
          : (q.groupIndex == groupIdx);
      if (!isSame) {
        nextTarget = i;
        break;
      }
    }

    if (nextTarget == -1) {
      nextTarget = _findNextTargetIndex(smart: _smartNavigation);
    }

    if (nextTarget != -1 && nextTarget != _currentIndex) {
      _goToQuestion(nextTarget);
    } else {
      _attemptFinishSession();
    }
  }

  /// إظهار قائمة خيارات التخطي والإجراءات السريعة
  void _showSkipOptionsMenu() {
    if (_questions.isEmpty) return;
    final currentQ = _questions[_currentIndex];
    final subcat = currentQ.subcategory;
    final groupTitle = currentQ.group.title;
    final targetSectionName = (subcat != null && subcat.isNotEmpty) ? subcat : groupTitle;

    int subcatRemaining = 0;
    for (int i = _currentIndex; i < _questions.length; i++) {
      final q = _questions[i];
      final matches = (subcat != null && subcat.isNotEmpty)
          ? (q.groupIndex == currentQ.groupIndex && q.subcategory == subcat)
          : (q.groupIndex == currentQ.groupIndex);
      if (matches) {
        if (!q.isInspected) subcatRemaining++;
      } else {
        break;
      }
    }

    int groupRemaining = 0;
    for (int i = _currentIndex; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.groupIndex == currentQ.groupIndex) {
        if (!q.isInspected) groupRemaining++;
      } else {
        break;
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.bolt, color: Color(0xFFD97706), size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'خيارات التخطي والإجراءات السريعة',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'القسم الحالي: $targetSectionName',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const Divider(height: 20),

                // تخطي هذا السؤال فقط
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFFBEB),
                    child: Icon(Icons.skip_next_rounded, color: Color(0xFFD97706), size: 20),
                  ),
                  title: Text('تخطي هذا السؤال فقط (بند رقم ${_currentIndex + 1})'),
                  subtitle: const Text('تأجيل هذا البند والقفز للبند التالي', style: TextStyle(fontSize: 11)),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleSkip();
                  },
                ),

                // تخطي باقي أسئلة الصندوق
                if (subcatRemaining > 1)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.fast_forward_rounded, color: Color(0xFFB45309), size: 20),
                    ),
                    title: Text('تخطي باقي أسئلة هذا القسم ($subcatRemaining بنود)'),
                    subtitle: Text('تجاوز باقي أسئلة "$targetSectionName" والقفز للقسم التالي', style: const TextStyle(fontSize: 11)),
                    dense: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _skipRemainingInSubcategory();
                    },
                  ),

                // تخطي باقي أسئلة النموذج
                if (groupRemaining > subcatRemaining && groupRemaining > 1)
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.tab_unselected_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    title: Text('تخطي باقي أسئلة هذا النموذج بالكامل ($groupRemaining بنود)'),
                    subtitle: Text('القفز مباشرة إلى بداية النموذج التالي', style: const TextStyle(fontSize: 11)),
                    dense: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _skipRemainingInGroup();
                    },
                  ),

                const Divider(height: 16),

                // إجراءات جماعية سريعة
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.remove_circle_outline, size: 16),
                        label: const Text('غير متوفر بالموقع (N/A)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _applyBulkStatusToSubcategory(
                            InspectionStatus.notApplicable,
                            defaultNotes: 'غير متوفر في هذا المرفق',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('تعيين الكل: سليم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _applyBulkStatusToSubcategory(InspectionStatus.good);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePrevious() {
    if (_currentIndex > 0) {
      _goToQuestion(_currentIndex - 1);
    }
  }

  void _attemptFinishSession() {
    final remaining = _questions.where((q) => !q.isInspected).toList();

    if (remaining.isNotEmpty) {
      SessionCompletionDialog.showIncompleteWarning(
        context: context,
        remainingQuestions: remaining,
        onJumpToQuestion: (idx) {
          _goToQuestion(idx);
        },
      );
    } else {
      // 100% completed!
      HapticFeedback.heavyImpact();
      final completedReport = _report.copyWith(
        status: ReportStatus.completed,
        updatedAt: DateTime.now(),
      );

      ref.read(reportsProvider.notifier).updateReport(completedReport);
      setState(() {
        _report = completedReport;
      });

      SessionCompletionDialog.showCompletedSuccess(
        context: context,
        questions: _questions,
        onOpenEditor: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReportEditorScreen(reportId: completedReport.id),
            ),
          );
        },
        onSaveAndFinish: () {
          Navigator.pop(context); // Return from session screen
        },
        onPreviewPdf: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(report: completedReport),
            ),
          );
        },
      );
    }
  }

  void _openOverviewSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => QuestionsOverviewSheet(
        questions: _questions,
        currentIndex: _currentIndex,
        onSelectQuestion: (idx) {
          Navigator.pop(context);
          _goToQuestion(idx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final inspectedCount = _questions.where((q) => q.isInspected).length;
    final skippedCount = _questions.where((q) => q.isSkipped).length;
    final currentQ = _questions.isNotEmpty ? _questions[_currentIndex] : null;
    final isLastQuestion = _currentIndex == _questions.length - 1;

    Future<bool?> showExitConfirmation() async {
      final uninspected = _questions.where((q) => !q.isInspected).length;
      if (uninspected == 0) {
        ref.read(reportsProvider.notifier).updateReport(_report);
        return true;
      }

      return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.pause_circle_outline_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مغادرة جلسة الفحص',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Text(
            'يتبقى $uninspected بنداً لم يتم فحصها بعد. سيتم حفظ كافة الإجابات الحالية لتتمكن من متابعتها في أي وقت.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('متابعة الفحص', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3A60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                ref.read(reportsProvider.notifier).updateReport(_report);
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ وخروج'),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showExitConfirmation();
        if (shouldLeave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'جلسة الفحص الميداني التفاعلية',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
              Text(
                _report.facilityInfo.facilityName.isNotEmpty
                    ? _report.facilityInfo.facilityName
                    : _report.title,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(
                _autoAdvanceOnGood ? Icons.touch_app_rounded : Icons.touch_app_outlined,
                color: _autoAdvanceOnGood ? const Color(0xFF34D399) : Colors.white60,
              ),
              tooltip: _autoAdvanceOnGood ? 'التقدم التلقائي عند التقييم السليم: مفعل' : 'التقدم التلقائي: معطل',
              onPressed: () {
                setState(() {
                  _autoAdvanceOnGood = !_autoAdvanceOnGood;
                });
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _autoAdvanceOnGood
                          ? 'تم تفعيل التقدم التلقائي عند تقييم البند كـ "سليم"'
                          : 'تم تعطيل التقدم التلقائي',
                      style: const TextStyle(fontSize: 12),
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                _smartNavigation ? Icons.bolt_rounded : Icons.format_list_numbered_rounded,
                color: _smartNavigation ? const Color(0xFFFBBF24) : Colors.white70,
              ),
              tooltip: _smartNavigation ? 'القفز الذكي للبنود المعلقة: مفعل' : 'التقدم التسلسلي: مفعل',
              onPressed: () {
                setState(() {
                  _smartNavigation = !_smartNavigation;
                });
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _smartNavigation
                          ? 'تم تفعيل القفز الذكي للبنود المعلقة'
                          : 'تم تفعيل التنقل التسلسلي خطوة بخطوة',
                      style: const TextStyle(fontSize: 12),
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'فهرس ومصفوفة الأسئلة',
              onPressed: _openOverviewSheet,
            ),
            IconButton(
              icon: const Icon(Icons.task_alt_rounded),
              tooltip: 'التحقق من اكتمال الجلسة',
              onPressed: _attemptFinishSession,
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Progress & Status Header
            if (currentQ != null)
              SessionProgressHeader(
                facilityName: _report.facilityInfo.facilityName,
                reportNumber: _report.reportNumber,
                currentIndex: _currentIndex,
                totalQuestions: _questions.length,
                inspectedCount: inspectedCount,
                skippedCount: skippedCount,
                groupTitle: currentQ.group.title,
                groupNumber: currentQ.groupIndex + 1,
                subcategory: currentQ.subcategory,
                onOpenOverview: _openOverviewSheet,
              ),

            // Question View Area
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentIndex = page;
                  });
                },
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  final linkedNeeds = _report.requestedNeeds
                      .where((n) => n.relatedInspectionItemId == q.item.id)
                      .toList();
                  return QuestionCardWidget(
                    key: ValueKey('question_${q.globalIndex}_${q.item.id}'),
                    question: q,
                    report: _report,
                    linkedNeeds: linkedNeeds,
                    onUpdated: _onItemUpdated,
                    onAddNeed: _onNeedAdded,
                    onDeleteNeed: _onNeedDeleted,
                    onSkipSubcategory: _skipRemainingInSubcategory,
                    onMarkSubcategoryGood: () => _applyBulkStatusToSubcategory(InspectionStatus.good),
                    onMarkSubcategoryNA: () => _applyBulkStatusToSubcategory(
                      InspectionStatus.notApplicable,
                      defaultNotes: 'غير متوفر في هذا المرفق',
                    ),
                    onAutoAdvance: _autoAdvanceOnGood ? _handleNext : null,
                  );
                },
              ),
            ),

            // Bottom Navigation Controls
            _buildBottomActionBar(currentQ, isLastQuestion, inspectedCount),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBottomActionBar(
    SessionQuestion? currentQ,
    bool isLastQuestion,
    int inspectedCount,
  ) {
    final isInspected = currentQ?.isInspected ?? false;
    final nextTarget = _findNextTargetIndex(smart: _smartNavigation);
    final remainingCount = _questions.length - inspectedCount;
    final isAllCompleted = remainingCount == 0;

    String nextButtonLabel;
    IconData nextButtonIcon;
    Color nextButtonColor;

    if (isAllCompleted || nextTarget == -1) {
      nextButtonLabel = 'إنهاء واعتماد الجلسة';
      nextButtonIcon = Icons.verified_rounded;
      nextButtonColor = AppTheme.statusGood;
    } else if (_smartNavigation && nextTarget > _currentIndex + 1) {
      nextButtonLabel = 'التالي: بند ${nextTarget + 1} (معلق)';
      nextButtonIcon = Icons.fast_forward_rounded;
      nextButtonColor = AppTheme.primaryNavy;
    } else if (_smartNavigation && nextTarget < _currentIndex) {
      nextButtonLabel = 'العودة لبند ${nextTarget + 1} (معلق)';
      nextButtonIcon = Icons.replay_rounded;
      nextButtonColor = const Color(0xFFD97706);
    } else {
      nextButtonLabel = isLastQuestion ? 'إنهاء واعتماد الجلسة' : 'السؤال التالي (${nextTarget + 1})';
      nextButtonIcon = isLastQuestion ? Icons.verified_rounded : Icons.arrow_back_rounded;
      nextButtonColor = isInspected ? AppTheme.primaryNavy : const Color(0xFF2563EB);
    }

    final int? jumpedCount = (_smartNavigation && nextTarget != -1 && nextTarget > _currentIndex + 1)
        ? (nextTarget - _currentIndex - 1)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Smart Jump Notice Pill
            if (jumpedCount != null && jumpedCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'قفز ذكي: سيتم تجاوز $jumpedCount بنداً مكتملاً والانتقال مباشرة للبند المعلق رقم (${nextTarget + 1})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                // Previous Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(
                      color: _currentIndex > 0 ? AppTheme.borderMedium : AppTheme.borderSubtle,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right, size: 20), // ← chevron_right = "السابق" في RTL
                  label: const Text('السابق', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  onPressed: _currentIndex > 0 ? _handlePrevious : null,
                ),
                const SizedBox(width: 8),

                // Enhanced Multi-Skip Button (Tap to skip 1, Long-press or tap arrow for bulk options)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _handleSkip,
                        onLongPress: _showSkipOptionsMenu,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.skip_next_rounded, size: 18, color: Color(0xFFD97706)),
                              SizedBox(width: 4),
                              Text(
                                'تخطي',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: const Color(0xFFFCD34D),
                      ),
                      InkWell(
                        onTap: _showSkipOptionsMenu,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                        child: const Tooltip(
                          message: 'خيارات التخطي السريع وتخطي القسم',
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                            child: Icon(
                              Icons.arrow_drop_down,
                              size: 20,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Next / Finish Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nextButtonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: Icon(nextButtonIcon, size: 18),
                    label: Text(
                      nextButtonLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _handleNext,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
