import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inspection_item.dart';
import '../../../models/maintenance_need.dart';
import '../../../models/report.dart';
import '../../../services/camera_service.dart';
import '../../../services/preset_notes_service.dart';
import '../models/session_question.dart';
import '../preset_notes_manager_screen.dart';
import 'quick_need_dialog.dart';

class QuestionCardWidget extends StatefulWidget {
  final SessionQuestion question;
  final ValueChanged<InspectionItem> onUpdated;
  final Report report;
  final List<MaintenanceNeedItem> linkedNeeds;
  final ValueChanged<MaintenanceNeedItem> onAddNeed;
  final ValueChanged<String> onDeleteNeed;
  final VoidCallback? onSkipSubcategory;
  final VoidCallback? onMarkSubcategoryGood;
  final VoidCallback? onMarkSubcategoryNA;
  final VoidCallback? onAutoAdvance;

  const QuestionCardWidget({
    super.key,
    required this.question,
    required this.onUpdated,
    required this.report,
    this.linkedNeeds = const [],
    required this.onAddNeed,
    required this.onDeleteNeed,
    this.onSkipSubcategory,
    this.onMarkSubcategoryGood,
    this.onMarkSubcategoryNA,
    this.onAutoAdvance,
  });

  @override
  State<QuestionCardWidget> createState() => _QuestionCardWidgetState();
}

class _QuestionCardWidgetState extends State<QuestionCardWidget> {
  late TextEditingController _notesController;
  List<String> _presetNotes = [];
  bool _isLoadingNotes = false;

  // Progressive Disclosure (الظهور التدريجي لتقليل إجهاد التمرير)
  bool _showNotes = false;
  bool _showPhoto = false;
  bool _showNeeds = false;

  void _syncExpansionState(InspectionItem item) {
    if (item.notes.trim().isNotEmpty) {
      _showNotes = true;
    }
    if (item.photoBase64 != null && item.photoBase64!.isNotEmpty) {
      _showPhoto = true;
    }
    if (widget.linkedNeeds.isNotEmpty) {
      _showNeeds = true;
    }
    if (item.status == InspectionStatus.needsFollowup ||
        item.status == InspectionStatus.rejected) {
      _showNotes = true;
      _showNeeds = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.question.item.notes);
    _notesController.addListener(_onNotesChanged);
    _syncExpansionState(widget.question.item);
    _loadPresetNotes();
  }

  void _onNotesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant QuestionCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.item.id != widget.question.item.id) {
      _notesController.text = widget.question.item.notes;
      _showNotes = false;
      _showPhoto = false;
      _showNeeds = false;
      _syncExpansionState(widget.question.item);
      _loadPresetNotes();
    } else {
      if (oldWidget.question.item.notes != widget.question.item.notes &&
          _notesController.text != widget.question.item.notes) {
        _notesController.text = widget.question.item.notes;
      }
      _syncExpansionState(widget.question.item);
    }
  }

  Future<void> _loadPresetNotes() async {
    if (!mounted) return;
    setState(() => _isLoadingNotes = true);
    final item = widget.question.item;
    final notes = await PresetNotesService.getNotesForQuestion(
      item.id,
      subcategory: item.subcategory,
      description: item.description,
    );
    if (mounted) {
      setState(() {
        _presetNotes = notes;
        _isLoadingNotes = false;
      });
    }
  }

  Future<void> _promptAddPresetNote() async {
    final item = widget.question.item;
    final addCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_comment_rounded, color: AppTheme.primaryNavy, size: 20),
            SizedBox(width: 8),
            Text('إضافة ملاحظة مسبقة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('بند: ${item.description}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: addCtrl,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'أدخل نص الملاحظة الفنية المسبقة...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة وحفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (res == true && addCtrl.text.trim().isNotEmpty) {
      await PresetNotesService.addCustomNote(item.id, addCtrl.text.trim(), description: item.description);
      await _loadPresetNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة الملاحظة المسبقة بنجاح')),
        );
      }
    }
  }

  Future<void> _saveCurrentPhrase() async {
    final phrase = _notesController.text.trim();
    if (phrase.isEmpty) return;
    final item = widget.question.item;
    final ok = await PresetNotesService.addCustomNote(item.id, phrase, description: item.description);
    if (ok) {
      await _loadPresetNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ العبارة كملاحظة مسبقة: "$phrase"'),
            backgroundColor: AppTheme.statusGood,
          ),
        );
      }
    }
  }

  void _applyNoteChip(String note) {
    final item = widget.question.item;
    String newText;
    final current = _notesController.text.trim();
    if (current.isEmpty) {
      newText = note;
    } else if (current.contains(note)) {
      newText = current;
    } else {
      newText = '$current - $note';
    }
    _notesController.text = newText;
    widget.onUpdated(item.copyWith(notes: newText));
  }

  void _showAllPresetNotesSheet() {
    final item = widget.question.item;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.quickreply_rounded, color: AppTheme.primaryNavy, size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'بنك الملاحظات المقترحة والمسبقة للبند',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'بند: ${item.description}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetNotes.map((note) {
                    final isIncluded = _notesController.text.contains(note);
                    return ActionChip(
                      avatar: Icon(
                        isIncluded ? Icons.check_circle : Icons.add_circle_outline,
                        size: 14,
                        color: isIncluded ? AppTheme.statusGood : AppTheme.primaryNavy,
                      ),
                      label: Text(
                        note,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isIncluded ? FontWeight.bold : FontWeight.normal,
                          color: isIncluded ? AppTheme.primaryNavy : AppTheme.textDark,
                        ),
                      ),
                      backgroundColor: isIncluded
                          ? AppTheme.statusGood.withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isIncluded
                            ? AppTheme.statusGood.withValues(alpha: 0.5)
                            : AppTheme.borderSubtle,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      onPressed: () {
                        _applyNoteChip(note);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _captureFromCamera() async {
    final bytes = await CameraService.capturePhotoFromCamera();
    if (bytes != null) {
      final b64 = base64Encode(bytes);
      final updated = widget.question.item.copyWith(photoBase64: b64);
      widget.onUpdated(updated);
    }
  }

  Future<void> _pickFromGallery() async {
    final bytes = await CameraService.pickImageFromGallery();
    if (bytes != null) {
      final b64 = base64Encode(bytes);
      final updated = widget.question.item.copyWith(photoBase64: b64);
      widget.onUpdated(updated);
    }
  }

  void _removePhoto() {
    final updated = widget.question.item.copyWith(photoBase64: '');
    widget.onUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.question.item;
    final isSkipped = widget.question.isSkipped;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Target Box / Subcategory Attribution Banner
          if (item.subcategory != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryNavy.withValues(alpha: 0.08),
                    const Color(0xFFF1F5F9),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الصندوق / النظام المستهدف بالفحص (نموذج ${widget.question.group.groupNumber})',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subcategory!,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    tooltip: 'إجراءات جماعية لهذا الصندوق',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    position: PopupMenuPosition.under,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFD97706)),
                          SizedBox(width: 3),
                          Text(
                            'إجراءات الصندوق',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'skip') widget.onSkipSubcategory?.call();
                      if (val == 'good') widget.onMarkSubcategoryGood?.call();
                      if (val == 'na') widget.onMarkSubcategoryNA?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'skip',
                        child: Row(
                          children: [
                            Icon(Icons.skip_next_rounded, size: 18, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Text('تخطي باقي أسئلة هذا الصندوق'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'good',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF2E7D32)),
                            SizedBox(width: 8),
                            Text('تعيين كل بنود هذا الصندوق: جيد / سليم'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'na',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF78909C)),
                            SizedBox(width: 8),
                            Text('المكون غير متوفر بالموقع (غير منطبق N/A)'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Question Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSkipped ? const Color(0xFFF59E0B) : AppTheme.borderSubtle,
                width: isSkipped ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Number & Status Header
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'بند رقم ${item.serialNo}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          ),
                          if (item.subcategory != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                item.subcategory!,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          if (isSkipped)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFD97706)),
                                  SizedBox(width: 4),
                                  Text(
                                    'تم تخطيه (معلق)',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.status.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'الحالة: ${item.status.labelAr}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: item.status.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Item Question Description
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Status Selection Header
          Row(
            children: [
              const Text(
                'تقييم البند:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              if (item.status != InspectionStatus.uninspected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.status.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.status.labelAr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: item.status.color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 2x2 Grid + N/A Card
          _buildStatusOptions(item),

          // Quick Action Dock (صورة، ملاحظة، قطع غيار)
          _buildQuickActionDock(item),

          // Collapsible Photo Section
          if (_showPhoto) ...[
            _buildPhotoSection(item),
            const SizedBox(height: 10),
          ],

          // Collapsible Notes Section
          if (_showNotes) ...[
            _buildNotesSection(item),
            const SizedBox(height: 10),
          ],

          // Collapsible Needs Section
          if (_showNeeds) ...[
            _buildNeedsSection(item),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _selectStatus(InspectionStatus st) {
    HapticFeedback.lightImpact();
    final updated = widget.question.item.copyWith(status: st);
    widget.onUpdated(updated);

    if (st == InspectionStatus.good) {
      if (widget.onAutoAdvance != null) {
        Future.delayed(const Duration(milliseconds: 280), () {
          if (mounted) {
            widget.onAutoAdvance?.call();
          }
        });
      }
    } else if (st == InspectionStatus.needsFollowup || st == InspectionStatus.rejected) {
      setState(() {
        _showNotes = true;
        _showNeeds = true;
      });
    }
  }

  Widget _buildStatusTile(
    InspectionItem item, {
    required InspectionStatus status,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = item.status == status;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectStatus(status),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : AppTheme.borderSubtle,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? color : const Color(0xFFCBD5E1),
                      width: 1.8,
                    ),
                    color: isSelected ? color : Colors.white,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? color : AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotApplicableTile(InspectionItem item) {
    const status = InspectionStatus.notApplicable;
    final isSelected = item.status == status;
    const color = Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectStatus(status),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderSubtle,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFF94A3B8),
                    width: 1.8,
                  ),
                  color: isSelected ? color : Colors.white,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.do_not_disturb_on_rounded, color: color, size: 17),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'غير منطبق (N/A) - المكون غير متوفر بالمنشأة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'محدد',
                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOptions(InspectionItem item) {
    return Column(
      children: [
        // Row 1: Good & Acceptable
        Row(
          children: [
            _buildStatusTile(
              item,
              status: InspectionStatus.good,
              label: 'سليم / ممتاز',
              icon: Icons.check_circle_rounded,
              color: AppTheme.statusGood,
            ),
            const SizedBox(width: 8),
            _buildStatusTile(
              item,
              status: InspectionStatus.acceptable,
              label: 'مقبول / يعمل',
              icon: Icons.sentiment_satisfied_alt_rounded,
              color: AppTheme.statusAcceptable,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Needs Followup & Rejected
        Row(
          children: [
            _buildStatusTile(
              item,
              status: InspectionStatus.needsFollowup,
              label: 'يحتاج متابعة',
              icon: Icons.warning_amber_rounded,
              color: AppTheme.statusFollowup,
            ),
            const SizedBox(width: 8),
            _buildStatusTile(
              item,
              status: InspectionStatus.rejected,
              label: 'مرفوض / عاطل',
              icon: Icons.cancel_rounded,
              color: AppTheme.statusRejected,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 3: Not Applicable
        _buildNotApplicableTile(item),
      ],
    );
  }

  Widget _buildQuickActionDock(InspectionItem item) {
    final hasPhoto = item.photoBase64 != null && item.photoBase64!.isNotEmpty;
    final hasNotes = item.notes.trim().isNotEmpty;
    final needsCount = widget.linkedNeeds.length;
    final hasNeeds = needsCount > 0;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Photo Action
          Expanded(
            child: _buildDockButton(
              icon: hasPhoto ? Icons.photo_camera_rounded : Icons.add_a_photo_outlined,
              label: hasPhoto ? 'صورة مرفقة' : 'إرفاق صورة',
              badgeCount: hasPhoto ? 1 : 0,
              badgeColor: AppTheme.statusGood,
              isSelected: _showPhoto,
              activeColor: AppTheme.primaryNavy,
              onTap: () {
                setState(() {
                  _showPhoto = !_showPhoto;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          // Notes Action
          Expanded(
            child: _buildDockButton(
              icon: hasNotes ? Icons.rate_review_rounded : Icons.edit_note_rounded,
              label: hasNotes ? 'ملاحظة مسجلة' : 'ملاحظات فنية',
              badgeCount: hasNotes ? 1 : 0,
              badgeColor: AppTheme.brandCyan,
              isSelected: _showNotes,
              activeColor: AppTheme.brandCyan,
              onTap: () {
                setState(() {
                  _showNotes = !_showNotes;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          // Needs Action
          Expanded(
            child: _buildDockButton(
              icon: hasNeeds ? Icons.build_circle_rounded : Icons.handyman_outlined,
              label: hasNeeds ? 'احتياجات ($needsCount)' : 'طلب مواد',
              badgeCount: needsCount,
              badgeColor: AppTheme.solarGold,
              isSelected: _showNeeds,
              activeColor: AppTheme.solarGold,
              onTap: () {
                setState(() {
                  _showNeeds = !_showNeeds;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required int badgeCount,
    required Color badgeColor,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : AppTheme.textSecondary,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Center(
                        child: Text(
                          badgeCount > 1 ? '$badgeCount' : '✓',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(InspectionItem item) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: item.photoBase64 != null && item.photoBase64!.isNotEmpty
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(item.photoBase64!),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تم إرفاق صورة توثيقية للبند',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('ستظهر الصورة في ملحق التقرير المصدّر',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'حذف الصورة',
                    onPressed: _removePhoto,
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.camera_alt, size: 17),
                        label: const Text(
                          'التقاط فوري بالكاميرا',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _captureFromCamera,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.brandCyan,
                          side: const BorderSide(color: AppTheme.brandCyan),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text(
                          'الاستوديو',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _pickFromGallery,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNotesSection(InspectionItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.brandCyan.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.quickreply_rounded, size: 16, color: AppTheme.primaryNavy),
              const SizedBox(width: 6),
              const Text(
                'الملاحظات المسبقة',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              if (_presetNotes.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_presetNotes.length}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                ),
              ],
              const Spacer(),
              if (item.notes.isNotEmpty)
                InkWell(
                  onTap: () {
                    _notesController.clear();
                    widget.onUpdated(item.copyWith(notes: ''));
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'مسح',
                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'خيارات الملاحظات',
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                position: PopupMenuPosition.under,
                onSelected: (val) async {
                  if (val == 'save') {
                    _saveCurrentPhrase();
                  } else if (val == 'add') {
                    _promptAddPresetNote();
                  } else if (val == 'manage') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PresetNotesManagerScreen(initialQuestionId: item.id),
                      ),
                    );
                    _loadPresetNotes();
                  }
                },
                itemBuilder: (ctx) => [
                  if (_notesController.text.trim().isNotEmpty)
                    const PopupMenuItem(
                      value: 'save',
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_add_outlined, size: 18, color: AppTheme.brandCyan),
                          SizedBox(width: 8),
                          Text('حفظ العبارة الحالية كملاحظة دائمة'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: AppTheme.primaryNavy),
                        SizedBox(width: 8),
                        Text('إضافة ملاحظة جديدة للبند'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manage',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: AppTheme.textSecondary),
                        SizedBox(width: 8),
                        Text('إدارة بنك الملاحظات المسبقة'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Horizontal scroll of Preset Chips with 'View all'
          if (_isLoadingNotes)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_presetNotes.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presetNotes.length + (_presetNotes.length > 2 ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  if (index == _presetNotes.length) {
                    return ActionChip(
                      avatar: const Icon(Icons.grid_view_rounded, size: 13, color: AppTheme.primaryNavy),
                      label: const Text(
                        'عرض الكل',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.08),
                      side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: _showAllPresetNotesSheet,
                    );
                  }
                  final note = _presetNotes[index];
                  final isIncluded = _notesController.text.contains(note);
                  return ActionChip(
                    avatar: Icon(
                      isIncluded ? Icons.check_circle : Icons.add_circle_outline,
                      size: 13,
                      color: isIncluded ? AppTheme.statusGood : AppTheme.primaryNavy,
                    ),
                    label: Text(
                      note,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isIncluded ? FontWeight.bold : FontWeight.normal,
                        color: isIncluded ? AppTheme.primaryNavy : AppTheme.textDark,
                      ),
                    ),
                    backgroundColor: isIncluded
                        ? AppTheme.statusGood.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isIncluded
                          ? AppTheme.statusGood.withValues(alpha: 0.5)
                          : AppTheme.borderSubtle,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => _applyNoteChip(note),
                  );
                },
              ),
            ),

          // Detailed Notes Text Field
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'أدخل أي ملاحظات فنية إضافية على هذا البند...',
              hintStyle: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.2),
              ),
            ),
            onChanged: (val) {
              widget.onUpdated(item.copyWith(notes: val));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsSection(InspectionItem item) {
    final isProblematic = item.status == InspectionStatus.needsFollowup ||
        item.status == InspectionStatus.rejected;
    final hasNeeds = widget.linkedNeeds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProblematic ? AppTheme.solarGold.withValues(alpha: 0.6) : AppTheme.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.solarGold.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.solarGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build_circle_rounded, size: 18, color: AppTheme.solarGold),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الاحتياجات والمواد للزيارة القادمة',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                    Text(
                      'سجل قطع الغيار والمواد المطلوبة لحل هذا العطل',
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.solarGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, size: 15),
                label: const Text('طلب مادة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  QuickNeedDialog.show(
                    context,
                    report: widget.report,
                    relatedItem: item,
                    onSave: widget.onAddNeed,
                  );
                },
              ),
            ],
          ),
          if (hasNeeds) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ...widget.linkedNeeds.map((need) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: need.priority.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: need.priority.color, width: 0.8),
                      ),
                      child: Text(
                        need.priority.labelAr,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: need.priority.color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${need.name} (${need.quantity % 1 == 0 ? need.quantity.toInt() : need.quantity} ${need.unit})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          if (need.reason.isNotEmpty)
                            Text(
                              need.reason,
                              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 17, color: AppTheme.brandCyan),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        QuickNeedDialog.show(
                          context,
                          report: widget.report,
                          relatedItem: item,
                          existingNeed: need,
                          onSave: widget.onAddNeed,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 17, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onDeleteNeed(need.id),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
