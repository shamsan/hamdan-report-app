import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_reshaper.dart';
import '../../../models/measurement_data.dart';

class BatteryMatrixWidget extends StatefulWidget {
  final List<BatteryMeasurement> measurements;
  final ValueChanged<List<BatteryMeasurement>> onChanged;
  final List<int> activeGroups;
  final ValueChanged<List<int>>? onActiveGroupsChanged;

  const BatteryMatrixWidget({
    super.key,
    required this.measurements,
    required this.onChanged,
    this.activeGroups = const [1, 2, 3, 4],
    this.onActiveGroupsChanged,
  });

  @override
  State<BatteryMatrixWidget> createState() => _BatteryMatrixWidgetState();
}

class _BatteryMatrixWidgetState extends State<BatteryMatrixWidget> {
  late int _selectedGroup;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.activeGroups.isNotEmpty ? widget.activeGroups.first : 1;
  }

  @override
  void didUpdateWidget(covariant BatteryMatrixWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.activeGroups.contains(_selectedGroup)) {
      setState(() {
        _selectedGroup = widget.activeGroups.isNotEmpty ? widget.activeGroups.first : 1;
      });
    }
  }

  /// يضمن وجود 96 خلية مستقلة لكافة المجموعات الأربع لمنع التداخل
  List<BatteryMeasurement> _getNormalizedCells() {
    final list = List<BatteryMeasurement>.from(widget.measurements);
    if (list.length >= 96) return list;

    for (int i = list.length; i < 96; i++) {
      final g = (i ~/ 24) + 1;
      list.add(BatteryMeasurement(
        cellNumber: i + 1,
        stringNumber: g,
        voltage: 0.0,
        temperature: 0.0,
        boltTorque: 0.0,
        internalResistance: 0.0,
        notes: '',
      ));
    }
    return list;
  }

  void _updateCell(
    int cellIndex, {
    double? v,
    double? t,
    double? torque,
    double? r,
    String? notes,
    bool clearV = false,
    bool clearTorque = false,
    bool clearR = false,
    bool clearNotes = false,
  }) {
    final list = _getNormalizedCells();
    if (cellIndex < 0 || cellIndex >= list.length) return;

    final current = list[cellIndex];
    list[cellIndex] = current.copyWith(
      voltage: clearV ? 0.0 : (v ?? current.voltage),
      temperature: t ?? current.temperature,
      boltTorque: clearTorque ? 0.0 : (torque ?? current.boltTorque),
      internalResistance: clearR ? 0.0 : (r ?? current.internalResistance),
      notes: clearNotes ? '' : (notes ?? current.notes),
    );
    widget.onChanged(list);
  }

  void _applyGroupNote(String note) {
    final list = _getNormalizedCells();
    final startIndex = (_selectedGroup - 1) * 24;
    for (int i = 0; i < 24; i++) {
      final realIndex = startIndex + i;
      if (realIndex < list.length) {
        list[realIndex] = list[realIndex].copyWith(notes: note);
      }
    }
    widget.onChanged(list);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          note.isEmpty
              ? 'تم مسح ملاحظات المجموعة $_selectedGroup'
              : 'تم تطبيق ملاحظة "$note" على كافة خلايا المجموعة $_selectedGroup',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyGroupVoltage(double v) {
    final list = _getNormalizedCells();
    final startIndex = (_selectedGroup - 1) * 24;
    for (int i = 0; i < 24; i++) {
      final realIndex = startIndex + i;
      if (realIndex < list.length) {
        list[realIndex] = list[realIndex].copyWith(voltage: v);
      }
    }
    widget.onChanged(list);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تعيين جهد ${v.toStringAsFixed(2)}V لكافة خلايا المجموعة $_selectedGroup'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyGroupTorque(double torque) {
    final list = _getNormalizedCells();
    final startIndex = (_selectedGroup - 1) * 24;
    for (int i = 0; i < 24; i++) {
      final realIndex = startIndex + i;
      if (realIndex < list.length) {
        list[realIndex] = list[realIndex].copyWith(boltTorque: torque);
      }
    }
    widget.onChanged(list);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تعيين عزم ربط ${torque.toStringAsFixed(1)} N.m لكافة خلايا المجموعة $_selectedGroup'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearGroupMeasurements() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح قياسات المجموعة'),
        content: Text('هل أنت متأكد من مسح جميع قياسات المجموعة $_selectedGroup؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              final list = _getNormalizedCells();
              final startIndex = (_selectedGroup - 1) * 24;
              for (int i = 0; i < 24; i++) {
                final realIndex = startIndex + i;
                if (realIndex < list.length) {
                  list[realIndex] = list[realIndex].copyWith(
                    voltage: 0.0,
                    boltTorque: 0.0,
                    internalResistance: 0.0,
                    notes: '',
                  );
                }
              }
              widget.onChanged(list);
            },
            child: const Text('مسح', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cells = _getNormalizedCells();

    // Calculations for currently active groups only
    final activeCells = <BatteryMeasurement>[];
    for (final g in widget.activeGroups) {
      final start = (g - 1) * 24;
      if (start < cells.length) {
        activeCells.addAll(cells.skip(start).take(24));
      }
    }
    final calcCells = activeCells.isNotEmpty ? activeCells : cells;
    final measuredCells = calcCells.where((c) => c.voltage > 0).toList();

    final minV = measuredCells.isNotEmpty ? measuredCells.map((c) => c.voltage).reduce((a, b) => a < b ? a : b) : 0.0;
    final maxV = measuredCells.isNotEmpty ? measuredCells.map((c) => c.voltage).reduce((a, b) => a > b ? a : b) : 0.0;
    final avgV = measuredCells.isNotEmpty ? measuredCells.map((c) => c.voltage).reduce((a, b) => a + b) / measuredCells.length : 0.0;

    final startIndex = (_selectedGroup - 1) * 24;
    final groupCells = cells.skip(startIndex).take(24).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Groups Configuration Panel
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_suggest_rounded, size: 18, color: AppTheme.primaryNavy),
                      const SizedBox(width: 6),
                      Text(
                        'مجموعات البطاريات المطلوب ظهورها في التقرير (${widget.activeGroups.length} من 4)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primaryNavy),
                      ),
                    ],
                  ),
                  if (widget.onActiveGroupsChanged != null)
                    PopupMenuButton<String>(
                      tooltip: 'خيارات سريعة',
                      icon: const Icon(Icons.flash_on_rounded, size: 18, color: AppTheme.solarGold),
                      onSelected: (val) {
                        if (val == 'g1') widget.onActiveGroupsChanged!([1]);
                        if (val == 'g12') widget.onActiveGroupsChanged!([1, 2]);
                        if (val == 'all') widget.onActiveGroupsChanged!([1, 2, 3, 4]);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'g1', child: Text('موقع صغير: المجموعة 1 فقط')),
                        const PopupMenuItem(value: 'g12', child: Text('موقع متوسط: مجموعتان (1 و 2)')),
                        const PopupMenuItem(value: 'all', child: Text('موقع قياسي: كافة المجموعات (1 إلى 4)')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [1, 2, 3, 4].map((g) {
                  final isSelected = widget.activeGroups.contains(g);
                  return FilterChip(
                    label: Text('المجموعة $g'),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.18),
                    checkmarkColor: AppTheme.primaryNavy,
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryNavy : AppTheme.textSecondary,
                    ),
                    onSelected: widget.onActiveGroupsChanged == null ? null : (selected) {
                      final updated = List<int>.from(widget.activeGroups);
                      if (selected) {
                        if (!updated.contains(g)) updated.add(g);
                      } else {
                        if (updated.length > 1) {
                          updated.remove(g);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يجب إبقاء مجموعة واحدة على الأقل نشطة في التقرير')),
                          );
                        }
                      }
                      updated.sort();
                      widget.onActiveGroupsChanged!(updated);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    widget.activeGroups.length <= 2 ? Icons.check_circle_outline : Icons.info_outline,
                    size: 14,
                    color: widget.activeGroups.length <= 2 ? AppTheme.statusGood : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.activeGroups.length <= 2
                          ? 'سيتم توليد صفحة واحدة مخصصة للبطاريات في التقرير (Page 6) بخط كبير وواضح مع ترقيم صفحات تلقائي.'
                          : 'سيتم توليد صفحتين متتاليتين للبطاريات في التقرير لتغطية المجموعات الـ 4.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: widget.activeGroups.length <= 2 ? Colors.green.shade800 : AppTheme.textMuted,
                        fontWeight: widget.activeGroups.length <= 2 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Header & Clear Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'بيانات قياسات الخلايا (${widget.activeGroups.length * 24} خلية نشطة)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textDark),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.cleaning_services_rounded, size: 14),
              label: Text('مسح قياسات المجموعة $_selectedGroup', style: const TextStyle(fontSize: 11)),
              onPressed: _clearGroupMeasurements,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Live Stats Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatPill('أقل جهد', minV > 0 ? '${minV.toStringAsFixed(2)} V' : '--', AppTheme.statusFollowup),
              const SizedBox(width: 10),
              _buildStatPill('متوسط الجهد', avgV > 0 ? '${avgV.toStringAsFixed(2)} V' : '--', AppTheme.primaryNavy),
              const SizedBox(width: 10),
              _buildStatPill('أعلى جهد', maxV > 0 ? '${maxV.toStringAsFixed(2)} V' : '--', AppTheme.statusGood),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Group Selector Tabs (Showing active groups)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: (widget.activeGroups.isNotEmpty ? widget.activeGroups : [1, 2, 3, 4]).map((g) {
              final isSel = _selectedGroup == g;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  key: ValueKey('group_chip_$g'),
                  label: Text('المجموعة $g (خلايا ${(g - 1) * 24 + 1} - ${g * 24})'),
                  selected: isSel,
                  selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                    color: isSel ? AppTheme.primaryNavy : AppTheme.textSecondary,
                  ),
                  side: BorderSide(
                    color: isSel ? AppTheme.primaryNavy : AppTheme.borderSubtle,
                    width: isSel ? 1.5 : 1.0,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (_) => setState(() => _selectedGroup = g),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Quick Note Action Bar for Active Group
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.solarGold),
              const SizedBox(width: 6),
              Text(
                'ملاحظة للمجموعة $_selectedGroup:',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickNoteChip('سليمة'),
                      const SizedBox(width: 6),
                      _buildQuickNoteChip('فحص دوري'),
                      const SizedBox(width: 6),
                      _buildQuickNoteChip('تحتاج متابعة'),
                      const SizedBox(width: 6),
                      _buildQuickNoteChip('مسح الكل', isClear: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Quick Voltage Action Bar for Active Group
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.brandCyan),
              const SizedBox(width: 6),
              Text(
                'جهد موحد للمجموعة $_selectedGroup:',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickVoltageChip(2.14),
                      const SizedBox(width: 6),
                      _buildQuickVoltageChip(2.15),
                      const SizedBox(width: 6),
                      _buildQuickVoltageChip(2.16),
                      const SizedBox(width: 6),
                      _buildQuickVoltageChip(2.18),
                      const SizedBox(width: 6),
                      _buildQuickVoltageChip(2.20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Quick Torque Action Bar for Active Group
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.build_circle_rounded, size: 16, color: AppTheme.primaryNavy),
              const SizedBox(width: 6),
              Text(
                'عزم ربط للمجموعة $_selectedGroup:',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickTorqueChip(10.0),
                      const SizedBox(width: 6),
                      _buildQuickTorqueChip(11.0),
                      const SizedBox(width: 6),
                      _buildQuickTorqueChip(12.0),
                      const SizedBox(width: 6),
                      _buildQuickTorqueChip(13.0),
                      const SizedBox(width: 6),
                      _buildQuickTorqueChip(15.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: const [
              SizedBox(
                width: 36,
                child: Text('م', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textMuted), textAlign: TextAlign.center),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text('الجهد (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textDark)),
              ),
              SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Text('عزم الربط (N.m)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textDark)),
              ),
              SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text('الملاحظات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textDark)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Cells List — Keyed to prevent State reuse across groups
        ListView.separated(
          key: ValueKey('cells_list_group_$_selectedGroup'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groupCells.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, idx) {
            final cell = groupCells[idx];
            final realIndex = startIndex + idx;
            final isArNote = ArabicReshaper.hasArabic(cell.notes);
            final isUnmeasured = cell.voltage <= 0;

            return Container(
              key: ValueKey('cell_row_${cell.cellNumber}_group_$_selectedGroup'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isUnmeasured
                    ? const Color(0xFFFFFBEB)
                    : (idx.isEven ? const Color(0xFFF8FAFC) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isUnmeasured ? const Color(0xFFF59E0B) : AppTheme.borderSubtle,
                  width: isUnmeasured ? 1.2 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Cell Number Badge (local 1..24 and global #1..96)
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isUnmeasured
                          ? const Color(0xFFFEF3C7)
                          : AppTheme.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: isUnmeasured ? const Color(0xFFB45309) : AppTheme.primaryNavy,
                          ),
                        ),
                        Text(
                          '#${cell.cellNumber}',
                          style: const TextStyle(fontSize: 8.5, color: AppTheme.textMuted, height: 1.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Voltage Input (V)
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: ValueKey('v_${cell.cellNumber}_g_$_selectedGroup'),
                      initialValue: cell.voltage > 0 ? '${cell.voltage}' : '',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (val) {
                        final trimmed = val.trim();
                        if (trimmed.isEmpty) {
                          _updateCell(realIndex, clearV: true);
                        } else {
                          final v = double.tryParse(trimmed);
                          if (v != null) _updateCell(realIndex, v: v);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Bolt Torque Input (N.m)
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: ValueKey('torque_${cell.cellNumber}_g_$_selectedGroup'),
                      initialValue: cell.boltTorque > 0 ? '${cell.boltTorque}' : '',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: '0.0',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (val) {
                        final trimmed = val.trim();
                        if (trimmed.isEmpty) {
                          _updateCell(realIndex, clearTorque: true);
                        } else {
                          final t = double.tryParse(trimmed);
                          if (t != null) _updateCell(realIndex, torque: t);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Notes Input — Language-adaptive direction & alignment
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      key: ValueKey('n_${cell.cellNumber}_g_$_selectedGroup'),
                      initialValue: cell.notes,
                      textDirection: isArNote ? TextDirection.rtl : TextDirection.ltr,
                      textAlign: isArNote ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(fontSize: 11.5),
                      decoration: const InputDecoration(
                        hintText: 'الملاحظة...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (val) {
                        final trimmed = val.trim();
                        if (trimmed.isEmpty) {
                          _updateCell(realIndex, clearNotes: true);
                        } else {
                          _updateCell(realIndex, notes: trimmed);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickNoteChip(String label, {bool isClear = false}) {
    return InkWell(
      onTap: () => _applyGroupNote(isClear ? '' : label),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isClear ? Colors.red.shade50 : AppTheme.primaryNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isClear ? Colors.red.shade200 : AppTheme.primaryNavy.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isClear ? Colors.red.shade700 : AppTheme.primaryNavy,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickVoltageChip(double v) {
    return InkWell(
      onTap: () => _applyGroupVoltage(v),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.brandCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.brandCyan.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Text(
          '${v.toStringAsFixed(2)}V',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryNavy,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTorqueChip(double torque) {
    return InkWell(
      onTap: () => _applyGroupTorque(torque),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppTheme.primaryNavy.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Text(
          '${torque.toStringAsFixed(0)} N.m',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryNavy,
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, fontFamily: 'Cairo'),
        ),
      ],
    );
  }
}
