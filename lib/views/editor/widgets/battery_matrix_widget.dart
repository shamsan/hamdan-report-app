import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_reshaper.dart';
import '../../../models/measurement_data.dart';

// ════════════════════════════════════════════════════════════════════
// BatteryMatrixWidget — Redesigned with Progressive Disclosure
// ────────────────────────────────────────────────────────────────────
// Design principles applied:
//  1. Progressive Disclosure — only essential UI visible by default
//  2. Mobile-First — large touch targets (≥44dp), readable fonts (≥12sp)
//  3. Responsive — Wrap-based chips, LayoutBuilder-aware padding
//  4. Interactive — haptic feedback, smooth animations, visual progress
//  5. Clean hierarchy — group config in bottom sheet, actions collapsible
// ════════════════════════════════════════════════════════════════════

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
  int _groupRevision = 0;

  // Progressive Disclosure state
  bool _isStatsExpanded = false;
  bool _isQuickActionsExpanded = false;
  int _activeQuickTab = 0; // 0=voltage, 1=torque, 2=notes

  // ─── Lifecycle ─────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedGroup =
        widget.activeGroups.isNotEmpty ? widget.activeGroups.first : 1;
  }

  @override
  void didUpdateWidget(covariant BatteryMatrixWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.activeGroups.contains(_selectedGroup)) {
      setState(() {
        _selectedGroup =
            widget.activeGroups.isNotEmpty ? widget.activeGroups.first : 1;
      });
    }
  }

  // ─── Data Helpers ──────────────────────────────────────────────

  List<BatteryMeasurement> _getNormalizedCells() {
    final list = List<BatteryMeasurement>.from(widget.measurements);
    if (list.length >= 96) return list;
    for (int i = list.length; i < 96; i++) {
      final g = (i ~/ 24) + 1;
      list.add(BatteryMeasurement(
        cellNumber: i + 1,
        stringNumber: g,
      ));
    }
    return list;
  }

  void _updateCell(
    int cellIndex, {
    double? v,
    double? torque,
    String? notes,
    bool clearV = false,
    bool clearTorque = false,
    bool clearNotes = false,
  }) {
    final list = _getNormalizedCells();
    if (cellIndex < 0 || cellIndex >= list.length) return;
    final current = list[cellIndex];
    list[cellIndex] = current.copyWith(
      voltage: clearV ? 0.0 : (v ?? current.voltage),
      boltTorque: clearTorque ? 0.0 : (torque ?? current.boltTorque),
      notes: clearNotes ? '' : (notes ?? current.notes),
    );
    widget.onChanged(list);
  }

  void _applyGroupVoltage(double v, {bool withVariance = false}) {
    HapticFeedback.lightImpact();
    final list = _getNormalizedCells();
    final startIndex = (_selectedGroup - 1) * 24;
    final varianceOffsets = [
      0.00, 0.01, -0.01, 0.00, 0.01, -0.01, 0.00, 0.00,
      0.01, -0.01, 0.00, 0.01, -0.01, 0.00, 0.01, 0.00,
      -0.01, 0.00, 0.01, -0.01, 0.00, 0.00, 0.01, -0.01,
    ];
    for (int i = 0; i < 24; i++) {
      final realIndex = startIndex + i;
      if (realIndex < list.length) {
        final cellV = withVariance
            ? double.parse(
                (v + varianceOffsets[i % varianceOffsets.length])
                    .toStringAsFixed(2))
            : v;
        list[realIndex] = list[realIndex].copyWith(voltage: cellV);
      }
    }
    setState(() => _groupRevision++);
    widget.onChanged(list);
    _showFeedback(
      withVariance
          ? 'تم تطبيق جهد واقعي (${v.toStringAsFixed(2)}V ±0.01)'
          : 'تم تعيين ${v.toStringAsFixed(2)}V للمجموعة $_selectedGroup',
    );
  }

  void _applyGroupTorque(double torque) {
    HapticFeedback.lightImpact();
    final list = _getNormalizedCells();
    final startIndex = (_selectedGroup - 1) * 24;
    for (int i = 0; i < 24; i++) {
      final realIndex = startIndex + i;
      if (realIndex < list.length) {
        list[realIndex] = list[realIndex].copyWith(boltTorque: torque);
      }
    }
    setState(() => _groupRevision++);
    widget.onChanged(list);
    _showFeedback('تم تعيين عزم ${torque.toStringAsFixed(1)} N.m');
  }

  void _applyGroupNote(String note) {
    HapticFeedback.lightImpact();
    final list = _getNormalizedCells();
    final startIndex = (_selectedGroup - 1) * 24;
    for (int i = 0; i < 24; i++) {
      final realIndex = startIndex + i;
      if (realIndex < list.length) {
        list[realIndex] = list[realIndex].copyWith(notes: note);
      }
    }
    setState(() => _groupRevision++);
    widget.onChanged(list);
    _showFeedback(note.isEmpty ? 'تم مسح الملاحظات' : 'تم تطبيق "$note"');
  }

  void _clearGroupMeasurements() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 22),
            const SizedBox(width: 8),
            const Text('مسح قياسات المجموعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('سيتم مسح جميع بيانات المجموعة $_selectedGroup.\nهل أنت متأكد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              final list = _getNormalizedCells();
              final startIndex = (_selectedGroup - 1) * 24;
              for (int i = 0; i < 24; i++) {
                final realIndex = startIndex + i;
                if (realIndex < list.length) {
                  list[realIndex] = list[realIndex].copyWith(
                    voltage: 0.0,
                    boltTorque: 0.0,
                    notes: '',
                  );
                }
              }
              setState(() => _groupRevision++);
              widget.onChanged(list);
            },
            label: const Text('مسح'),
          ),
        ],
      ),
    );
  }

  void _showFeedback(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  // ─── Dialogs & Bottom Sheets ───────────────────────────────────

  void _showCustomVoltageDialog() {
    final ctrl = TextEditingController(text: '2.15');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.brandCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: AppTheme.brandCyan, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'جهد مخصص — المجموعة $_selectedGroup',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'الجهد (V)',
            hintText: '2.15',
            suffixText: 'V',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                _applyGroupVoltage(val);
              }
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  void _showCustomTorqueDialog() {
    final ctrl = TextEditingController(text: '12.0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.build_circle_rounded, color: AppTheme.primaryNavy, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'عزم ربط مخصص — المجموعة $_selectedGroup',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'عزم الربط (N.m)',
            hintText: '12.0',
            suffixText: 'N.m',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                _applyGroupTorque(val);
              }
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet for group configuration — replaces the always-visible panel
  void _showGroupConfigSheet() {
    final localGroups = List<int>.from(widget.activeGroups);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                  top: 12, left: 20, right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.settings_rounded, size: 20, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('إعدادات المجموعات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                              SizedBox(height: 2),
                              Text('حدد المجموعات التي ستظهر في التقرير', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Group toggles
                    ...List.generate(4, (i) {
                      final g = i + 1;
                      final isActive = localGroups.contains(g);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primaryNavy.withValues(alpha: 0.04) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive ? AppTheme.primaryNavy.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: SwitchListTile.adaptive(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                          secondary: Container(
                            width: 40, height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isActive ? AppTheme.primaryNavy.withValues(alpha: 0.1) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$g',
                              style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16,
                                color: isActive ? AppTheme.primaryNavy : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          title: Text('المجموعة $g', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('خلايا ${(g - 1) * 24 + 1} — ${g * 24}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                          value: isActive,
                          activeThumbColor: AppTheme.primaryNavy,
                          onChanged: (val) {
                            if (val) {
                              if (!localGroups.contains(g)) localGroups.add(g);
                            } else {
                              if (localGroups.length > 1) {
                                localGroups.remove(g);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('يجب إبقاء مجموعة واحدة على الأقل')),
                                );
                                return;
                              }
                            }
                            localGroups.sort();
                            setSheetState(() {});
                            widget.onActiveGroupsChanged?.call(List.from(localGroups));
                          },
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    // Quick presets
                    const Text('إعدادات مسبقة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPresetButton(
                            label: 'مجموعة واحدة',
                            isActive: localGroups.length == 1 && localGroups.contains(1),
                            onTap: () {
                              localGroups
                                ..clear()
                                ..add(1);
                              setSheetState(() {});
                              widget.onActiveGroupsChanged?.call([1]);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPresetButton(
                            label: 'مجموعتان',
                            isActive: localGroups.length == 2,
                            onTap: () {
                              localGroups
                                ..clear()
                                ..addAll([1, 2]);
                              setSheetState(() {});
                              widget.onActiveGroupsChanged?.call([1, 2]);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPresetButton(
                            label: 'الكل (4)',
                            isActive: localGroups.length == 4,
                            onTap: () {
                              localGroups
                                ..clear()
                                ..addAll([1, 2, 3, 4]);
                              setSheetState(() {});
                              widget.onActiveGroupsChanged?.call([1, 2, 3, 4]);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // PDF page info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF0369A1)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              localGroups.length <= 2
                                  ? 'صفحة واحدة للبطاريات في التقرير PDF'
                                  : 'صفحتان متتاليتان للبطاريات في التقرير PDF',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cells = _getNormalizedCells();

    // Stats for active groups
    final activeCells = <BatteryMeasurement>[];
    for (final g in widget.activeGroups) {
      final start = (g - 1) * 24;
      if (start < cells.length) {
        activeCells.addAll(cells.skip(start).take(24));
      }
    }
    final calcCells = activeCells.isNotEmpty ? activeCells : cells;
    final measuredCells = calcCells.where((c) => c.voltage > 0).toList();

    final minV = measuredCells.isNotEmpty
        ? measuredCells.map((c) => c.voltage).reduce((a, b) => a < b ? a : b)
        : 0.0;
    final maxV = measuredCells.isNotEmpty
        ? measuredCells.map((c) => c.voltage).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final avgV = measuredCells.isNotEmpty
        ? measuredCells.map((c) => c.voltage).reduce((a, b) => a + b) / measuredCells.length
        : 0.0;

    final startIndex = (_selectedGroup - 1) * 24;
    final groupCells = cells.skip(startIndex).take(24).toList();
    final groupMeasuredCount = groupCells.where((c) => c.voltage > 0).length;
    final groupTotalV = groupCells.where((c) => c.voltage > 0).fold(0.0, (s, c) => s + c.voltage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1️⃣ Group Selector with Progress
        _buildGroupHeader(cells, groupMeasuredCount),
        const SizedBox(height: 10),

        // 2️⃣ Collapsible Stats
        _buildCollapsibleStats(minV, avgV, maxV, groupTotalV, measuredCells.length),
        const SizedBox(height: 6),

        // 3️⃣ Collapsible Quick Actions (Progressive Disclosure)
        _buildCollapsibleQuickActions(),
        const SizedBox(height: 12),

        // 4️⃣ Table Header
        _buildTableHeader(),
        const SizedBox(height: 6),

        // 5️⃣ Data Entry Cells
        _buildCellsList(groupCells, startIndex),
      ],
    );
  }

  // ─── 1️⃣ Group Header with Progress ────────────────────────────

  Widget _buildGroupHeader(List<BatteryMeasurement> allCells, int groupMeasuredCount) {
    final progress = groupMeasuredCount / 24;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.battery_charging_full_rounded, size: 18, color: AppTheme.primaryNavy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المجموعة $_selectedGroup',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${widget.activeGroups.length} مجموعات نشطة • ${widget.activeGroups.length * 24} خلية',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Settings gear
              if (widget.onActiveGroupsChanged != null)
                _buildIconAction(
                  icon: Icons.tune_rounded,
                  tooltip: 'إعدادات المجموعات',
                  onTap: _showGroupConfigSheet,
                ),
              const SizedBox(width: 4),
              // Clear button
              _buildIconAction(
                icon: Icons.cleaning_services_rounded,
                tooltip: 'مسح المجموعة',
                color: Colors.red.shade400,
                onTap: _clearGroupMeasurements,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Group selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: (widget.activeGroups.isNotEmpty ? widget.activeGroups : [1, 2, 3, 4]).map((g) {
                final isSel = _selectedGroup == g;
                final gStart = (g - 1) * 24;
                final gCells = allCells.skip(gStart).take(24);
                final gFilled = gCells.where((c) => c.voltage > 0).length;
                final isComplete = gFilled == 24;
                final isPartial = gFilled > 0 && gFilled < 24;

                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Material(
                    color: isSel
                        ? AppTheme.primaryNavy
                        : (isComplete ? const Color(0xFFF0FDF4) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedGroup = g);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel
                                ? AppTheme.primaryNavy
                                : (isComplete ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status icon
                            if (isComplete)
                              Icon(Icons.check_circle_rounded, size: 16,
                                  color: isSel ? Colors.white : const Color(0xFF16A34A))
                            else if (isPartial)
                              Icon(Icons.radio_button_checked, size: 16,
                                  color: isSel ? AppTheme.solarGold : const Color(0xFFD97706))
                            else
                              Icon(Icons.radio_button_unchecked, size: 16,
                                  color: isSel ? Colors.white60 : Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المجموعة $g',
                                  style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.bold,
                                    color: isSel ? Colors.white : AppTheme.textDark,
                                  ),
                                ),
                                Text(
                                  '$gFilled / 24',
                                  style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w600,
                                    color: isSel ? Colors.white70 : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? const Color(0xFF16A34A)
                    : (progress > 0 ? AppTheme.primaryNavy : const Color(0xFFCBD5E1)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$groupMeasuredCount من 24 خلية تم قياسها',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: progress >= 1.0 ? const Color(0xFF16A34A) : AppTheme.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: progress >= 1.0 ? const Color(0xFF16A34A) : AppTheme.primaryNavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2️⃣ Collapsible Stats ─────────────────────────────────────

  Widget _buildCollapsibleStats(double minV, double avgV, double maxV, double groupTotalV, int measuredCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isStatsExpanded = !_isStatsExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 18, color: AppTheme.primaryNavy),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      measuredCount > 0
                          ? 'ملخص الإحصائيات ($measuredCount خلية مقاسة)'
                          : 'ملخص الإحصائيات',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isStatsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 340;
                      final children = [
                        _buildStatTile('↓ أقل جهد', minV > 0 ? '${minV.toStringAsFixed(2)} V' : '—', AppTheme.statusFollowup),
                        _buildStatTile('μ متوسط', avgV > 0 ? '${avgV.toStringAsFixed(2)} V' : '—', AppTheme.primaryNavy),
                        _buildStatTile('↑ أعلى جهد', maxV > 0 ? '${maxV.toStringAsFixed(2)} V' : '—', AppTheme.statusGood),
                        _buildStatTile('Σ إجمالي المجموعة', groupTotalV > 0 ? '${groupTotalV.toStringAsFixed(1)} V' : '—', AppTheme.solarGold),
                      ];
                      if (isNarrow) {
                        return Column(
                          children: [
                            Row(children: [Expanded(child: children[0]), const SizedBox(width: 8), Expanded(child: children[1])]),
                            const SizedBox(height: 8),
                            Row(children: [Expanded(child: children[2]), const SizedBox(width: 8), Expanded(child: children[3])]),
                          ],
                        );
                      }
                      return Row(
                        children: children.expand((w) => [Expanded(child: w), const SizedBox(width: 8)]).toList()..removeLast(),
                      );
                    },
                  ),
                ),
              ],
            ),
            crossFadeState: _isStatsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  // ─── 3️⃣ Collapsible Quick Actions (Progressive Disclosure) ────

  Widget _buildCollapsibleQuickActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isQuickActionsExpanded = !_isQuickActionsExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, size: 18, color: AppTheme.solarGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تعبئة سريعة — المجموعة $_selectedGroup',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isQuickActionsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Tab selector
                      _buildQuickActionTabs(),
                      const SizedBox(height: 12),
                      // Tab content
                      _buildQuickActionContent(),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isQuickActionsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTabs() {
    final tabs = [
      (icon: Icons.bolt_rounded, label: 'الجهد (V)', color: AppTheme.brandCyan),
      (icon: Icons.build_circle_rounded, label: 'العزم (N.m)', color: AppTheme.primaryNavy),
      (icon: Icons.sticky_note_2_rounded, label: 'الملاحظات', color: AppTheme.solarGold),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final isSelected = _activeQuickTab == i;
          final tab = tabs[i];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeQuickTab = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon, size: 15, color: isSelected ? tab.color : AppTheme.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppTheme.textDark : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQuickActionContent() {
    switch (_activeQuickTab) {
      case 0: // Voltage
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickChip(label: '2.14V', onTap: () => _applyGroupVoltage(2.14), color: AppTheme.brandCyan),
            _buildQuickChip(label: '2.15V', onTap: () => _applyGroupVoltage(2.15), color: AppTheme.brandCyan),
            _buildQuickChip(label: '2.16V', onTap: () => _applyGroupVoltage(2.16), color: AppTheme.brandCyan),
            _buildQuickChip(label: '2.18V', onTap: () => _applyGroupVoltage(2.18), color: AppTheme.brandCyan),
            _buildQuickChip(label: '2.20V', onTap: () => _applyGroupVoltage(2.20), color: AppTheme.brandCyan),
            _buildQuickChip(
              label: 'واقعي ±0.01',
              icon: Icons.auto_awesome_rounded,
              onTap: () => _applyGroupVoltage(2.15, withVariance: true),
              color: Colors.teal.shade700,
              bgColor: Colors.teal.shade50,
            ),
            _buildQuickChip(
              label: 'مخصص',
              icon: Icons.edit_rounded,
              onTap: _showCustomVoltageDialog,
              outlined: true,
            ),
          ],
        );

      case 1: // Torque
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickChip(label: '10 N.m', onTap: () => _applyGroupTorque(10), color: AppTheme.primaryNavy),
            _buildQuickChip(label: '11 N.m', onTap: () => _applyGroupTorque(11), color: AppTheme.primaryNavy),
            _buildQuickChip(label: '12 N.m', onTap: () => _applyGroupTorque(12), color: AppTheme.primaryNavy),
            _buildQuickChip(label: '13 N.m', onTap: () => _applyGroupTorque(13), color: AppTheme.primaryNavy),
            _buildQuickChip(label: '15 N.m', onTap: () => _applyGroupTorque(15), color: AppTheme.primaryNavy),
            _buildQuickChip(
              label: 'مخصص',
              icon: Icons.edit_rounded,
              onTap: _showCustomTorqueDialog,
              outlined: true,
            ),
          ],
        );

      case 2: // Notes
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickChip(
              label: 'سليمة',
              icon: Icons.check_circle_outline,
              onTap: () => _applyGroupNote('سليمة'),
              color: const Color(0xFF16A34A),
              bgColor: const Color(0xFFF0FDF4),
            ),
            _buildQuickChip(
              label: 'فحص دوري',
              icon: Icons.schedule_rounded,
              onTap: () => _applyGroupNote('فحص دوري'),
              color: AppTheme.primaryNavy,
            ),
            _buildQuickChip(
              label: 'تحتاج متابعة',
              icon: Icons.warning_amber_rounded,
              onTap: () => _applyGroupNote('تحتاج متابعة'),
              color: const Color(0xFFD97706),
              bgColor: const Color(0xFFFFFBEB),
            ),
            _buildQuickChip(
              label: 'مسح الملاحظات',
              icon: Icons.clear_rounded,
              onTap: () => _applyGroupNote(''),
              isDestructive: true,
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ─── 4️⃣ Table Header ──────────────────────────────────────────

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryNavy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.12)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('م', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy), textAlign: TextAlign.center),
          ),
          SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text('الجهد (V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy)),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text('العزم (N.m)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy)),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text('الملاحظات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryNavy)),
          ),
        ],
      ),
    );
  }

  // ─── 5️⃣ Cells List ────────────────────────────────────────────

  Widget _buildCellsList(List<BatteryMeasurement> groupCells, int startIndex) {
    return ListView.separated(
      key: ValueKey('cells_list_group_$_selectedGroup'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupCells.length,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, idx) {
        final cell = groupCells[idx];
        final realIndex = startIndex + idx;
        final isArNote = ArabicReshaper.hasArabic(cell.notes);
        final isUnmeasured = cell.voltage <= 0;

        return Container(
          key: ValueKey('cell_${cell.cellNumber}_g_$_selectedGroup'),
          decoration: BoxDecoration(
            color: isUnmeasured
                ? const Color(0xFFFFF7ED)
                : (idx.isEven ? Colors.white : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUnmeasured ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
              width: isUnmeasured ? 1.3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Start-edge accent bar
                Container(
                  width: 4,
                  color: isUnmeasured ? const Color(0xFFF59E0B) : const Color(0xFF22C55E),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        // Cell number badge
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isUnmeasured
                                ? const Color(0xFFFDE68A)
                                : AppTheme.primaryNavy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13,
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
                        const SizedBox(width: 10),

                        // Voltage input
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            key: ValueKey('v_${cell.cellNumber}_g_${_selectedGroup}_r$_groupRevision'),
                            initialValue: cell.voltage > 0 ? '${cell.voltage}' : '',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.brandCyan, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.white,
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
                        const SizedBox(width: 8),

                        // Torque input
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            key: ValueKey('t_${cell.cellNumber}_g_${_selectedGroup}_r$_groupRevision'),
                            initialValue: cell.boltTorque > 0 ? '${cell.boltTorque}' : '',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: '0.0',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.white,
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
                        const SizedBox(width: 8),

                        // Notes input
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            key: ValueKey('n_${cell.cellNumber}_g_${_selectedGroup}_r$_groupRevision'),
                            initialValue: cell.notes,
                            textDirection: isArNote ? TextDirection.rtl : TextDirection.ltr,
                            textAlign: isArNote ? TextAlign.right : TextAlign.left,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'ملاحظة...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.solarGold, width: 1.5),
                              ),
                              filled: true,
                              fillColor: Colors.white,
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Utility Widgets ───────────────────────────────────────────

  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: (color ?? AppTheme.primaryNavy).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 38, height: 38,
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color ?? AppTheme.primaryNavy),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    Color? color,
    Color? bgColor,
    bool outlined = false,
    bool isDestructive = false,
  }) {
    final chipColor = isDestructive
        ? Colors.red.shade700
        : (color ?? AppTheme.primaryNavy);
    final chipBg = isDestructive
        ? Colors.red.shade50
        : (outlined ? Colors.white : (bgColor ?? chipColor.withValues(alpha: 0.06)));
    final chipBorder = isDestructive
        ? Colors.red.shade200
        : (outlined ? chipColor.withValues(alpha: 0.35) : chipColor.withValues(alpha: 0.15));

    return Material(
      color: chipBg,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: chipBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: chipColor),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: chipColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: isActive ? AppTheme.primaryNavy.withValues(alpha: 0.08) : Colors.white,
        foregroundColor: isActive ? AppTheme.primaryNavy : AppTheme.textSecondary,
        side: BorderSide(
          color: isActive ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
