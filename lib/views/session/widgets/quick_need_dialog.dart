import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inspection_item.dart';
import '../../../models/maintenance_need.dart';
import '../../../models/report.dart';
import '../../../services/camera_service.dart';

class QuickNeedDialog extends StatefulWidget {
  final Report report;
  final InspectionItem? relatedItem;
  final MaintenanceNeedItem? existingNeed;
  final ValueChanged<MaintenanceNeedItem> onSave;

  const QuickNeedDialog({
    super.key,
    required this.report,
    this.relatedItem,
    this.existingNeed,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required Report report,
    InspectionItem? relatedItem,
    MaintenanceNeedItem? existingNeed,
    required ValueChanged<MaintenanceNeedItem> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickNeedDialog(
        report: report,
        relatedItem: relatedItem,
        existingNeed: existingNeed,
        onSave: onSave,
      ),
    );
  }

  @override
  State<QuickNeedDialog> createState() => _QuickNeedDialogState();
}

class _QuickNeedDialogState extends State<QuickNeedDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;

  String _selectedCategory = 'قواطع DC';
  String _selectedUnit = 'حبة';
  NeedPriority _selectedPriority = NeedPriority.urgent;
  String? _photoBase64;

  static const List<String> _categories = [
    'قواطع DC',
    'بطاريات',
    'إنفرتر ومحولات',
    'كابلات وتوصيلات',
    'تأريض وحماية',
    'ألواح وهياكل',
    'عام',
  ];

  static const Map<String, List<String>> _quickSuggestions = {
    'قواطع DC': [
      'قاطع تيار DC 125A 2P',
      'قاطع تيار DC 63A',
      'فيوز أسطواني 1000V 15A',
      'مقبس فيوز DC Din-Rail',
    ],
    'بطاريات': [
      'بطارية جل 12V 200Ah',
      'كابل ربط بيني 35mm²',
      'مرابط نحاسية مطلية بقصدير',
      'حامل بطاريات معدني مجلفن',
    ],
    'إنفرتر ومحولات': [
      'مروحة تبريد إنفرتر داخلية',
      'حساس حرارة البطاريات BTS',
      'كابل اتصال اتصالات RS485',
      'قاطع مدخل التيار المتناوب AC',
    ],
    'كابلات وتوصيلات': [
      'كابل طاقة شمسية 6mm² (أحمر)',
      'كابل طاقة شمسية 6mm² (أسود)',
      'طقم موصلات MC4 ذكر/أنثى',
      'مرابط ضغط نحاسية (Lugs)',
    ],
    'تأريض وحماية': [
      'مانعة صواعق DC SPD 1000V',
      'مانعة صواعق AC SPD',
      'قضيب تأريض نحاسي 1.5م',
      'مشبك توصيل نحاسي للتأريض',
    ],
    'ألواح وهياكل': [
      'لوح شمسي Monocrystalline',
      'مرابط وسطية Mid-Clamp',
      'مرابط طرفية End-Clamp',
      'صواميل تثبيت فولاذ مقاوم للصدأ',
    ],
    'عام': [
      'شريط عازل عالي الجودة',
      'سائل تنظيف ألواح شمسية',
      'جل حماية أقطاب البطاريات',
      'ملصقات تحذيرية للمنظومة',
    ],
  };

  static const List<String> _units = [
    'حبة',
    'متر',
    'طقم',
    'لفة',
    'علبة',
    'كيلو',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existingNeed;
    if (e != null) {
      _nameController = TextEditingController(text: e.name);
      _quantityController = TextEditingController(
        text: e.quantity % 1 == 0 ? e.quantity.toInt().toString() : e.quantity.toString(),
      );
      _reasonController = TextEditingController(text: e.reason);
      _selectedCategory = e.category;
      _selectedUnit = e.unit;
      _selectedPriority = e.priority;
      _photoBase64 = e.photoBase64;
    } else {
      _nameController = TextEditingController();
      _quantityController = TextEditingController(text: '1');
      _reasonController = TextEditingController(
        text: widget.relatedItem?.notes.isNotEmpty == true ? widget.relatedItem!.notes : '',
      );

      // Guess category from subcategory if available
      final sub = widget.relatedItem?.subcategory ?? '';
      if (sub.contains('بطار')) {
        _selectedCategory = 'بطاريات';
      } else if (sub.contains('قواطع') || sub.contains('DC')) {
        _selectedCategory = 'قواطع DC';
      } else if (sub.contains('إنفرتر') || sub.contains('محول')) {
        _selectedCategory = 'إنفرتر ومحولات';
      } else if (sub.contains('تأريض') || sub.contains('حماية')) {
        _selectedCategory = 'تأريض وحماية';
      } else if (sub.contains('ألواح') || sub.contains('هيكل')) {
        _selectedCategory = 'ألواح وهياكل';
      }

      _photoBase64 = widget.relatedItem?.photoBase64;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _stepQuantity(double delta) {
    double current = double.tryParse(_quantityController.text) ?? 1;
    current += delta;
    if (current < 0.5) current = 0.5;
    setState(() {
      _quantityController.text = current % 1 == 0 ? current.toInt().toString() : current.toString();
    });
  }

  Future<void> _capturePhoto() async {
    final bytes = await CameraService.capturePhotoFromCamera();
    if (bytes != null) {
      setState(() {
        _photoBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _pickPhoto() async {
    final bytes = await CameraService.pickImageFromGallery();
    if (bytes != null) {
      setState(() {
        _photoBase64 = base64Encode(bytes);
      });
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة أو اختيار اسم المادة المطلوبة')),
      );
      return;
    }

    final currentVisit = widget.report.visitNumber.isNotEmpty ? widget.report.visitNumber : '1';
    final targetVisitNum = ((int.tryParse(currentVisit) ?? 1) + 1).toString();
    final qty = double.tryParse(_quantityController.text.trim()) ?? 1.0;

    final need = (widget.existingNeed != null)
        ? widget.existingNeed!.copyWith(
            name: name,
            quantity: qty,
            unit: _selectedUnit,
            category: _selectedCategory,
            priority: _selectedPriority,
            reason: _reasonController.text.trim(),
            photoBase64: _photoBase64,
          )
        : MaintenanceNeedItem(
            id: 'need_${const Uuid().v4().substring(0, 8)}',
            facilityName: widget.report.facilityInfo.facilityName,
            currentVisitNumber: currentVisit,
            targetVisitNumber: targetVisitNum,
            name: name,
            quantity: qty,
            unit: _selectedUnit,
            category: _selectedCategory,
            priority: _selectedPriority,
            reason: _reasonController.text.trim(),
            relatedInspectionItemId: widget.relatedItem?.id,
            relatedInspectionItemTitle: widget.relatedItem?.description,
            photoBase64: _photoBase64,
            createdAt: DateTime.now(),
          );

    widget.onSave(need);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentVisit = widget.report.visitNumber.isNotEmpty ? widget.report.visitNumber : '1';
    final targetVisit = ((int.tryParse(currentVisit) ?? 1) + 1).toString();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
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
            const SizedBox(height: 14),

            // Header with Target Visit Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.solarGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.build_circle_outlined, color: AppTheme.solarGold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingNeed != null ? 'تعديل مادة مطلوبة' : 'طلب مادة / قطعة غيار للزيارة القادمة',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.brandCyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'الزيارة الحالية: $currentVisit ➔ الزيارة القادمة: $targetVisit',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.brandCyan),
                            ),
                          ),
                          if (widget.relatedItem != null)
                            Text(
                              '• ${widget.relatedItem!.description}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            // Category Chips
            const Text(
              'تصنيف القطعة / المنظومة:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      selected: isSel,
                      selectedColor: AppTheme.primaryNavy,
                      labelStyle: TextStyle(color: isSel ? Colors.white : AppTheme.textDark),
                      checkmarkColor: Colors.white,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Quick Suggestions based on Category
            if (_quickSuggestions.containsKey(_selectedCategory)) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickSuggestions[_selectedCategory]!.map((item) {
                  return ActionChip(
                    backgroundColor: const Color(0xFFF1F5F9),
                    label: Text(item, style: const TextStyle(fontSize: 11, color: AppTheme.primaryNavy)),
                    avatar: const Icon(Icons.add, size: 14, color: AppTheme.brandCyan),
                    onPressed: () {
                      setState(() {
                        _nameController.text = item;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Item Name TextField
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'اسم المادة / مواصفة قطعة الغيار *',
                hintText: 'مثال: قاطع DC 125A ماركة شنايدر أو كابل 16مم²',
                prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppTheme.brandCyan),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Quantity & Unit Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => _stepQuantity(-1),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _quantityController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'الكمية',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => _stepQuantity(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: 'الوحدة',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedUnit = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Priority Selection
            const Text(
              'درجة الأولوية والتأثير:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            Row(
              children: NeedPriority.values.map((p) {
                final isSel = _selectedPriority == p;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _selectedPriority = p),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? p.color : p.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.color, width: isSel ? 1.5 : 0.8),
                        ),
                        child: Column(
                          children: [
                            Icon(p.icon, size: 18, color: isSel ? Colors.white : p.color),
                            const SizedBox(height: 3),
                            Text(
                              p.labelAr,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : p.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Reason / Notes TextField
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'سبب الطلب والملاحظات الفنية',
                hintText: 'مثال: تلف القاطع بسبب حرارة عالية ويشكل خطورة على الإنفرتر',
                prefixIcon: const Icon(Icons.notes_rounded, color: AppTheme.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            // Photo Capture Row
            Row(
              children: [
                if (_photoBase64 != null && _photoBase64!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(_photoBase64!),
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'حذف الصورة',
                    onPressed: () => setState(() => _photoBase64 = null),
                  ),
                  const Spacer(),
                ] else ...[
                  const Text('توثيق بالصورة (اختياري):', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const Spacer(),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: const Text('كاميرا', style: TextStyle(fontSize: 12)),
                  onPressed: _capturePhoto,
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.photo_library, size: 16),
                  label: const Text('معرض', style: TextStyle(fontSize: 12)),
                  onPressed: _pickPhoto,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Submit Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20, color: AppTheme.solarGold),
              label: Text(
                widget.existingNeed != null ? 'حفظ التعديلات' : 'إضافة المادة للزيارة القادمة (الزيارة $targetVisit)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
