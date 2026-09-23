import 'dart:convert';
import 'package:flutter/material.dart';
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
  });

  @override
  State<QuestionCardWidget> createState() => _QuestionCardWidgetState();
}

class _QuestionCardWidgetState extends State<QuestionCardWidget> {
  late TextEditingController _notesController;
  List<String> _presetNotes = [];
  bool _isLoadingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.question.item.notes);
    _notesController.addListener(_onNotesChanged);
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
      _loadPresetNotes();
    } else if (oldWidget.question.item.notes != widget.question.item.notes &&
        _notesController.text != widget.question.item.notes) {
      _notesController.text = widget.question.item.notes;
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
                  Row(
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
                      if (item.subcategory != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
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
                      const Spacer(),
                      Text(
                        'الحالة: ${item.status.labelAr}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: item.status.color,
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

          const SizedBox(height: 14),

          // Status Selection Cards (Large, Touch-Friendly)
          const Text(
            'نتيجة الفحص الميداني:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),

          _buildStatusOptions(item),

          const SizedBox(height: 16),

          // Quick Notes & Observations Header
          Row(
            children: [
              const Icon(Icons.quickreply_rounded, size: 16, color: AppTheme.primaryNavy),
              const SizedBox(width: 6),
              const Text(
                'الملاحظات والشرائح المقترحة:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              // Bookmark / Save Current Phrase
              if (_notesController.text.trim().isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 14, color: AppTheme.brandCyan),
                  label: const Text(
                    'حفظ العبارة',
                    style: TextStyle(fontSize: 11, color: AppTheme.brandCyan, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _saveCurrentPhrase,
                ),
              // Add New Preset Note Button
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add_circle_outline, size: 14, color: AppTheme.primaryNavy),
                label: const Text(
                  '+ ملاحظة مسبقة',
                  style: TextStyle(fontSize: 11, color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
                ),
                onPressed: _promptAddPresetNote,
              ),
              // Manage Notes Screen Icon
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.tune_rounded, size: 17, color: AppTheme.textMuted),
                tooltip: 'إدارة الملاحظات المسبقة',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PresetNotesManagerScreen(initialQuestionId: item.id),
                    ),
                  );
                  _loadPresetNotes();
                },
              ),
              if (item.notes.isNotEmpty) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    _notesController.clear();
                    widget.onUpdated(item.copyWith(notes: ''));
                  },
                  child: const Text('مسح', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Wrap of Preset Chips
          if (_isLoadingNotes)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_presetNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presetNotes.map((note) {
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
                        fontSize: 11,
                        fontWeight: isIncluded ? FontWeight.bold : FontWeight.normal,
                        color: isIncluded ? AppTheme.primaryNavy : AppTheme.textDark,
                      ),
                    ),
                    backgroundColor: isIncluded ? AppTheme.statusGood.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isIncluded ? AppTheme.statusGood.withValues(alpha: 0.5) : AppTheme.borderSubtle,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => _applyNoteChip(note),
                  );
                }).toList(),
              ),
            ),

          // Detailed Notes Text Field
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'أدخل أي ملاحظات فنية إضافية على هذا البند...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            onChanged: (val) {
              widget.onUpdated(item.copyWith(notes: val));
            },
          ),

          const SizedBox(height: 14),

          // Photo Attachment
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.borderSubtle),
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
                              Text('تم إرفاق صورة توثيقية للبند', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('ستظهر الصورة في ملحق التقرير المصدّر', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
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
          ),

          // Next Visit Material Requisition Section
          _buildNeedsSection(item),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNeedsSection(InspectionItem item) {
    final isProblematic = item.status == InspectionStatus.needsFollowup ||
        item.status == InspectionStatus.rejected;
    final hasNeeds = widget.linkedNeeds.isNotEmpty;

    if (!isProblematic && !hasNeeds) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isProblematic ? AppTheme.solarGold.withValues(alpha: 0.5) : AppTheme.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.solarGold.withValues(alpha: 0.06),
            blurRadius: 8,
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                    Text(
                      'سجل قطع الغيار والمواد المطلوبة لحل هذا العطل في الزيارة التالية',
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
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
                icon: const Icon(Icons.add, size: 16),
                label: const Text('طلب مادة', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: need.priority.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: need.priority.color, width: 0.8),
                      ),
                      child: Text(
                        need.priority.labelAr,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: need.priority.color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${need.name} (${need.quantity % 1 == 0 ? need.quantity.toInt() : need.quantity} ${need.unit})',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          if (need.reason.isNotEmpty)
                            Text(
                              need.reason,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.brandCyan),
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
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
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

  Widget _buildStatusOptions(InspectionItem item) {
    const statuses = [
      InspectionStatus.good,
      InspectionStatus.acceptable,
      InspectionStatus.needsFollowup,
      InspectionStatus.rejected,
      InspectionStatus.notApplicable,
    ];

    Color getStatusBg(InspectionStatus st, bool isSelected) {
      if (!isSelected) return Colors.white;
      switch (st) {
        case InspectionStatus.good:
          return AppTheme.statusGoodBg;
        case InspectionStatus.acceptable:
          return AppTheme.statusAcceptableBg;
        case InspectionStatus.needsFollowup:
          return AppTheme.statusFollowupBg;
        case InspectionStatus.rejected:
          return AppTheme.statusRejectedBg;
        case InspectionStatus.notApplicable:
        default:
          return AppTheme.statusNABg;
      }
    }

    return Column(
      children: statuses.map((st) {
        final isSelected = item.status == st;
        final bg = getStatusBg(st, isSelected);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              widget.onUpdated(item.copyWith(status: st));
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? st.color : AppTheme.borderSubtle,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: st.color.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? st.color : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                      color: isSelected ? st.color : Colors.white,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Icon(st.icon, color: st.color, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    st.labelAr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? st.color : AppTheme.textDark,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: st.color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'محدد',
                        style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
