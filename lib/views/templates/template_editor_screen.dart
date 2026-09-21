import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/report_template.dart';
import '../../core/theme/app_theme.dart';
import '../../state/templates_provider.dart';

class TemplateEditorScreen extends ConsumerStatefulWidget {
  final ReportTemplate? template;

  const TemplateEditorScreen({super.key, this.template});

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late List<TemplatePage> _pages;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _titleController = TextEditingController(text: t?.title ?? 'قالب تقرير جديد');
    _descController = TextEditingController(text: t?.description ?? 'وصف القالب ومجال استخدامه');
    _pages = t?.pages.map((p) => p.copyWith(elements: List.from(p.elements))).toList() ?? [
      const TemplatePage(
        pageNumber: 1,
        title: 'صفحة الغلاف والبيانات الأساسية',
        isLandscape: false,
        elements: [
          PageElement(id: 'el_1', type: ElementType.header, title: 'الترويسة الرسمية والشعارات'),
          PageElement(id: 'el_2', type: ElementType.table, title: 'جدول بيانات المشروع والمنشأة'),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addPage() {
    setState(() {
      _pages.add(TemplatePage(
        pageNumber: _pages.length + 1,
        title: 'صفحة جديدة رقم ${_pages.length + 1}',
        isLandscape: false,
        elements: [
          const PageElement(id: 'el_new', type: ElementType.inspectionTable, title: 'جدول فحص معياري'),
        ],
      ));
    });
  }

  void _addElement(int pageIndex) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إضافة عنصر جديد للصفحة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.blue),
              title: const Text('جدول فحص معياري مع حالات تقييم'),
              onTap: () => _insertElement(pageIndex, ElementType.inspectionTable, 'جدول فحص جديد', ctx),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on, color: Colors.teal),
              title: const Text('جدول قياسات رقمي'),
              onTap: () => _insertElement(pageIndex, ElementType.measurementTable, 'جدول قياسات تشغيلية', ctx),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields, color: Colors.amber),
              title: const Text('نص منسق مع متغيرات ديناميكية {{اسم_المشروع}}'),
              onTap: () => _insertElement(pageIndex, ElementType.richText, 'نص رسمي', ctx),
            ),
            ListTile(
              leading: const Icon(Icons.draw, color: Colors.indigo),
              title: const Text('مربع توقيع واعتماد'),
              onTap: () => _insertElement(pageIndex, ElementType.signatureBox, 'منطقة التوقيع والاعتماد', ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _insertElement(int pageIndex, ElementType type, String title, BuildContext sheetContext) {
    Navigator.pop(sheetContext);
    const uuid = Uuid();
    setState(() {
      final updatedElements = List<PageElement>.from(_pages[pageIndex].elements)
        ..add(PageElement(id: 'el_${uuid.v4().substring(0, 6)}', type: type, title: title));
      _pages[pageIndex] = _pages[pageIndex].copyWith(elements: updatedElements);
    });
  }

  Future<void> _saveTemplate() async {
    const uuid = Uuid();
    final templateToSave = ReportTemplate(
      id: widget.template?.id ?? 'tmpl_${uuid.v4().substring(0, 8)}',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: widget.template?.category ?? 'طاقة شمسية',
      isDefault: widget.template?.isDefault ?? false,
      isLocked: false,
      pages: _pages,
      updatedAt: DateTime.now(),
    );

    await ref.read(templatesProvider.notifier).saveTemplate(templateToSave);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ القالب: "${templateToSave.title}" بنجاح')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المحرر البصري للقوالب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'حفظ القالب',
            onPressed: _saveTemplate,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template Info Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'اسم القالب',
                      prefixIcon: Icon(Icons.title_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'وصف القالب ومجال استخدامه',
                      prefixIcon: Icon(Icons.description_outlined, size: 20),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'صفحات القالب (${_pages.length} صفحات)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textDark),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_to_photos_rounded, size: 16),
                  label: const Text('إضافة صفحة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _addPage,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Pages List
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pages.length,
              // ignore: deprecated_member_use
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = _pages.removeAt(oldIdx);
                  _pages.insert(newIdx, item);
                  // Update page numbers
                  for (int i = 0; i < _pages.length; i++) {
                    _pages[i] = _pages[i].copyWith();
                  }
                });
              },
              itemBuilder: (context, pIdx) {
                final page = _pages[pIdx];
                return Container(
                  key: ValueKey('page_${page.pageNumber}_$pIdx'),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.drag_handle_rounded, color: AppTheme.textMuted),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primaryNavy,
                            child: Text('${pIdx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: page.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: (val) {
                                _pages[pIdx] = page.copyWith(title: val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Orientation toggle
                          ChoiceChip(
                            label: Text(page.isLandscape ? 'أفقي' : 'عمودي'),
                            selected: page.isLandscape,
                            onSelected: (val) {
                              setState(() {
                                _pages[pIdx] = page.copyWith(isLandscape: val);
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.statusRejected, size: 20),
                            onPressed: _pages.length > 1
                                ? () => setState(() => _pages.removeAt(pIdx))
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('العناصر الموجودة في هذه الصفحة:', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                      const SizedBox(height: 8),
                      ...page.elements.asMap().entries.map((e) {
                        final elIdx = e.key;
                        final el = e.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_box_outlined, size: 16, color: AppTheme.primaryNavy),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(el.title, style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                                onPressed: () {
                                  setState(() {
                                    final updatedEls = List<PageElement>.from(page.elements)..removeAt(elIdx);
                                    _pages[pIdx] = page.copyWith(elements: updatedEls);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('إضافة عنصر جديد لهذه الصفحة', style: TextStyle(fontSize: 11.5)),
                        onPressed: () => _addElement(pIdx),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
