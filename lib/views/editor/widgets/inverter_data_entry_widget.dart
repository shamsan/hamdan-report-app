import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/measurement_data.dart';
import '../../../models/report.dart';

/// ويدجت إدخال بيانات الإنفرترات مصمم ومحسن بأعلى معايير الهواتف المحمولة
/// يضمن عدم تكدس الحقول أفقياً وتوفير تجربة إدخال سريعة ودقيقة في الميدان.
class InverterDataEntryWidget extends StatefulWidget {
  final Report report;
  final ValueChanged<Report> onReportUpdated;

  const InverterDataEntryWidget({
    super.key,
    required this.report,
    required this.onReportUpdated,
  });

  @override
  State<InverterDataEntryWidget> createState() => _InverterDataEntryWidgetState();
}

class _InverterDataEntryWidgetState extends State<InverterDataEntryWidget> {
  int _selectedInverterIndex = 1;
  bool _isFocusMode = true;
  int _revision = 0;
  final ScrollController _chipsScrollController = ScrollController();

  int get _effectiveInvCount {
    final invMatch = RegExp(r'\d+').firstMatch(widget.report.systemSpecs.invertersCount);
    final parsed = invMatch != null ? (int.tryParse(invMatch.group(0)!) ?? 1) : 1;
    return parsed.clamp(1, 13);
  }

  @override
  void initState() {
    super.initState();
    _selectedInverterIndex = 1;
  }

  @override
  void didUpdateWidget(covariant InverterDataEntryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedInverterIndex > _effectiveInvCount) {
      setState(() {
        _selectedInverterIndex = _effectiveInvCount;
      });
    }
  }

  @override
  void dispose() {
    _chipsScrollController.dispose();
    super.dispose();
  }

  String _getOpValue(String id, {String fallback = ''}) {
    final match = widget.report.operationalData.firstWhere(
      (o) => o.id == id,
      orElse: () => OperationalData(id: id, parameter: '', unit: '', measuredValue: fallback, standardRange: ''),
    );
    return match.measuredValue;
  }

  void _setInList(
    List<OperationalData> list,
    String id,
    String val, {
    String parameter = '',
    String unit = '',
    String range = '',
  }) {
    final cleanVal = val.trim();
    final idx = list.indexWhere((o) => o.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(measuredValue: cleanVal);
    } else {
      list.add(OperationalData(
        id: id,
        parameter: parameter,
        unit: unit,
        measuredValue: cleanVal,
        standardRange: range,
        status: 'طبيعي',
      ));
    }
  }

  void _updateLoad(int u, String val) {
    final clean = val.trim();
    final list = List<OperationalData>.from(widget.report.operationalData);
    _setInList(list, 'op_load_$u', clean, parameter: 'الحمل على الإنفرتر #$u', unit: 'W', range: '< 5000');
    if (u == 1) {
      _setInList(list, 'op_load', clean, parameter: 'الحمل على الإنفرتر', unit: 'W', range: '< 5000');
    }
    widget.onReportUpdated(widget.report.copyWith(operationalData: list));
  }

  void _updateAc(int u, String val) {
    final clean = val.trim();
    final list = List<OperationalData>.from(widget.report.operationalData);
    _setInList(list, 'op_ac_v_$u', clean, parameter: 'فرق جهد الخرج (متردد) #$u', unit: 'Vac', range: '220 - 230');
    if (u == 1) {
      _setInList(list, 'op_ac_v', clean, parameter: 'فرق جهد الخرج (متردد)', unit: 'Vac', range: '220 - 230');
    }
    widget.onReportUpdated(widget.report.copyWith(operationalData: list));
  }

  void _updateDc(int u, String val) {
    final clean = val.trim();
    final list = List<OperationalData>.from(widget.report.operationalData);
    _setInList(list, 'op_dc_v_$u', clean, parameter: 'فرق جهد الدخول (مستمر) #$u', unit: 'Vdc', range: '48.0 - 54.0');
    if (u == 1) {
      _setInList(list, 'op_dc_v', clean, parameter: 'فرق جهد الدخول (مستمر)', unit: 'Vdc', range: '48.0 - 54.0');
    }
    widget.onReportUpdated(widget.report.copyWith(operationalData: list));
  }

  void _updateMonitoring(int u, bool isMon) {
    final list = List<OperationalData>.from(widget.report.operationalData);
    _setInList(list, 'op_inv_mon_$u', isMon ? 'true' : 'false', parameter: 'شاشة المراقبة إنفرتر #$u');
    widget.onReportUpdated(widget.report.copyWith(operationalData: list));
  }

  void _changeInverterCount(int newCount) {
    if (newCount < 1 || newCount > 13) return;
    HapticFeedback.lightImpact();
    final updatedSpecs = widget.report.systemSpecs.copyWith(
      invertersCount: '$newCount',
    );
    widget.onReportUpdated(widget.report.copyWith(systemSpecs: updatedSpecs));
    if (_selectedInverterIndex > newCount) {
      setState(() {
        _selectedInverterIndex = newCount;
      });
    }
  }

  void _copyVoltagesFrom1ToAll() {
    HapticFeedback.lightImpact();
    final ac1 = _getOpValue('op_ac_v_1', fallback: _getOpValue('op_ac_v'));
    final dc1 = _getOpValue('op_dc_v_1', fallback: _getOpValue('op_dc_v'));

    if (ac1.isEmpty && dc1.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال جهد الخرج أو الدخول للإنفرتر #1 أولاً ليتم نسخه')),
      );
      return;
    }

    final list = List<OperationalData>.from(widget.report.operationalData);
    for (int u = 2; u <= _effectiveInvCount; u++) {
      if (ac1.isNotEmpty) {
        _setInList(list, 'op_ac_v_$u', ac1, parameter: 'فرق جهد الخرج (متردد) #$u', unit: 'Vac', range: '220 - 230');
      }
      if (dc1.isNotEmpty) {
        _setInList(list, 'op_dc_v_$u', dc1, parameter: 'فرق جهد الدخول (مستمر) #$u', unit: 'Vdc', range: '48.0 - 54.0');
      }
    }
    setState(() => _revision++);
    widget.onReportUpdated(widget.report.copyWith(operationalData: list));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ جهود الإنفرتر #1 بنجاح إلى باقي الإنفرترات ($_effectiveInvCount)')),
    );
  }

  void _copyFromPreviousInverter(int u) {
    if (u <= 1) return;
    HapticFeedback.lightImpact();
    final prevU = u - 1;
    final prevAc = _getOpValue('op_ac_v_$prevU', fallback: prevU == 1 ? _getOpValue('op_ac_v') : '');
    final prevDc = _getOpValue('op_dc_v_$prevU', fallback: prevU == 1 ? _getOpValue('op_dc_v') : '');
    final prevLoad = _getOpValue('op_load_$prevU', fallback: prevU == 1 ? _getOpValue('op_load') : '');

    final list = List<OperationalData>.from(widget.report.operationalData);
    if (prevAc.isNotEmpty) {
      _setInList(list, 'op_ac_v_$u', prevAc, parameter: 'فرق جهد الخرج (متردد) #$u', unit: 'Vac', range: '220 - 230');
    }
    if (prevDc.isNotEmpty) {
      _setInList(list, 'op_dc_v_$u', prevDc, parameter: 'فرق جهد الدخول (مستمر) #$u', unit: 'Vdc', range: '48.0 - 54.0');
    }
    if (prevLoad.isNotEmpty) {
      _setInList(list, 'op_load_$u', prevLoad, parameter: 'الحمل على الإنفرتر #$u', unit: 'W', range: '< 5000');
    }
    setState(() => _revision++);
    widget.onReportUpdated(widget.report.copyWith(operationalData: list));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ قراءات الإنفرتر #$prevU إلى الإنفرتر #$u بنجاح')),
    );
  }

  void _fillTypicalValues() {
    HapticFeedback.lightImpact();
    final list = List<OperationalData>.from(widget.report.operationalData);
    for (int u = 1; u <= _effectiveInvCount; u++) {
      final load = (3200 + ((u % 3) * 150) - ((u % 2) * 100)).toString();
      final ac = (228.0 + ((u % 4) * 0.5)).toStringAsFixed(1);
      final dc = (52.2 + ((u % 3) * 0.3)).toStringAsFixed(1);

      _setInList(list, 'op_load_$u', load, parameter: 'الحمل على الإنفرتر #$u', unit: 'W', range: '< 5000');
      _setInList(list, 'op_ac_v_$u', ac, parameter: 'فرق جهد الخرج (متردد) #$u', unit: 'Vac', range: '220 - 230');
      _setInList(list, 'op_dc_v_$u', dc, parameter: 'فرق جهد الدخول (مستمر) #$u', unit: 'Vdc', range: '48.0 - 54.0');
      _setInList(list, 'op_inv_mon_$u', 'true', parameter: 'شاشة المراقبة إنفرتر #$u');

      if (u == 1) {
        _setInList(list, 'op_load', load, parameter: 'الحمل على الإنفرتر', unit: 'W', range: '< 5000');
        _setInList(list, 'op_ac_v', ac, parameter: 'فرق جهد الخرج (متردد)', unit: 'Vac', range: '220 - 230');
        _setInList(list, 'op_dc_v', dc, parameter: 'فرق جهد الدخول (مستمر)', unit: 'Vdc', range: '48.0 - 54.0');
      }
    }
    setState(() => _revision++);
    widget.onReportUpdated(widget.report.copyWith(operationalData: list));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تمت تعبئة بيانات نموذجية لجميع الإنفرترات ($_effectiveInvCount)')),
    );
  }

  void _clearInverter(int u) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('مسح بيانات الإنفرتر #$u'),
        content: const Text('هل أنت متأكد من رغبتك في مسح قراءات هذا الإنفرتر؟'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.statusRejected,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(0, 48),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              final list = List<OperationalData>.from(widget.report.operationalData);
              _setInList(list, 'op_load_$u', '', parameter: 'الحمل على الإنفرتر #$u', unit: 'W');
              _setInList(list, 'op_ac_v_$u', '', parameter: 'فرق جهد الخرج (متردد) #$u', unit: 'Vac');
              _setInList(list, 'op_dc_v_$u', '', parameter: 'فرق جهد الدخول (مستمر) #$u', unit: 'Vdc');
              if (u == 1) {
                _setInList(list, 'op_load', '', parameter: 'الحمل على الإنفرتر', unit: 'W');
                _setInList(list, 'op_ac_v', '', parameter: 'فرق جهد الخرج (متردد)', unit: 'Vac');
                _setInList(list, 'op_dc_v', '', parameter: 'فرق جهد الدخول (مستمر)', unit: 'Vdc');
              }
              setState(() => _revision++);
              widget.onReportUpdated(widget.report.copyWith(operationalData: list));
            },
            child: const Text('مسح'),
          ),
        ],
      ),
    );
  }

  void _scrollToSelectedChip(int index) {
    if (!_chipsScrollController.hasClients) return;
    const itemWidth = 105.0;
    final targetOffset = (index - 1) * itemWidth;
    _chipsScrollController.animateTo(
      targetOffset.clamp(0.0, _chipsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  // --- Statistics Calculation ---
  double get _totalLoadWatts {
    double total = 0.0;
    for (int u = 1; u <= _effectiveInvCount; u++) {
      final valStr = _getOpValue('op_load_$u', fallback: u == 1 ? _getOpValue('op_load') : '');
      final numVal = double.tryParse(valStr) ?? 0.0;
      total += numVal;
    }
    return total;
  }

  double? get _averageAcVoltage {
    double sum = 0.0;
    int count = 0;
    for (int u = 1; u <= _effectiveInvCount; u++) {
      final valStr = _getOpValue('op_ac_v_$u', fallback: u == 1 ? _getOpValue('op_ac_v') : '');
      final numVal = double.tryParse(valStr);
      if (numVal != null && numVal > 0) {
        sum += numVal;
        count++;
      }
    }
    return count > 0 ? (sum / count) : null;
  }

  double? get _averageDcVoltage {
    double sum = 0.0;
    int count = 0;
    for (int u = 1; u <= _effectiveInvCount; u++) {
      final valStr = _getOpValue('op_dc_v_$u', fallback: u == 1 ? _getOpValue('op_dc_v') : '');
      final numVal = double.tryParse(valStr);
      if (numVal != null && numVal > 0) {
        sum += numVal;
        count++;
      }
    }
    return count > 0 ? (sum / count) : null;
  }

  int get _completedInvertersCount {
    int count = 0;
    for (int u = 1; u <= _effectiveInvCount; u++) {
      final loadStr = _getOpValue('op_load_$u', fallback: u == 1 ? _getOpValue('op_load') : '');
      final acStr = _getOpValue('op_ac_v_$u', fallback: u == 1 ? _getOpValue('op_ac_v') : '');
      final dcStr = _getOpValue('op_dc_v_$u', fallback: u == 1 ? _getOpValue('op_dc_v') : '');
      if (loadStr.trim().isNotEmpty && acStr.trim().isNotEmpty && dcStr.trim().isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Executive Summary & KPIs Card
        _buildSummaryDashboard(),

        const SizedBox(height: 12),

        // 2. View Mode Switcher & Quick Actions
        _buildModeAndActionsBar(),

        const SizedBox(height: 12),

        // 3. Inverter Selector Chips (Horizontal Bar)
        if (_isFocusMode) ...[
          _buildInverterChipsSelector(),
          const SizedBox(height: 12),
          _buildActiveInverterCard(_selectedInverterIndex),
        ] else ...[
          // List Mode (Stacked clean cards for all inverters)
          ...List.generate(_effectiveInvCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildActiveInverterCard(i + 1, isCompact: true),
            );
          }),
        ],
      ],
    );
  }

  // --- Summary & KPI Dashboard ---
  Widget _buildSummaryDashboard() {
    final totalKw = _totalLoadWatts / 1000.0;
    final avgAc = _averageAcVoltage;
    final avgDc = _averageDcVoltage;
    final completed = _completedInvertersCount;
    final total = _effectiveInvCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderMedium, width: 1.2),
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
          // Title + Inverter Count Stepper
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, size: 20, color: AppTheme.primaryNavy),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'بيانات تشغيل الإنفرترات',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
              ),
              // Count Controller (+ / -)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderMedium),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: total > 1 ? () => _changeInverterCount(total - 1) : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 16,
                          color: total > 1 ? AppTheme.textDark : Colors.grey[400],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$total عواكس',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                    ),
                    InkWell(
                      onTap: total < 13 ? () => _changeInverterCount(total + 1) : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: total < 13 ? AppTheme.primaryNavy : Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // KPIs Grid (Adaptive 2x2 on mobile, 1x4 on tablet)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 420;
              final loadTile = _buildKpiTile(
                title: 'إجمالي الحمل',
                value: totalKw > 0 ? '${totalKw.toStringAsFixed(1)} kW' : '0.0 kW',
                subtitle: '${_totalLoadWatts.toInt()} W',
                icon: Icons.electric_meter_rounded,
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
              );
              final acTile = _buildKpiTile(
                title: 'متوسط جهد AC',
                value: avgAc != null ? '${avgAc.toStringAsFixed(1)} V' : '--',
                subtitle: 'معيار: 220-230V',
                icon: Icons.power_rounded,
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
              );
              final dcTile = _buildKpiTile(
                title: 'متوسط جهد DC',
                value: avgDc != null ? '${avgDc.toStringAsFixed(1)} V' : '--',
                subtitle: 'معيار: 48-54V',
                icon: Icons.battery_charging_full_rounded,
                color: AppTheme.solarGold,
                bgColor: const Color(0xFFFFFBEB),
              );
              final compTile = _buildKpiTile(
                title: 'المكتمل',
                value: '$completed / $total',
                subtitle: completed == total ? 'مكتمل 100%' : 'قيد الإدخال',
                icon: Icons.check_circle_outline_rounded,
                color: completed == total ? const Color(0xFF16A34A) : AppTheme.textMuted,
                bgColor: completed == total ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              );

              if (isSmall) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: loadTile),
                        const SizedBox(width: 8),
                        Expanded(child: compTile),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: acTile),
                        const SizedBox(width: 8),
                        Expanded(child: dcTile),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: loadTile),
                  const SizedBox(width: 8),
                  Expanded(child: acTile),
                  const SizedBox(width: 8),
                  Expanded(child: dcTile),
                  const SizedBox(width: 8),
                  Expanded(child: compTile),
                ],
              );
            },
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
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

  // --- Actions & Mode Bar (Mobile-first, Zero-overflow with expressive icons) ---
  Widget _buildModeAndActionsBar() {
    return Row(
      children: [
        // Mode Switcher (Icon-Only Segmented Control with Tooltips)
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
                tooltip: 'وضع التركيز (إنفرتر تلو الآخر)',
                isSelected: _isFocusMode,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isFocusMode = true);
                },
              ),
              const SizedBox(width: 2),
              _buildModeIconButton(
                icon: Icons.view_agenda_outlined,
                tooltip: 'عرض كافة الإنفرترات في قائمة واحدة',
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

        // Copy #1 to All Action Icon Button
        if (_effectiveInvCount > 1) ...[
          _buildActionIconButton(
            icon: Icons.copy_all_rounded,
            tooltip: 'نسخ جهود إنفرتر #1 إلى باقي الإنفرترات',
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFF86EFAC),
            onTap: _copyVoltagesFrom1ToAll,
          ),
          const SizedBox(width: 8),
        ],

        // Typical fill Action Icon Button
        _buildActionIconButton(
          icon: Icons.auto_fix_high_rounded,
          tooltip: 'تعبئة نموذجية قياسية لكافة الإنفرترات',
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          onTap: _fillTypicalValues,
        ),
      ],
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
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [const BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
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
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }

  // --- Horizontal Inverter Selector Chips ---
  Widget _buildInverterChipsSelector() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        controller: _chipsScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _effectiveInvCount,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final u = index + 1;
          final isSelected = _selectedInverterIndex == u;

          // Check fill status
          final loadVal = _getOpValue('op_load_$u', fallback: u == 1 ? _getOpValue('op_load') : '');
          final acVal = _getOpValue('op_ac_v_$u', fallback: u == 1 ? _getOpValue('op_ac_v') : '');
          final dcVal = _getOpValue('op_dc_v_$u', fallback: u == 1 ? _getOpValue('op_dc_v') : '');

          final isComplete = loadVal.isNotEmpty && acVal.isNotEmpty && dcVal.isNotEmpty;
          final isPartial = !isComplete && (loadVal.isNotEmpty || acVal.isNotEmpty || dcVal.isNotEmpty);

          final loadNum = double.tryParse(loadVal);
          final loadStr = loadNum != null && loadNum > 0 ? '${(loadNum / 1000).toStringAsFixed(1)}kW' : '';

          return InkWell(
            onTap: () {
              setState(() => _selectedInverterIndex = u);
              _scrollToSelectedChip(u);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  // Status Dot/Check
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
                        'إنفرتر #$u',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      if (loadStr.isNotEmpty)
                        Text(
                          loadStr,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF166534),
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

  // --- Active Inverter Focus Card ---
  Widget _buildActiveInverterCard(int u, {bool isCompact = false}) {
    final loadVal = _getOpValue('op_load_$u', fallback: u == 1 ? _getOpValue('op_load') : '');
    final acVal = _getOpValue('op_ac_v_$u', fallback: u == 1 ? _getOpValue('op_ac_v') : '');
    final dcVal = _getOpValue('op_dc_v_$u', fallback: u == 1 ? _getOpValue('op_dc_v') : '');
    final monVal = _getOpValue('op_inv_mon_$u', fallback: 'true');
    final isMon = monVal != 'false' && monVal != '0' && monVal != 'لا';

    final isComplete = loadVal.isNotEmpty && acVal.isNotEmpty && dcVal.isNotEmpty;

    return Container(
      key: ValueKey('inverter_card_$u'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isComplete ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Title, Status Badge, Nav buttons
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: AppTheme.solarGold),
                    const SizedBox(width: 5),
                    Text(
                      'إنفرتر #$u من $_effectiveInvCount',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isComplete ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isComplete ? 'مكتمل' : 'قيد الإدخال',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? const Color(0xFF166534) : Colors.grey[600],
                  ),
                ),
              ),

              const Spacer(),

              // Quick copy from previous inverter
              if (u > 1)
                IconButton(
                  tooltip: 'نسخ من إنفرتر #${u - 1}',
                  icon: const Icon(Icons.download_rounded, size: 18, color: AppTheme.primaryNavy),
                  onPressed: () => _copyFromPreviousInverter(u),
                ),

              // Clear button
              IconButton(
                tooltip: 'مسح بيانات هذا الإنفرتر',
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                onPressed: () => _clearInverter(u),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // 1. Load Field (Full Width, Spacious on Mobile)
          _buildLoadInputField(u, loadVal),

          const SizedBox(height: 14),

          // 2. AC Voltage Field
          _buildAcVoltageInputField(u, acVal),

          const SizedBox(height: 14),

          // 3. DC Voltage Field
          _buildDcVoltageInputField(u, dcVal),

          const SizedBox(height: 14),

          // 4. Monitoring Toggle Card
          _buildMonitoringToggle(u, isMon),

          // 5. Navigation Footer (In Focus Mode only)
          if (!isCompact && _effectiveInvCount > 1) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: u > 1 ? AppTheme.primaryNavy : Colors.grey[400],
                    side: BorderSide(
                      color: u > 1 ? const Color(0xFFCBD5E1) : Colors.grey.shade200,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('السابق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: u > 1
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedInverterIndex = u - 1);
                          _scrollToSelectedChip(u - 1);
                        }
                      : null,
                ),

                // Next / Finish button
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: u < _effectiveInvCount ? AppTheme.primaryNavy : const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: Icon(
                    u < _effectiveInvCount ? Icons.arrow_back_rounded : Icons.check_rounded,
                    size: 16,
                  ),
                  label: Text(
                    u < _effectiveInvCount ? 'التالي (إنفرتر #${u + 1})' : 'تم مراجعة الكل',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (u < _effectiveInvCount) {
                      setState(() => _selectedInverterIndex = u + 1);
                      _scrollToSelectedChip(u + 1);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم الانتهاء من مراجعة كافة الإنفرترات بنجاح')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- 1. Load Field ---
  Widget _buildLoadInputField(int u, String currentVal) {
    final numVal = double.tryParse(currentVal);
    final kwStr = numVal != null && numVal > 0 ? '${(numVal / 1000).toStringAsFixed(2)} kW' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF2563EB)),
            const SizedBox(width: 6),
            const Text(
              'الحمل على الإنفرتر',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            if (kwStr != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  kwStr,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('inv_load_${u}_rev_$_revision'),
          initialValue: currentVal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: InputDecoration(
            hintText: 'مثال: 3200',
            suffixText: 'وات (W)',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
          onChanged: (v) => _updateLoad(u, v),
        ),
        const SizedBox(height: 6),
        // Quick Presets
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: ['0', '1500', '2500', '3200', '4000', '5000'].map((preset) {
            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _revision++);
                _updateLoad(u, preset);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentVal == preset ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: currentVal == preset ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$preset W',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: currentVal == preset ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- 2. AC Voltage Field ---
  Widget _buildAcVoltageInputField(int u, String currentVal) {
    final numVal = double.tryParse(currentVal);
    String? statusText;
    Color statusColor = const Color(0xFF16A34A);

    if (numVal != null && numVal > 0) {
      if (numVal >= 220 && numVal <= 235) {
        statusText = '✓ جهد طبيعي ومثالي';
        statusColor = const Color(0xFF16A34A);
      } else if (numVal < 220) {
        statusText = '⚠ جهد خرج منخفض';
        statusColor = const Color(0xFFD97706);
      } else {
        statusText = '⚠ جهد خرج مرتفع';
        statusColor = const Color(0xFFDC2626);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.power_rounded, size: 16, color: Color(0xFF16A34A)),
            const SizedBox(width: 6),
            const Text(
              'فرق جهد الخرج (متردد)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const Spacer(),
            if (statusText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              )
            else
              const Text(
                'المعيار: 220 - 230 Vac',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('inv_ac_${u}_rev_$_revision'),
          initialValue: currentVal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: InputDecoration(
            hintText: '220 - 230',
            suffixText: 'Vac',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
            ),
          ),
          onChanged: (v) => _updateAc(u, v),
        ),
        const SizedBox(height: 6),
        // Quick Presets
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: ['220', '225', '228', '230', '232'].map((preset) {
            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _revision++);
                _updateAc(u, preset);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentVal == preset ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: currentVal == preset ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$preset V',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: currentVal == preset ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- 3. DC Voltage Field ---
  Widget _buildDcVoltageInputField(int u, String currentVal) {
    final numVal = double.tryParse(currentVal);
    String? statusText;
    Color statusColor = AppTheme.solarGold;

    if (numVal != null && numVal > 0) {
      if (numVal >= 48.0 && numVal <= 54.5) {
        statusText = '✓ جهد دخول طبيعي';
        statusColor = const Color(0xFF16A34A);
      } else if (numVal < 48.0) {
        statusText = '⚠ جهد بطاريات منخفض';
        statusColor = const Color(0xFFD97706);
      } else {
        statusText = '⚠ جهد زائد';
        statusColor = const Color(0xFFDC2626);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.battery_charging_full_rounded, size: 16, color: AppTheme.solarGold),
            const SizedBox(width: 6),
            const Text(
              'فرق جهد الدخول (مستمر)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const Spacer(),
            if (statusText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              )
            else
              const Text(
                'المعيار: 48.0 - 54.0 Vdc',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('inv_dc_${u}_rev_$_revision'),
          initialValue: currentVal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: InputDecoration(
            hintText: '48.0 - 54.0',
            suffixText: 'Vdc',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.solarGold, width: 1.5),
            ),
          ),
          onChanged: (v) => _updateDc(u, v),
        ),
        const SizedBox(height: 6),
        // Quick Presets
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: ['48.0', '50.5', '51.2', '52.4', '53.5', '54.0'].map((preset) {
            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _revision++);
                _updateDc(u, preset);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentVal == preset ? AppTheme.solarGold : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: currentVal == preset ? AppTheme.solarGold : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$preset V',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: currentVal == preset ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- 4. Monitoring Toggle ---
  Widget _buildMonitoringToggle(int u, bool isMon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        value: isMon,
        activeThumbColor: const Color(0xFF16A34A),
        title: const Text(
          'متصل بشاشة المراقبة (RS485)',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
        ),
        subtitle: const Text(
          'تضمين بيانات هذا الإنفرتر في سجل شاشة التحكم المركزية',
          style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        onChanged: (val) => _updateMonitoring(u, val),
      ),
    );
  }
}
