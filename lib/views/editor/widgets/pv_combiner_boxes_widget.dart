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
    final bNum = ((sIdx - 1) ~/ 4) + 1;
    final boxPanels = widget.report.getBoxPanelCount(bNum);
    final perString = boxPanels > 0 ? (boxPanels ~/ 4) : 0;

    final existingIdx = list.indexWhere((s) => s.stringNumber == sIdx);
    if (existingIdx != -1) {
      list[existingIdx] = list[existingIdx].copyWith(
        openCircuitVoltageVoc: voc,
        shortCircuitCurrentIsc: isc,
        panelCount: perString > 0 ? perString : null,
      );
    } else {
      list.add(StringMeasurement(
        stringNumber: sIdx,
        panelCount: perString,
        openCircuitVoltageVoc: voc ?? 0.0,
        shortCircuitCurrentIsc: isc ?? 0.0,
      ));
    }
    widget.onReportUpdated(widget.report.copyWith(stringMeasurements: list));
  }

  void _updateBoxPanelCount(int bNum, int count) {
    final currentMap = Map<int, int>.from(widget.report.arrayPanelCounts);
    if (count > 0) {
      currentMap[bNum] = count;
    } else {
      currentMap.remove(bNum);
    }

    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
    final perString = count > 0 ? (count ~/ 4) : 0;
    for (int sNum = 1; sNum <= 4; sNum++) {
      final sIdx = ((bNum - 1) * 4) + sNum;
      final existingIdx = list.indexWhere((s) => s.stringNumber == sIdx);
      if (existingIdx != -1) {
        list[existingIdx] = list[existingIdx].copyWith(panelCount: perString);
      } else {
        list.add(StringMeasurement(stringNumber: sIdx, panelCount: perString));
      }
    }

    widget.onReportUpdated(widget.report.copyWith(
      arrayPanelCounts: currentMap,
      stringMeasurements: list,
    ));
    setState(() => _revision++);
    _showFeedback('تم ضبط ألواح مصفوفة صندوق #$bNum إلى $count لوح');
  }

  void _autoDistributePanelsEvenly() {
    final totalPanels = widget.report.parseTotalPanels();
    if (totalPanels <= 0) {
      _showFeedback('يرجى التأكد من إدخال إجمالي عدد الألواح أولاً في مواصفات المنظومة');
      return;
    }
    final active = _activeBoxes;
    if (active.isEmpty) return;

    final perBox = totalPanels ~/ active.length;
    final remainder = totalPanels % active.length;

    final currentMap = Map<int, int>.from(widget.report.arrayPanelCounts);
    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);

    for (int i = 0; i < active.length; i++) {
      final bNum = active[i];
      final count = perBox + (i < remainder ? 1 : 0);
      currentMap[bNum] = count;

      final perString = count ~/ 4;
      for (int sNum = 1; sNum <= 4; sNum++) {
        final sIdx = ((bNum - 1) * 4) + sNum;
        final existingIdx = list.indexWhere((s) => s.stringNumber == sIdx);
        if (existingIdx != -1) {
          list[existingIdx] = list[existingIdx].copyWith(panelCount: perString);
        } else {
          list.add(StringMeasurement(stringNumber: sIdx, panelCount: perString));
        }
      }
    }

    widget.onReportUpdated(widget.report.copyWith(
      arrayPanelCounts: currentMap,
      stringMeasurements: list,
    ));
    setState(() => _revision++);
    _showFeedback('تم توزيع $totalPanels لوحاً بالتساوي ($perBox لوح لكل مصفوفة)');
  }


  void _showEditBoxPanelsDialog(int bNum) {
    final currentCount = widget.report.getBoxPanelCount(bNum);
    final ctrl = TextEditingController(text: currentCount > 0 ? '$currentCount' : '');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDlgState) {
          final countVal = int.tryParse(ctrl.text.trim()) ?? 0;
          final perString = countVal > 0 ? (countVal ~/ 4) : 0;
          final isDivisibleBy4 = countVal > 0 && (countVal % 4 == 0);
          final minVoc = perString > 0 ? (perString * 44).toStringAsFixed(0) : '0';
          final maxVoc = perString > 0 ? (perString * 50).toStringAsFixed(0) : '0';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Icon(Icons.solar_power_rounded, color: Color(0xFF16A34A), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ألواح مصفوفة صندوق #$bNum', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      const Text('توزيع السلاسل والتوصيل الكهربائي', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أدخل إجمالي عدد الألواح المتصلة بهذه المصفوفة (صندوق التجميع):',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    decoration: InputDecoration(
                      labelText: 'إجمالي ألواح المصفوفة',
                      suffixText: 'لوح',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.pin_rounded, color: AppTheme.primaryNavy),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Real-time Electrical Analysis Card
                  if (countVal > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDivisibleBy4 ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDivisibleBy4 ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDivisibleBy4 ? Icons.bolt_rounded : Icons.warning_amber_rounded,
                                size: 16,
                                color: isDivisibleBy4 ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isDivisibleBy4 ? 'التحليل الهندسي للتوصيل:' : 'تنبيه عدم التماثل الكهربائي:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDivisibleBy4 ? const Color(0xFF166534) : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isDivisibleBy4
                                ? '• الصندوق يضم 4 سلاسل توازي.\n• كل سلسلة تحتوي على $perString ألواح موصلة على التوالي (Series).\n• جهد الدائرة المفتوحة المتوقع لكل سلسلة: ~$minVoc - $maxVoc فولت.'
                                : '⚠️ $countVal لوح لا تقبل القسمة بالتساوي على 4 سلاسل توازي!\nالتوصيل غير المتطابق في عدد الألواح يؤدي لاختلاف الجهود وتوليد تيار عكسي ضار.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.45,
                              color: isDivisibleBy4 ? const Color(0xFF166534) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Standard Quick Choice Chips
                  const Text(
                    'الخيارات المعيارية الشائعة (مضاعفات 4):',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [16, 20, 24, 28, 32].map((cnt) {
                      final s = cnt ~/ 4;
                      final isSelected = countVal == cnt;
                      return ChoiceChip(
                        label: Text('$cnt لوح (4×$s)'),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryNavy,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (_) {
                          ctrl.text = '$cnt';
                          setDlgState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 17),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final val = int.tryParse(ctrl.text.trim()) ?? 0;
                  Navigator.pop(ctx);
                  _updateBoxPanelCount(bNum, val);
                },
                label: const Text('حفظ وتطبيق'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _fillTypicalValues({
    double baseVoc = 135.2,
    double baseIsc = 8.4,
    String label = 'نموذجية (330W-350W)',
  }) {
    HapticFeedback.lightImpact();
    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
    for (final bNum in _activeBoxes) {
      final boxPanels = widget.report.getBoxPanelCount(bNum);
      final perString = boxPanels > 0 ? (boxPanels ~/ 4) : 0;

      // Calculate realistic Voc dynamically based on series panels if configured
      double effectiveVoc = baseVoc;
      if (perString > 0) {
        final double perPanelVoc = (baseVoc > 180 || label.contains('545') || label.contains('550')) ? 49.5 : 45.0;
        effectiveVoc = perString * perPanelVoc;
      }

      for (int sNum = 1; sNum <= 4; sNum++) {
        final sIdx = ((bNum - 1) * 4) + sNum;
        final voc = effectiveVoc + ((sIdx % 4) * 0.3);
        final isc = baseIsc + ((sIdx % 3) * 0.2);
        final existingIdx = list.indexWhere((s) => s.stringNumber == sIdx);
        if (existingIdx != -1) {
          list[existingIdx] = list[existingIdx].copyWith(
            panelCount: perString > 0 ? perString : list[existingIdx].panelCount,
            openCircuitVoltageVoc: double.parse(voc.toStringAsFixed(1)),
            shortCircuitCurrentIsc: double.parse(isc.toStringAsFixed(1)),
          );
        } else {
          list.add(StringMeasurement(
            stringNumber: sIdx,
            panelCount: perString,
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
          final boxPanels = widget.report.getBoxPanelCount(bNum);
          list.add(StringMeasurement(
            stringNumber: targetIdx,
            panelCount: boxPanels > 0 ? (boxPanels ~/ 4) : 0,
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
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('توزيع ألواح المنظومة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                              Text('توزيع إجمالي ألواح المنظومة بالتساوي على الصناديق', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            _autoDistributePanelsEvenly();
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                          label: const Text('توزيع متساوي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryNavy,
                            backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

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
        final boxPanels = widget.report.getBoxPanelCount(bNum);
        final m = widget.report.stringMeasurements.firstWhere(
          (s) => s.stringNumber == sIdx,
          orElse: () => StringMeasurement(stringNumber: sIdx, panelCount: boxPanels > 0 ? (boxPanels ~/ 4) : 0),
        );
        list.add(m);
      }
    }
    return list;
  }

  // ─── Panels Management Bottom Sheet ───────────────────────────

  void _showPanelsManagementSheet() {
    final totalPanels = widget.report.parseTotalPanels();
    final totalCtrl = TextEditingController(text: totalPanels > 0 ? '$totalPanels' : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final curTotal = int.tryParse(totalCtrl.text.trim()) ?? 0;
            int allocated = 0;
            for (final b in _activeBoxes) {
              allocated += widget.report.getBoxPanelCount(b);
            }
            final isMatched = curTotal > 0 && allocated == curTotal;
            final isOver = curTotal > 0 && allocated > curTotal;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.solar_power_rounded, color: AppTheme.primaryNavy, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إدارة وتوزيع ألواح المنظومة',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              Text(
                                'تحديد إجمالي الألواح وتوزيعها على صناديق التجميع',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Total Panels Input
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pin_rounded, size: 16, color: AppTheme.primaryNavy),
                              const SizedBox(width: 6),
                              const Text(
                                'إجمالي عدد ألواح المنظومة ككل:',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              const Spacer(),
                              if (curTotal > 0)
                                TextButton.icon(
                                  onPressed: () {
                                    _autoDistributePanelsEvenly();
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
                                  label: const Text('توزيع متساوي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.08),
                                    foregroundColor: AppTheme.primaryNavy,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: totalCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  decoration: InputDecoration(
                                    hintText: '96',
                                    suffixText: 'لوح',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (val) {
                                    final numVal = int.tryParse(val.trim()) ?? 0;
                                    if (numVal > 0) {
                                      final currentSpecs = widget.report.systemSpecs;
                                      String newSpec = '$numVal لوح';
                                      if (currentSpecs.panelsCountAndWatt.contains('W')) {
                                        final wattMatch = RegExp(r'(\d+\s*W[^\s]*)').firstMatch(currentSpecs.panelsCountAndWatt);
                                        if (wattMatch != null) {
                                          newSpec = '$numVal لوح × ${wattMatch.group(1)!}';
                                        }
                                      }
                                      widget.onReportUpdated(widget.report.copyWith(
                                        systemSpecs: currentSpecs.copyWith(panelsCountAndWatt: newSpec),
                                      ));
                                    }
                                    setSheetState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Quick Sizes
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [48, 64, 72, 80, 96, 112, 120, 144].map((cnt) {
                                final isSel = curTotal == cnt;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: ChoiceChip(
                                    label: Text('$cnt لوح'),
                                    selected: isSel,
                                    selectedColor: AppTheme.primaryNavy,
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : AppTheme.textDark,
                                    ),
                                    backgroundColor: Colors.white,
                                    onSelected: (_) {
                                      totalCtrl.text = '$cnt';
                                      final currentSpecs = widget.report.systemSpecs;
                                      String newSpec = '$cnt لوح';
                                      if (currentSpecs.panelsCountAndWatt.contains('W')) {
                                        final wattMatch = RegExp(r'(\d+\s*W[^\s]*)').firstMatch(currentSpecs.panelsCountAndWatt);
                                        if (wattMatch != null) {
                                          newSpec = '$cnt لوح × ${wattMatch.group(1)!}';
                                        }
                                      }
                                      widget.onReportUpdated(widget.report.copyWith(
                                        systemSpecs: currentSpecs.copyWith(panelsCountAndWatt: newSpec),
                                      ));
                                      setSheetState(() {});
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Box Steppers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'توزيع ألواح الصناديق النشطة (4 سلاسل توازي):',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMatched
                                ? const Color(0xFFDCFCE7)
                                : (isOver ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            curTotal > 0
                                ? '$allocated / $curTotal لوح'
                                : '$allocated لوح موزع',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMatched
                                  ? const Color(0xFF15803D)
                                  : (isOver ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ..._activeBoxes.map((bNum) {
                      final boxPanels = widget.report.getBoxPanelCount(bNum);
                      final perString = boxPanels > 0 ? (boxPanels ~/ 4) : 0;
                      final minVoc = perString > 0 ? (perString * 44).toStringAsFixed(0) : '0';
                      final maxVoc = perString > 0 ? (perString * 50).toStringAsFixed(0) : '0';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.hub_rounded, size: 16, color: AppTheme.primaryNavy),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'صندوق التجميع #$bNum',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                  ),
                                  Text(
                                    boxPanels > 0
                                        ? '4 سلاسل × $perString ألواح توالي (~$minVoc-$maxVoc V)'
                                        : 'لم تحدد ألواح المصفوفة بعد',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: boxPanels > 0 ? const Color(0xFF166534) : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Stepper (-4 / +4)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                  color: boxPanels > 4 ? AppTheme.primaryNavy : Colors.grey.shade400,
                                  onPressed: boxPanels >= 4
                                      ? () {
                                          _updateBoxPanelCount(bNum, (boxPanels - 4).clamp(0, 1000));
                                          setSheetState(() {});
                                        }
                                      : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                InkWell(
                                  onTap: () {
                                    _showEditBoxPanelsDialog(bNum);
                                    Navigator.pop(ctx);
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$boxPanels',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                  color: AppTheme.primaryNavy,
                                  onPressed: () {
                                    _updateBoxPanelCount(bNum, boxPanels + 4);
                                    setSheetState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق وتطبيق', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        // 1️⃣ Unified Executive Header
        _buildUnifiedExecutiveHeader(
          completedCount: completedCount,
          totalCount: totalStringsCount,
          progress: progress,
          avgVoc: avgVoc,
          avgIsc: avgIsc,
        ),
        const SizedBox(height: 10),

        // 2️⃣ Combiner Box Segmented Tabs (Focus Mode)
        if (_isFocusMode) ...[
          _buildBoxTabsBar(),
          const SizedBox(height: 10),
          _buildActiveBoxWorkspace(_selectedBoxIndex),
        ] else ...[
          // Overview Mode: All Active Boxes
          ..._activeBoxes.map((bNum) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildActiveBoxWorkspace(bNum, isOverview: true),
            );
          }),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── 1️⃣ Unified Executive Header ────────────────────────────────

  Widget _buildUnifiedExecutiveHeader({
    required int completedCount,
    required int totalCount,
    required double progress,
    required double avgVoc,
    required double avgIsc,
  }) {
    final totalPanels = widget.report.parseTotalPanels();
    int allocatedPanels = 0;
    for (final b in _activeBoxes) {
      allocatedPanels += widget.report.getBoxPanelCount(b);
    }
    final isMatched = totalPanels > 0 && allocatedPanels == totalPanels;
    final isOver = totalPanels > 0 && allocatedPanels > totalPanels;
    final isUnder = totalPanels > 0 && allocatedPanels < totalPanels;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
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
          // Row 1: Title & Toolbar Controls
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.solar_power_rounded, size: 18, color: AppTheme.primaryNavy),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'قياسات سلاسل وصناديق التجميع',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_activeBoxes.length} صناديق نشطة • $totalCount سلسلة • $completedCount مقاسة',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // View Mode Smart Toggle (Focus vs List)
              _buildIconAction(
                icon: _isFocusMode ? Icons.view_agenda_outlined : Icons.filter_center_focus_rounded,
                tooltip: _isFocusMode ? 'عرض الكل في قائمة واحدة' : 'وضع التركيز (صندوق تلو الآخر)',
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isFocusMode = !_isFocusMode);
                },
              ),
              const SizedBox(width: 4),

              // Unified Actions & Settings Popup Menu
              PopupMenuButton<String>(
                tooltip: 'خيارات وإعدادات إضافية',
                icon: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.primaryNavy),
                ),
                padding: EdgeInsets.zero,
                onSelected: (val) {
                  if (val == 'config_boxes') _showBoxesConfigSheet();
                  if (val == 'manage_panels') _showPanelsManagementSheet();
                  if (val == 'copy_all') _copyBox1ToAll();
                  if (val == 'fill_std') _fillTypicalValues(baseVoc: 135.2, baseIsc: 8.4, label: 'قياسية 330W');
                  if (val == 'fill_half') _fillTypicalValues(baseVoc: 196.5, baseIsc: 13.5, label: 'ألواح 550W');
                  if (val == 'fill_custom') _showCustomFillDialog();
                  if (val == 'clear') _clearActiveStrings();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'config_boxes',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryNavy),
                        SizedBox(width: 8),
                        Text('تحديد الصناديق المضمنة بالتقرير'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manage_panels',
                    child: Row(
                      children: [
                        Icon(Icons.solar_power_rounded, size: 16, color: AppTheme.primaryNavy),
                        SizedBox(width: 8),
                        Text('إدارة وتوزيع ألواح المنظومة ⚡'),
                      ],
                    ),
                  ),
                  if (_activeBoxes.length > 1)
                    const PopupMenuItem(
                      value: 'copy_all',
                      child: Row(
                        children: [
                          Icon(Icons.copy_all_rounded, size: 16, color: Color(0xFF16A34A)),
                          SizedBox(width: 8),
                          Text('نسخ قراءات الصندوق #1 لباقي الصناديق'),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'fill_half',
                    child: Text('تعبئة نموذجية: ألواح حديثة 545W-550W'),
                  ),
                  const PopupMenuItem(
                    value: 'fill_std',
                    child: Text('تعبئة نموذجية: ألواح قياسية 330W-350W'),
                  ),
                  const PopupMenuItem(
                    value: 'fill_custom',
                    child: Text('تعبئة نموذجية: بقيم مخصصة...'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('مسح قراءات السلاسل النشطة', style: TextStyle(color: Colors.red.shade700)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Unified Panels Banner & Progress
          InkWell(
            onTap: _showPanelsManagementSheet,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isMatched
                    ? const Color(0xFFF0FDF4)
                    : (totalPanels > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isMatched
                      ? const Color(0xFF86EFAC)
                      : (totalPanels > 0 ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isMatched
                        ? Icons.check_circle_rounded
                        : (isOver ? Icons.warning_amber_rounded : Icons.tune_rounded),
                    size: 15,
                    color: isMatched
                        ? const Color(0xFF16A34A)
                        : (isOver ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      totalPanels > 0
                          ? 'ألواح المنظومة: $totalPanels لوح • الموزع: $allocatedPanels ${isMatched ? "(مكتمل 100%)" : (isUnder ? "(متبقي ${totalPanels - allocatedPanels})" : "(تجاوز)")}'
                          : 'توزيع الألواح: $allocatedPanels لوح موزع (انقر للإعداد والتحكم)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isMatched
                            ? const Color(0xFF15803D)
                            : (isOver ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? const Color(0xFF16A34A) : AppTheme.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2️⃣ Segmented Box Tabs Bar (Focus Mode) ──────────────────

  Widget _buildBoxTabsBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        controller: _chipsScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _activeBoxes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
          final boxPanels = widget.report.getBoxPanelCount(bNum);

          Color bgColor;
          Color borderColor;
          Color textColor;

          if (isSelected) {
            bgColor = AppTheme.primaryNavy;
            borderColor = AppTheme.primaryNavy;
            textColor = Colors.white;
          } else if (isComplete) {
            bgColor = const Color(0xFFF0FDF4);
            borderColor = const Color(0xFF86EFAC);
            textColor = const Color(0xFF15803D);
          } else if (isPartial) {
            bgColor = const Color(0xFFFFFBEB);
            borderColor = const Color(0xFFFDE68A);
            textColor = const Color(0xFFB45309);
          } else {
            bgColor = Colors.white;
            borderColor = const Color(0xFFE2E8F0);
            textColor = AppTheme.textDark;
          }

          return InkWell(
            onTap: () => _selectBoxWithAnimation(bNum),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 1.6 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryNavy.withValues(alpha: 0.22),
                          blurRadius: 5,
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
                    Icon(Icons.circle_outlined, size: 13, color: isSelected ? Colors.white70 : const Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    'صندوق #$bNum',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (boxPanels > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : (isComplete ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${boxPanels}L',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : (isComplete ? const Color(0xFF166534) : AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 5),
                  Text(
                    '($filledInBox/4)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white70 : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── 3️⃣ Active Combiner Box Workspace ──────────────────────────

  Widget _buildActiveBoxWorkspace(int bNum, {bool isOverview = false}) {
    final boxPanels = widget.report.getBoxPanelCount(bNum);
    final perString = boxPanels > 0 ? (boxPanels ~/ 4) : 0;
    final boxStrings = [1, 2, 3, 4].map((sNum) {
      final sIdx = ((bNum - 1) * 4) + sNum;
      return widget.report.stringMeasurements.firstWhere(
        (s) => s.stringNumber == sIdx,
        orElse: () => StringMeasurement(
          stringNumber: sIdx,
          panelCount: perString,
          openCircuitVoltageVoc: 0,
          shortCircuitCurrentIsc: 0,
        ),
      );
    }).toList();

    int filledCount = 0;
    double sumVoc = 0;
    double sumIsc = 0;
    double minVoc = double.infinity;
    double maxVoc = 0;

    for (final s in boxStrings) {
      if (s.openCircuitVoltageVoc > 0 && s.shortCircuitCurrentIsc > 0) {
        filledCount++;
        sumVoc += s.openCircuitVoltageVoc;
        sumIsc += s.shortCircuitCurrentIsc;
        if (s.openCircuitVoltageVoc < minVoc) minVoc = s.openCircuitVoltageVoc;
        if (s.openCircuitVoltageVoc > maxVoc) maxVoc = s.openCircuitVoltageVoc;
      }
    }

    final isAllFilled = filledCount == 4;
    final isPartiallyFilled = filledCount > 0 && filledCount < 4;
    final avgVoc = filledCount > 0 ? sumVoc / filledCount : 0.0;
    final avgIsc = filledCount > 0 ? sumIsc / filledCount : 0.0;
    final deltaVoc = (filledCount >= 2 && minVoc < double.infinity) ? (maxVoc - minVoc) : 0.0;

    final currentIndex = _activeBoxes.indexOf(bNum);
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex != -1 && currentIndex < _activeBoxes.length - 1;

    return Container(
      key: ValueKey('box_workspace_${bNum}_rev_$_revision'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAllFilled
              ? const Color(0xFF86EFAC)
              : (isPartiallyFilled ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
          width: isAllFilled ? 1.4 : 1.1,
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
          // ── Workspace Header (Row 1: Identity & Status + Actions) ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.solar_power_rounded, size: 13, color: AppTheme.solarGold),
                    const SizedBox(width: 4),
                    Text(
                      'صندوق #$bNum',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'سلاسل ${((bNum - 1) * 4) + 1}-${bNum * 4}',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),

              const Spacer(),

              // Completion Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isAllFilled
                      ? const Color(0xFFF0FDF4)
                      : (isPartiallyFilled ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isAllFilled
                        ? const Color(0xFF86EFAC)
                        : (isPartiallyFilled ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAllFilled
                          ? Icons.check_circle_rounded
                          : (isPartiallyFilled ? Icons.adjust_rounded : Icons.radio_button_unchecked_rounded),
                      size: 11,
                      color: isAllFilled
                          ? const Color(0xFF16A34A)
                          : (isPartiallyFilled ? const Color(0xFFD97706) : AppTheme.textMuted),
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      isAllFilled ? 'مكتمل (4/4)' : (isPartiallyFilled ? '$filledCount / 4' : 'فارغ'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAllFilled
                            ? const Color(0xFF166534)
                            : (isPartiallyFilled ? const Color(0xFFB45309) : AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // Single Box Actions Menu
              PopupMenuButton<String>(
                tooltip: 'إجراءات الصندوق #$bNum',
                icon: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.more_vert_rounded, size: 16, color: AppTheme.textDark),
                ),
                padding: EdgeInsets.zero,
                onSelected: (val) {
                  if (val == 'copy_from_1') _copyBox1ToBox(bNum);
                  if (val == 'fill_typical') _fillSingleBoxTypical(bNum);
                  if (val == 'clear') _clearSingleBoxStrings(bNum);
                  if (val == 'edit_panels') _showEditBoxPanelsDialog(bNum);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit_panels',
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryNavy),
                        const SizedBox(width: 8),
                        Text('تعديل ألواح الصندوق ($boxPanels لوح)'),
                      ],
                    ),
                  ),
                  if (bNum != 1)
                    const PopupMenuItem(
                      value: 'copy_from_1',
                      child: Row(
                        children: [
                          Icon(Icons.copy_all_rounded, size: 16, color: Color(0xFF16A34A)),
                          SizedBox(width: 8),
                          Text('نسخ قراءات الصندوق #1 إلى هذا الصندوق'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'fill_typical',
                    child: Row(
                      children: [
                        Icon(Icons.auto_fix_high_rounded, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 8),
                        Text('تعبئة نموذجية لهذا الصندوق فقط'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text('تصفير قراءات هذا الصندوق', style: TextStyle(color: Colors.red.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Workspace Header (Row 2: Full-Width Interactive Panels Banner) ──
          InkWell(
            onTap: () => _showEditBoxPanelsDialog(bNum),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: boxPanels > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: boxPanels > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 14,
                    color: boxPanels > 0 ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      boxPanels > 0
                          ? '$boxPanels لوح بالمصفوفة • 4 سلاسل × $perString ألواح توالي'
                          : 'ألواح المصفوفة: غير محدد (انقر للتعيين والتوزيع)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: boxPanels > 0 ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: boxPanels > 0 ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                  ),
                ],
              ),
            ),
          ),

          // ── Technical Telemetry Dashboard (Balanced 3-Column Mini-KPI Bar) ──
          if (filledCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // KPI 1: Voc
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'متوسط Voc',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${avgVoc.toStringAsFixed(1)} V',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 22, color: const Color(0xFFCBD5E1)),
                  // KPI 2: Isc
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'متوسط Isc',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${avgIsc.toStringAsFixed(1)} A',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 22, color: const Color(0xFFCBD5E1)),
                  // KPI 3: Delta V
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'اتزان الجهد ΔV',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              filledCount >= 2 ? '${deltaVoc.toStringAsFixed(1)} V' : '—',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: deltaVoc <= 3.0 ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              ),
                            ),
                            if (filledCount >= 2) ...[
                              const SizedBox(width: 3),
                              Icon(
                                deltaVoc <= 3.0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                size: 12,
                                color: deltaVoc <= 3.0 ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Strings Table Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text('سلسلة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy), textAlign: TextAlign.center),
                ),
                SizedBox(width: 6),
                SizedBox(
                  width: 42,
                  child: Text('ألواح', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy), textAlign: TextAlign.center),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text('Voc (فولت)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy), textAlign: TextAlign.center),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text('Isc (أمبير)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy), textAlign: TextAlign.center),
                ),
                SizedBox(width: 26),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Strings Rows ──
          ...boxStrings.map((str) {
            final isMeasured = str.openCircuitVoltageVoc > 0 || str.shortCircuitCurrentIsc > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isMeasured ? Colors.white : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMeasured ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // String number badge
                  Container(
                    width: 36,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isMeasured ? AppTheme.primaryNavy.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${str.stringNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: isMeasured ? AppTheme.primaryNavy : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // String panel count badge
                  Builder(builder: (_) {
                    final effCount = str.panelCount > 0 ? str.panelCount : perString;
                    return Container(
                      width: 42,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: effCount > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: effCount > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        effCount > 0 ? '${effCount}L' : '—',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: effCount > 0 ? const Color(0xFF1D4ED8) : AppTheme.textMuted,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),

                  // Voc Field
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 38,
                      child: TextFormField(
                        key: ValueKey('voc_${str.stringNumber}_rev_$_revision'),
                        initialValue: str.openCircuitVoltageVoc > 0 ? '${str.openCircuitVoltageVoc}' : '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          hintText: '135.2',
                          hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
                          suffixText: 'V',
                          suffixStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: BorderSide(
                              color: str.openCircuitVoltageVoc > 0 ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
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
                  ),
                  const SizedBox(width: 8),

                  // Isc Field
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 38,
                      child: TextFormField(
                        key: ValueKey('isc_${str.stringNumber}_rev_$_revision'),
                        initialValue: str.shortCircuitCurrentIsc > 0 ? '${str.shortCircuitCurrentIsc}' : '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.next,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          hintText: '8.4',
                          hintStyle: TextStyle(fontSize: 11.5, color: Colors.grey.shade400),
                          suffixText: 'A',
                          suffixStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
                            borderSide: BorderSide(
                              color: str.shortCircuitCurrentIsc > 0 ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(7),
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
                  ),
                  const SizedBox(width: 6),

                  // Row status icon
                  SizedBox(
                    width: 20,
                    child: Icon(
                      (str.openCircuitVoltageVoc > 0 && str.shortCircuitCurrentIsc > 0)
                          ? Icons.check_circle_rounded
                          : Icons.remove_rounded,
                      size: 15,
                      color: (str.openCircuitVoltageVoc > 0 && str.shortCircuitCurrentIsc > 0)
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            );
          }),

          // ── Focus Mode Box Navigation Footer ──
          if (!isOverview && _activeBoxes.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (hasPrev)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectBoxWithAnimation(_activeBoxes[currentIndex - 1]),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: Text('صندوق #${_activeBoxes[currentIndex - 1]} السابق', style: const TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryNavy,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                if (hasNext)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _selectBoxWithAnimation(_activeBoxes[currentIndex + 1]),
                      icon: const Icon(Icons.arrow_back_rounded, size: 14),
                      label: Text('صندوق #${_activeBoxes[currentIndex + 1]} التالي', style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Single Box Action Helpers ─────────────────────────────────

  void _selectBoxWithAnimation(int bNum) {
    HapticFeedback.selectionClick();
    setState(() => _selectedBoxIndex = bNum);
    final idx = _activeBoxes.indexOf(bNum);
    if (idx != -1 && _chipsScrollController.hasClients) {
      final targetOffset = (idx * 115.0) - 40.0;
      _chipsScrollController.animateTo(
        targetOffset.clamp(0.0, _chipsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _copyBox1ToBox(int targetBox) {
    if (targetBox == 1) return;
    HapticFeedback.lightImpact();
    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
    final box1Strings = [1, 2, 3, 4].map((sNum) {
      return list.firstWhere(
        (m) => m.stringNumber == sNum,
        orElse: () => const StringMeasurement(stringNumber: 0),
      );
    }).toList();

    final hasData = box1Strings.any((s) => s.openCircuitVoltageVoc > 0 || s.shortCircuitCurrentIsc > 0);
    if (!hasData) {
      _showFeedback('يرجى إدخال قراءات الصندوق #1 أولاً ليتم نسخها');
      return;
    }

    final targetPanels = widget.report.getBoxPanelCount(targetBox);
    final perString = targetPanels > 0 ? (targetPanels ~/ 4) : 0;

    for (int sNum = 1; sNum <= 4; sNum++) {
      final targetIdx = ((targetBox - 1) * 4) + sNum;
      final src = box1Strings[sNum - 1];
      final existingIdx = list.indexWhere((s) => s.stringNumber == targetIdx);
      if (existingIdx != -1) {
        list[existingIdx] = list[existingIdx].copyWith(
          openCircuitVoltageVoc: src.openCircuitVoltageVoc,
          shortCircuitCurrentIsc: src.shortCircuitCurrentIsc,
          panelCount: perString > 0 ? perString : list[existingIdx].panelCount,
        );
      } else {
        list.add(StringMeasurement(
          stringNumber: targetIdx,
          panelCount: perString,
          openCircuitVoltageVoc: src.openCircuitVoltageVoc,
          shortCircuitCurrentIsc: src.shortCircuitCurrentIsc,
        ));
      }
    }
    setState(() => _revision++);
    widget.onReportUpdated(widget.report.copyWith(stringMeasurements: list));
    _showFeedback('تم نسخ قراءات الصندوق #1 إلى الصندوق #$targetBox بنجاح');
  }

  void _fillSingleBoxTypical(int bNum) {
    HapticFeedback.lightImpact();
    final boxPanels = widget.report.getBoxPanelCount(bNum);
    final perString = boxPanels > 0 ? (boxPanels ~/ 4) : 0;
    final double baseVoc = perString > 0 ? (perString * 45.0) : 135.2;
    const double baseIsc = 8.4;

    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
    for (int sNum = 1; sNum <= 4; sNum++) {
      final sIdx = ((bNum - 1) * 4) + sNum;
      final voc = baseVoc + ((sIdx % 4) * 0.3);
      final isc = baseIsc + ((sIdx % 3) * 0.2);
      final existingIdx = list.indexWhere((s) => s.stringNumber == sIdx);
      if (existingIdx != -1) {
        list[existingIdx] = list[existingIdx].copyWith(
          panelCount: perString > 0 ? perString : list[existingIdx].panelCount,
          openCircuitVoltageVoc: double.parse(voc.toStringAsFixed(1)),
          shortCircuitCurrentIsc: double.parse(isc.toStringAsFixed(1)),
        );
      } else {
        list.add(StringMeasurement(
          stringNumber: sIdx,
          panelCount: perString,
          openCircuitVoltageVoc: double.parse(voc.toStringAsFixed(1)),
          shortCircuitCurrentIsc: double.parse(isc.toStringAsFixed(1)),
        ));
      }
    }
    setState(() => _revision++);
    widget.onReportUpdated(widget.report.copyWith(stringMeasurements: list));
    _showFeedback('تم تعبئة قراءات نموذجية للصندوق #$bNum');
  }

  void _clearSingleBoxStrings(int bNum) {
    HapticFeedback.mediumImpact();
    final list = List<StringMeasurement>.from(widget.report.stringMeasurements);
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
    setState(() => _revision++);
    widget.onReportUpdated(widget.report.copyWith(stringMeasurements: list));
    _showFeedback('تم تصفير قراءات الصندوق #$bNum');
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
