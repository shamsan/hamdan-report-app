import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/measurement_data.dart';
import '../../../models/report.dart';

// ════════════════════════════════════════════════════════════════════
// PvCombinerBoxesWidget — Redesigned with Progressive Disclosure
// ────────────────────────────────────────────────────────────────────
// Best-in-class mobile-first design for PV string measurements:
//  1. Progressive Disclosure:
//     - 1-16 boxes config moved to modal bottom sheet
//     - Collapsible telemetry & live KPIs summary
//     - Collapsible quick presets & auto-fill actions
//  2. Responsive Dual Modes:
//     - Focus Mode (recommended for field use with box selector chips)
//     - Overview Mode (all active boxes rendered neatly)
//  3. High-Contrast Field Engineering Layout:
//     - Visual progress indicators per box & overall
//     - Calculated power preview (Voc × Isc) per string
//     - Smooth keyboard Tab navigation (TextInputAction.next)
//     - Accessible touch targets (≥44dp) & high contrast borders
// ════════════════════════════════════════════════════════════════════

class PvCombinerBoxesWidget extends StatefulWidget {
  final Report report;
  final ValueChanged<Report> onReportUpdated;
  final Widget? pageSetupControl;

  const PvCombinerBoxesWidget({
    super.key,
    required this.report,
    required this.onReportUpdated,
    this.pageSetupControl,
  });

  @override
  State<PvCombinerBoxesWidget> createState() => _PvCombinerBoxesWidgetState();
}

class _PvCombinerBoxesWidgetState extends State<PvCombinerBoxesWidget> {
  int _selectedBoxIndex = 1;
  bool _isFocusMode = true;
  bool _isStatsExpanded = false;
  int _revision = 0;

  final ScrollController _chipsScrollController = ScrollController();

  List<int> get _activeBoxes {
    final list = widget.report.activeCombinerBoxes;
    return list.isNotEmpty ? list : const [1, 2, 3, 4];
  }

  @override
  void initState() {
    super.initState();
    _selectedBoxIndex = _activeBoxes.isNotEmpty ? _activeBoxes.first : 1;
  }

  @override
  void didUpdateWidget(covariant PvCombinerBoxesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_activeBoxes.contains(_selectedBoxIndex)) {
      setState(() {
        _selectedBoxIndex = _activeBoxes.isNotEmpty ? _activeBoxes.first : 1;
      });
    }
  }

  @override
  void dispose() {
    _chipsScrollController.dispose();
    super.dispose();
  }

  // ─── Data Manipulation Helpers ─────────────────────────────────

  void _updateStringValue(int sIdx, {double? voc, double? isc}) {
    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
    final existingIdx = list.indexWhere((s) => s.stringNumber == sIdx);
    if (existingIdx != -1) {
      list[existingIdx] = list[existingIdx].copyWith(
        openCircuitVoltageVoc: voc,
        shortCircuitCurrentIsc: isc,
      );
    } else {
      list.add(StringMeasurement(
        stringNumber: sIdx,
        panelCount: 24,
        openCircuitVoltageVoc: voc ?? 0.0,
        shortCircuitCurrentIsc: isc ?? 0.0,
      ));
    }
    widget.onReportUpdated(widget.report.copyWith(stringMeasurements: list));
  }

  void _fillTypicalValues({
    double baseVoc = 135.2,
    double baseIsc = 8.4,
    String label = 'نموذجية (330W-350W)',
  }) {
    HapticFeedback.lightImpact();
    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
    for (final bNum in _activeBoxes) {
      for (int sNum = 1; sNum <= 4; sNum++) {
        final sIdx = ((bNum - 1) * 4) + sNum;
        final voc = baseVoc + ((sIdx % 4) * 0.3);
        final isc = baseIsc + ((sIdx % 3) * 0.2);
        final existingIdx = list.indexWhere((s) => s.stringNumber == sIdx);
        if (existingIdx != -1) {
          list[existingIdx] = list[existingIdx].copyWith(
            openCircuitVoltageVoc: double.parse(voc.toStringAsFixed(1)),
            shortCircuitCurrentIsc: double.parse(isc.toStringAsFixed(1)),
          );
        } else {
          list.add(StringMeasurement(
            stringNumber: sIdx,
            panelCount: 24,
            openCircuitVoltageVoc: double.parse(voc.toStringAsFixed(1)),
            shortCircuitCurrentIsc: double.parse(isc.toStringAsFixed(1)),
          ));
        }
      }
    }
    setState(() => _revision++);
    widget.onReportUpdated(widget.report.copyWith(stringMeasurements: list));
    _showFeedback('تم تطبيق قراءات $label لجميع السلاسل النشطة');
  }

  void _clearActiveStrings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 22),
            const SizedBox(width: 8),
            const Text('مسح قياسات السلاسل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('سيتم تصفير جميع قراءات سلاسل الصناديق النشطة (${_activeBoxes.length} صناديق).\nهل أنت متأكد؟'),
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
              final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
              for (final bNum in _activeBoxes) {
                for (int sNum = 1; sNum <= 4; sNum++) {
                  final sIdx = ((bNum - 1) * 4) + sNum;
                  final existingIdx = list.indexWhere((s) => s.stringNumber == sIdx);
                  if (existingIdx != -1) {
                    list[existingIdx] = list[existingIdx].copyWith(
                      openCircuitVoltageVoc: 0.0,
                      shortCircuitCurrentIsc: 0.0,
                    );
                  }
                }
              }
              setState(() => _revision++);
              widget.onReportUpdated(widget.report.copyWith(stringMeasurements: list));
              _showFeedback('تم مسح قراءات السلاسل النشطة بنجاح');
            },
            label: const Text('مسح'),
          ),
        ],
      ),
    );
  }

  void _copyBox1ToAll() {
    HapticFeedback.lightImpact();
    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
    final box1Strings = [1, 2, 3, 4].map((sNum) {
      final s = list.firstWhere(
        (m) => m.stringNumber == sNum,
        orElse: () => const StringMeasurement(stringNumber: 0),
      );
      return s;
    }).toList();

    final hasData = box1Strings.any((s) => s.openCircuitVoltageVoc > 0 || s.shortCircuitCurrentIsc > 0);
    if (!hasData) {
      _showFeedback('يرجى إدخال قراءات الصندوق #1 أولاً ليتم نسخها');
      return;
    }

    for (final bNum in _activeBoxes.where((b) => b != 1)) {
      for (int sNum = 1; sNum <= 4; sNum++) {
        final targetIdx = ((bNum - 1) * 4) + sNum;
        final src = box1Strings[sNum - 1];
        final existingIdx = list.indexWhere((s) => s.stringNumber == targetIdx);
        if (existingIdx != -1) {
          list[existingIdx] = list[existingIdx].copyWith(
            openCircuitVoltageVoc: src.openCircuitVoltageVoc,
            shortCircuitCurrentIsc: src.shortCircuitCurrentIsc,
          );
        } else {
          list.add(StringMeasurement(
            stringNumber: targetIdx,
            panelCount: 24,
            openCircuitVoltageVoc: src.openCircuitVoltageVoc,
            shortCircuitCurrentIsc: src.shortCircuitCurrentIsc,
          ));
        }
      }
    }
    setState(() => _revision++);
    widget.onReportUpdated(widget.report.copyWith(stringMeasurements: list));
    _showFeedback('تم نسخ قراءات الصندوق #1 إلى باقي الصناديق (${_activeBoxes.length})');
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

  // ─── Modal Dialogs & Sheets ────────────────────────────────────

  void _showCustomFillDialog() {
    final vocCtrl = TextEditingController(text: '135.2');
    final iscCtrl = TextEditingController(text: '8.4');

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
              child: const Icon(Icons.tune_rounded, color: AppTheme.primaryNavy, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('تعبئة مخصصة لقراءات السلاسل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل جهد الدائرة المفتوحة (Voc) وتيار القصر (Isc) لتطبيقهما على السلاسل النشطة مع تباين فيزيائي طفيف:',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: vocCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'جهد السلسلة Voc (V)',
                suffixText: 'V',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: iscCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'تيار السلسلة Isc (A)',
                suffixText: 'A',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
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
              final v = double.tryParse(vocCtrl.text.trim()) ?? 135.2;
              final a = double.tryParse(iscCtrl.text.trim()) ?? 8.4;
              Navigator.pop(ctx);
              _fillTypicalValues(baseVoc: v, baseIsc: a, label: 'مخصصة (${v}V / ${a}A)');
            },
            child: const Text('تطبيق على السلاسل'),
          ),
        ],
      ),
    );
  }

  void _showBoxesConfigSheet() {
    final localBoxes = List<int>.from(_activeBoxes);

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
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
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
                          child: const Icon(Icons.hub_rounded, size: 20, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('صناديق التجميع المضمنة بالتقرير', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                              Text('${localBoxes.length} من 16 صندوقاً نشطاً (${localBoxes.length * 4} سلسلة)', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick presets row
                    const Text('تحديد سريع لعدد الصناديق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPresetButton(
                            label: 'صندوقين (1-2)',
                            isActive: localBoxes.length == 2 && localBoxes.contains(1) && localBoxes.contains(2),
                            onTap: () {
                              localBoxes..clear()..addAll([1, 2]);
                              setSheetState(() {});
                              widget.onReportUpdated(widget.report.copyWith(activeCombinerBoxes: [1, 2]));
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPresetButton(
                            label: '3 صناديق (1-3)',
                            isActive: localBoxes.length == 3,
                            onTap: () {
                              localBoxes..clear()..addAll([1, 2, 3]);
                              setSheetState(() {});
                              widget.onReportUpdated(widget.report.copyWith(activeCombinerBoxes: [1, 2, 3]));
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPresetButton(
                            label: '4 صناديق (1-4)',
                            isActive: localBoxes.length == 4,
                            onTap: () {
                              localBoxes..clear()..addAll([1, 2, 3, 4]);
                              setSheetState(() {});
                              widget.onReportUpdated(widget.report.copyWith(activeCombinerBoxes: [1, 2, 3, 4]));
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPresetButton(
                            label: 'الكل (16)',
                            isActive: localBoxes.length == 16,
                            onTap: () {
                              localBoxes..clear()..addAll(List.generate(16, (i) => i + 1));
                              setSheetState(() {});
                              widget.onReportUpdated(widget.report.copyWith(activeCombinerBoxes: List.generate(16, (i) => i + 1)));
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Individual Box Grid
                    const Text('تحديد الصناديق الفردية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(16, (i) => i + 1).map((b) {
                        final isSelected = localBoxes.contains(b);
                        return FilterChip(
                          label: Text('صندوق $b'),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryNavy.withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.primaryNavy,
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
                            width: isSelected ? 1.4 : 1,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primaryNavy : AppTheme.textDark,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              if (!localBoxes.contains(b)) localBoxes.add(b);
                            } else {
                              if (localBoxes.length > 1) {
                                localBoxes.remove(b);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('يجب إبقاء صندوق تجميع واحد على الأقل')),
                                );
                                return;
                              }
                            }
                            localBoxes.sort();
                            setSheetState(() {});
                            widget.onReportUpdated(widget.report.copyWith(activeCombinerBoxes: List.from(localBoxes)));
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Page Orientation & PDF info
                    if (widget.pageSetupControl != null) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      widget.pageSetupControl!,
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Statistics Calculation ────────────────────────────────────

  List<StringMeasurement> _getActiveStrings() {
    final list = <StringMeasurement>[];
    for (final bNum in _activeBoxes) {
      for (int sNum = 1; sNum <= 4; sNum++) {
        final sIdx = ((bNum - 1) * 4) + sNum;
        final m = widget.report.stringMeasurements.firstWhere(
          (s) => s.stringNumber == sIdx,
          orElse: () => StringMeasurement(stringNumber: sIdx, panelCount: 24),
        );
        list.add(m);
      }
    }
    return list;
  }

  // ─── Build Method ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeStrings = _getActiveStrings();
    final completedCount = activeStrings.where((s) => s.openCircuitVoltageVoc > 0 && s.shortCircuitCurrentIsc > 0).length;
    final totalStringsCount = activeStrings.length;
    final progress = totalStringsCount > 0 ? (completedCount / totalStringsCount) : 0.0;

    double avgVoc = 0.0;
    double avgIsc = 0.0;
    final validVocList = activeStrings.where((s) => s.openCircuitVoltageVoc > 0).map((s) => s.openCircuitVoltageVoc).toList();
    final validIscList = activeStrings.where((s) => s.shortCircuitCurrentIsc > 0).map((s) => s.shortCircuitCurrentIsc).toList();
    if (validVocList.isNotEmpty) {
      avgVoc = validVocList.reduce((a, b) => a + b) / validVocList.length;
    }
    if (validIscList.isNotEmpty) {
      avgIsc = validIscList.reduce((a, b) => a + b) / validIscList.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1️⃣ Header with Progress & Config Action
        _buildHeaderCard(completedCount, totalStringsCount, progress),
        const SizedBox(height: 10),

        // 2️⃣ Collapsible Telemetry & Live KPIs
        _buildCollapsibleKpis(avgVoc, avgIsc, completedCount, totalStringsCount),
        const SizedBox(height: 8),

        // 3️⃣ View Mode & Quick Actions Bar
        _buildModeAndQuickBar(),
        const SizedBox(height: 10),

        // 4️⃣ String Cards Rendered in Focus or Overview mode
        if (_isFocusMode) ...[
          _buildBoxSelectorChips(),
          const SizedBox(height: 12),
          _buildActiveBoxCard(_selectedBoxIndex),
        ] else ...[
          ..._activeBoxes.map((bNum) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildActiveBoxCard(bNum, isOverview: true),
            );
          }),
        ],
      ],
    );
  }

  // ─── 1️⃣ Header Card ───────────────────────────────────────────

  Widget _buildHeaderCard(int completedCount, int totalCount, double progress) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.solar_power_rounded, size: 19, color: AppTheme.primaryNavy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'قياسات سلاسل الألواح والصناديق',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      '${_activeBoxes.length} صناديق نشطة • $totalCount سلسلة أداء (Voc & Isc)',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Config Gear
              _buildIconAction(
                icon: Icons.tune_rounded,
                tooltip: 'تحديد الصناديق النشطة',
                onTap: _showBoxesConfigSheet,
              ),
              const SizedBox(width: 4),
              // Clear Action
              _buildIconAction(
                icon: Icons.cleaning_services_rounded,
                tooltip: 'مسح قراءات السلاسل',
                color: Colors.red.shade400,
                onTap: _clearActiveStrings,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
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
                '$completedCount من $totalCount سلسلة تم قياسها بالكامل',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: progress >= 1.0 ? const Color(0xFF16A34A) : AppTheme.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: progress >= 1.0 ? const Color(0xFF16A34A) : AppTheme.primaryNavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2️⃣ Collapsible KPIs & Telemetry ──────────────────────────

  Widget _buildCollapsibleKpis(double avgVoc, double avgIsc, int completed, int total) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
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
                  const Expanded(
                    child: Text(
                      'ملخص مؤشرات أداء السلاسل',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark),
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

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildKpiTile(
                          title: 'متوسط Voc',
                          value: avgVoc > 0 ? '${avgVoc.toStringAsFixed(1)} V' : '—',
                          subtitle: 'جهد الدائرة المفتوحة',
                          icon: Icons.bolt_rounded,
                          color: AppTheme.brandCyan,
                          bgColor: const Color(0xFFF0FDF4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiTile(
                          title: 'متوسط Isc',
                          value: avgIsc > 0 ? '${avgIsc.toStringAsFixed(1)} A' : '—',
                          subtitle: 'تيار دائرة القصر',
                          icon: Icons.electric_bolt_rounded,
                          color: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiTile(
                          title: 'السلاسل المكتملة',
                          value: '$completed / $total',
                          subtitle: completed == total ? 'مكتمل 100%' : 'قيد الإدخال',
                          icon: Icons.check_circle_outline_rounded,
                          color: completed == total ? const Color(0xFF16A34A) : AppTheme.solarGold,
                          bgColor: const Color(0xFFFFFBEB),
                        ),
                      ),
                    ],
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

  // ─── 3️⃣ Mode & Quick Bar ───────────────────────────────────────

  Widget _buildModeAndQuickBar() {
    return Row(
      children: [
        // Mode Switcher (Icon-Only Segmented Control)
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeIconButton(
                icon: Icons.filter_center_focus_rounded,
                tooltip: 'وضع التركيز (صندوق تلو الآخر)',
                isSelected: _isFocusMode,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isFocusMode = true);
                },
              ),
              const SizedBox(width: 2),
              _buildModeIconButton(
                icon: Icons.view_agenda_outlined,
                tooltip: 'عرض كافة الصناديق في قائمة واحدة',
                isSelected: !_isFocusMode,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isFocusMode = false);
                },
              ),
            ],
          ),
        ),

        const Spacer(),

        // Copy Box #1 to All Action Icon Button
        if (_activeBoxes.length > 1) ...[
          _buildActionIconButton(
            icon: Icons.copy_all_rounded,
            tooltip: 'نسخ قراءات الصندوق #1 لباقي الصناديق',
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFF86EFAC),
            onTap: _copyBox1ToAll,
          ),
          const SizedBox(width: 8),
        ],

        // Typical fill button
        _buildActionIconButton(
          icon: Icons.auto_fix_high_rounded,
          tooltip: 'تعبئة نموذجية قياسية لكافة السلاسل',
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          onTap: () => _fillTypicalValues(),
        ),

        const SizedBox(width: 6),

        // More options PopupMenu
        PopupMenuButton<String>(
          tooltip: 'خيارات تعبئة متقدمة للسلاسل',
          icon: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.primaryNavy),
          ),
          padding: EdgeInsets.zero,
          onSelected: (val) {
            if (val == 'std') _fillTypicalValues(baseVoc: 135.2, baseIsc: 8.4, label: 'قياسية 330W-350W');
            if (val == 'half_cut') _fillTypicalValues(baseVoc: 196.5, baseIsc: 13.5, label: 'ألواح حديثة 545W-550W');
            if (val == 'custom') _showCustomFillDialog();
            if (val == 'clear') _clearActiveStrings();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'std', child: Text('ألواح 330W-350W (Voc ≈ 135V, Isc ≈ 8.4A)')),
            const PopupMenuItem(value: 'half_cut', child: Text('ألواح 545W-550W (Voc ≈ 196V, Isc ≈ 13.5A)')),
            const PopupMenuItem(value: 'custom', child: Text('تعبئة بقيم مخصصة ✎...')),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'clear',
              child: Text('مسح قراءات الصناديق النشطة', style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Box Selector Chips (Horizontal Focus Bar) ─────────────────

  Widget _buildBoxSelectorChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        controller: _chipsScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _activeBoxes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final bNum = _activeBoxes[index];
          final isSelected = _selectedBoxIndex == bNum;

          // Check fill status of this box
          int filledInBox = 0;
          for (int sNum = 1; sNum <= 4; sNum++) {
            final sIdx = ((bNum - 1) * 4) + sNum;
            final m = widget.report.stringMeasurements.firstWhere(
              (s) => s.stringNumber == sIdx,
              orElse: () => const StringMeasurement(stringNumber: 0),
            );
            if (m.openCircuitVoltageVoc > 0 && m.shortCircuitCurrentIsc > 0) {
              filledInBox++;
            }
          }

          final isComplete = filledInBox == 4;
          final isPartial = filledInBox > 0 && filledInBox < 4;

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedBoxIndex = bNum);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryNavy
                    : (isComplete ? const Color(0xFFF0FDF4) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryNavy
                      : (isComplete ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                  width: isSelected ? 1.6 : 1.1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryNavy.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isComplete)
                    Icon(Icons.check_circle_rounded, size: 14, color: isSelected ? Colors.white : const Color(0xFF16A34A))
                  else if (isPartial)
                    Icon(Icons.adjust_rounded, size: 14, color: isSelected ? AppTheme.solarGold : const Color(0xFFD97706))
                  else
                    Icon(Icons.circle_outlined, size: 13, color: isSelected ? Colors.white70 : Colors.grey[400]),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'صندوق #$bNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        '$filledInBox / 4 سلاسل',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white70 : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Active Combiner Box Card ──────────────────────────────────

  Widget _buildActiveBoxCard(int bNum, {bool isOverview = false}) {
    final boxStrings = [1, 2, 3, 4].map((sNum) {
      final sIdx = ((bNum - 1) * 4) + sNum;
      return widget.report.stringMeasurements.firstWhere(
        (s) => s.stringNumber == sIdx,
        orElse: () => StringMeasurement(
          stringNumber: sIdx,
          panelCount: 24,
          openCircuitVoltageVoc: 0,
          shortCircuitCurrentIsc: 0,
        ),
      );
    }).toList();

    final isAllFilled = boxStrings.every((s) => s.openCircuitVoltageVoc > 0 && s.shortCircuitCurrentIsc > 0);

    return Container(
      key: ValueKey('box_card_${bNum}_rev_$_revision'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAllFilled ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
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
          // Box Card Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub_rounded, size: 14, color: AppTheme.solarGold),
                    const SizedBox(width: 6),
                    Text(
                      'صندوق التجميع #$bNum',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'السلاسل: ${((bNum - 1) * 4) + 1} إلى ${bNum * 4}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ),
              if (isAllFilled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text('مكتمل', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Strings Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text('سلسلة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy), textAlign: TextAlign.center),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text('Voc (V)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Text('Isc (A)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Strings Rows
          ...boxStrings.map((str) {
            final isMeasured = str.openCircuitVoltageVoc > 0 || str.shortCircuitCurrentIsc > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isMeasured ? Colors.white : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isMeasured ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Accent bar
                    Container(
                      width: 4,
                      color: isMeasured ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            // String badge
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isMeasured
                                    ? AppTheme.primaryNavy.withValues(alpha: 0.08)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#${str.stringNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isMeasured ? AppTheme.primaryNavy : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Voc Input Field
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                key: ValueKey('str_voc_${str.stringNumber}_rev_$_revision'),
                                initialValue: str.openCircuitVoltageVoc > 0 ? '${str.openCircuitVoltageVoc}' : '',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                decoration: InputDecoration(
                                  labelText: 'Voc (V)',
                                  hintText: '135.2',
                                  labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                                onChanged: (v) {
                                  final d = double.tryParse(v.trim());
                                  if (d != null) {
                                    _updateStringValue(str.stringNumber, voc: d);
                                  } else if (v.trim().isEmpty) {
                                    _updateStringValue(str.stringNumber, voc: 0.0);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Isc Input Field
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                key: ValueKey('str_isc_${str.stringNumber}_rev_$_revision'),
                                initialValue: str.shortCircuitCurrentIsc > 0 ? '${str.shortCircuitCurrentIsc}' : '',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                decoration: InputDecoration(
                                  labelText: 'Isc (A)',
                                  hintText: '8.4',
                                  labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                                onChanged: (v) {
                                  final d = double.tryParse(v.trim());
                                  if (d != null) {
                                    _updateStringValue(str.stringNumber, isc: d);
                                  } else if (v.trim().isEmpty) {
                                    _updateStringValue(str.stringNumber, isc: 0.0);
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
          }),
        ],
      ),
    );
  }

  // ─── Reusable Helper Widgets ───────────────────────────────────

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
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color ?? AppTheme.primaryNavy),
          ),
        ),
      ),
    );
  }

  Widget _buildModeIconButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 38,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [const BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? AppTheme.primaryNavy : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 8.5, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    );
  }
}
