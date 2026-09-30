import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/inspection_item.dart';
import '../../services/default_templates.dart';
import '../../services/preset_notes_service.dart';

/// Screen allowing engineers to configure and manage preset inspection notes in advance
/// for every question/group in the maintenance checklist.
class PresetNotesManagerScreen extends StatefulWidget {
  final String? initialQuestionId;

  const PresetNotesManagerScreen({
    super.key,
    this.initialQuestionId,
  });

  @override
  State<PresetNotesManagerScreen> createState() => _PresetNotesManagerScreenState();
}

class _PresetNotesManagerScreenState extends State<PresetNotesManagerScreen> {
  late List<InspectionGroup> _groups;
  int _selectedGroupIndex = 0;
  String _searchQuery = '';
  final Map<String, List<String>> _loadedNotes = {};
  final Set<String> _customNotesKeys = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _groups = DefaultTemplates.defaultInspectionGroups;
    if (widget.initialQuestionId != null) {
      for (int i = 0; i < _groups.length; i++) {
        if (_groups[i].items.any((it) => it.id == widget.initialQuestionId)) {
          _selectedGroupIndex = i;
          break;
        }
      }
    }
    _loadAllNotes();
  }

  Future<void> _loadAllNotes() async {
    setState(() => _isLoading = true);
    for (final g in _groups) {
      for (final it in g.items) {
        final notes = await PresetNotesService.getNotesForQuestion(
          it.id,
          subcategory: it.subcategory,
          description: it.description,
        );
        _loadedNotes[it.id] = notes;

        final custom = await PresetNotesService.getCustomNotes(it.id, description: it.description);
        for (final c in custom) {
          _customNotesKeys.add('${it.id}_$c');
        }
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _promptAddNote(InspectionItem item) async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.brandCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.note_add_rounded, color: AppTheme.brandCyan, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'إضافة ملاحظة مسبقة جديدة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'البند: بند ${item.serialNo} - ${item.description}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    if (item.subcategory != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.subcategory!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'أدخل نص الملاحظة الجاهزة التي ترغب بظهورها لهذا السؤال دائماً:',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'مثال: تم الفحص والتأكد من سلامة التوصيلات...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('حفظ الملاحظة', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (added == true && controller.text.trim().isNotEmpty) {
      final note = controller.text.trim();
      await PresetNotesService.addCustomNote(item.id, note, description: item.description);
      _customNotesKeys.add('${item.id}_$note');
      final updated = await PresetNotesService.getNotesForQuestion(
        item.id,
        subcategory: item.subcategory,
        description: item.description,
      );
      setState(() {
        _loadedNotes[item.id] = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إضافة الملاحظة المسبقة بنجاح وستظهر في جلسات الفحص القادمة'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomNote(InspectionItem item, String note) async {
    await PresetNotesService.removeCustomNote(item.id, note, description: item.description);
    _customNotesKeys.remove('${item.id}_$note');
    final updated = await PresetNotesService.getNotesForQuestion(
      item.id,
      subcategory: item.subcategory,
      description: item.description,
    );
    setState(() {
      _loadedNotes[item.id] = updated;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الملاحظة المخصصة'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentGroup = _groups[_selectedGroupIndex];
    final items = currentGroup.items.where((it) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final desc = it.description.toLowerCase();
      final sub = (it.subcategory ?? '').toLowerCase();
      return desc.contains(query) || sub.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملاحظات المسبقة لنماذج الفحص'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الملاحظات',
            onPressed: _loadAllNotes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Info & Search Box
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.playlist_add_check_rounded, color: AppTheme.primaryNavy, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تخصيص الملاحظات التلقائية مسبقاً',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                ),
                                Text(
                                  'أضف عباراتك الفنية الشائعة لتظهر كأزرار سريعة في جلسة الفحص الميداني',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'بحث في بنود الفحص...',
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ],
                  ),
                ),

                // Groups Tabs Bar
                Container(
                  height: 46,
                  color: const Color(0xFFF1F5F9),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _groups.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final isSel = idx == _selectedGroupIndex;
                      final g = _groups[idx];
                      return ChoiceChip(
                        label: Text('مجموعة ${g.groupNumber}: ${g.title}'),
                        selected: isSel,
                        selectedColor: AppTheme.primaryNavy,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? Colors.white : AppTheme.textDark,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSel ? AppTheme.primaryNavy : AppTheme.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (val) {
                          if (val) setState(() => _selectedGroupIndex = idx);
                        },
                      );
                    },
                  ),
                ),

                // Questions and Preset Notes List
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('لا توجد بنود مطابقة للبحث'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, idx) {
                            final item = items[idx];
                            final notes = _loadedNotes[item.id] ?? [];

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.borderSubtle),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Question Header
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'بند ${item.serialNo}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryNavy,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.description,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textDark,
                                              ),
                                            ),
                                            if (item.subcategory != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item.subcategory!,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.brandCyan.withValues(alpha: 0.12),
                                          foregroundColor: AppTheme.brandCyan,
                                          minimumSize: const Size(0, 40),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text('إضافة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          _promptAddNote(item);
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),

                                  // Preset Notes Chips
                                  const Text(
                                    'الملاحظات المسبقة المتاحة لهذا البند:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: notes.map((note) {
                                      final isCustom = _customNotesKeys.contains('${item.id}_$note');

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCustom ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isCustom ? const Color(0xFF93C5FD) : AppTheme.borderSubtle,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isCustom) ...[
                                              const Icon(Icons.star_rounded, size: 13, color: Color(0xFF2563EB)),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              note,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isCustom ? const Color(0xFF1E40AF) : AppTheme.textDark,
                                                fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                            if (isCustom) ...[
                                              const SizedBox(width: 4),
                                              InkWell(
                                                onTap: () => _deleteCustomNote(item, note),
                                                child: const Icon(Icons.close, size: 13, color: Colors.red),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
