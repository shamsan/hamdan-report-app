import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// نتيجة إعدادات مقاسات وتنسيق الصفحات
class PageLayoutResult {
  final Map<int, String> pageOrientations;
  final Set<int>? selectedPages;

  const PageLayoutResult({
    required this.pageOrientations,
    this.selectedPages,
  });
}

/// معالج ومحرر إعدادات مقاسات وتنسيق صفحات التقرير (A4 / A3 والاتجاه الأفقي / العمودي)
/// مصمم خصيصاً لشاشات هواتف أندرويد وفق معايير Material 3 وتجربة الاستخدام المريحة
class PageLayoutSettingsSheet extends StatefulWidget {
  final Map<int, String> initialOrientations;
  final Set<int>? initialSelectedPages;
  final bool allowPageSelection;
  final Map<int, String>? customPageLabels;
  final ValueChanged<PageLayoutResult>? onApplied;

  const PageLayoutSettingsSheet({
    super.key,
    required this.initialOrientations,
    this.initialSelectedPages,
    this.allowPageSelection = false,
    this.customPageLabels,
    this.onApplied,
  });

  /// إظهار ورقة التنسيق السفلية كنافذة منبثقة احترافية
  static Future<PageLayoutResult?> show(
    BuildContext context, {
    required Map<int, String> initialOrientations,
    Set<int>? initialSelectedPages,
    bool allowPageSelection = false,
    Map<int, String>? customPageLabels,
    ValueChanged<PageLayoutResult>? onApplied,
  }) {
    return showModalBottomSheet<PageLayoutResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PageLayoutSettingsSheet(
        initialOrientations: initialOrientations,
        initialSelectedPages: initialSelectedPages,
        allowPageSelection: allowPageSelection,
        customPageLabels: customPageLabels,
        onApplied: onApplied,
      ),
    );
  }

  @override
  State<PageLayoutSettingsSheet> createState() => _PageLayoutSettingsSheetState();
}

class _PageLayoutSettingsSheetState extends State<PageLayoutSettingsSheet> {
  late Map<int, String> _orientations;
  late Set<int> _selectedPages;

  static const Map<int, String> _defaultPageLabels = {
    1: 'بيانات المشروع والمرفق العام',
    2: 'الفحص 1: منظومة الألواح والبطاريات',
    3: 'الفحص 2: لوحات القواطع ومفاتيح التبديل',
    4: 'الفحص 3: الهياكل والتأريض والتهوية',
    5: 'الفحص 4: التوصيلات والسلامة العامة',
    6: 'مصفوفة قياس خلايا البطاريات (م1 - م2)',
    7: 'مصفوفة قياس خلايا البطاريات (م3 - م4)',
    8: 'بيانات التشغيل والحمل اللحظي',
    9: 'قياسات أداء السلاسل الكهروضوئية (PV Strings)',
    10: 'محضر إفادة الحضور والتواقيع والختم',
    11: 'كشف حضور فريق العمل الميداني',
    12: 'ملحق التوثيق الفوتوغرافي والصور الميدانية',
    13: 'جدول الاحتياجات وقطع الغيار المطلوبة',
  };

  static const Map<int, IconData> _pageIcons = {
    1: Icons.info_outline_rounded,
    2: Icons.solar_power_rounded,
    3: Icons.toggle_on_outlined,
    4: Icons.foundation_rounded,
    5: Icons.security_rounded,
    6: Icons.battery_charging_full_rounded,
    7: Icons.battery_charging_full_rounded,
    8: Icons.speed_rounded,
    9: Icons.grid_view_rounded,
    10: Icons.draw_rounded,
    11: Icons.groups_rounded,
    12: Icons.photo_library_rounded,
    13: Icons.handyman_rounded,
  };

  @override
  void initState() {
    super.initState();
    _orientations = Map<int, String>.from(widget.initialOrientations);
    _selectedPages = widget.initialSelectedPages != null
        ? Set<int>.from(widget.initialSelectedPages!)
        : _defaultPageLabels.keys.toSet();
  }

  Map<int, String> get _pageLabels => widget.customPageLabels ?? _defaultPageLabels;

  String _getPageSize(int pageNum) {
    final val = (_orientations[pageNum] ?? ((pageNum == 8 || pageNum == 9) ? 'a4_book' : 'a4_portrait')).toLowerCase();
    return val.contains('a3') ? 'a3' : 'a4';
  }

  String _getPageMode(int pageNum) {
    final val = (_orientations[pageNum] ?? ((pageNum == 8 || pageNum == 9) ? 'a4_book' : 'a4_portrait')).toLowerCase();
    if (val.contains('book') || val.contains('rotated')) return 'book';
    if (val.contains('landscape') || val.contains('horizontal')) return 'landscape';
    return 'portrait';
  }

  void _updatePageSize(int pageNum, String size) {
    setState(() {
      final mode = _getPageMode(pageNum);
      _orientations[pageNum] = '${size}_$mode';
    });
  }

  void _updatePageMode(int pageNum, String mode) {
    setState(() {
      final size = _getPageSize(pageNum);
      _orientations[pageNum] = '${size}_$mode';
    });
  }

  void _applyPreset(String presetKey) {
    setState(() {
      for (final p in _pageLabels.keys) {
        switch (presetKey) {
          case 'book_complete':
            // كراسة دفترياً بالكامل: كل الصفحات من 1 إلى 13 بدون استثناء في وضع التدوير الدفتري
            _orientations[p] = 'a4_book';
            break;
          case 'smart_default':
            // الوضع الذكي المعتمد: الصفحات 8 و 9 مدارة دفترياً والباقي عمودي
            _orientations[p] = (p == 8 || p == 9) ? 'a4_book' : 'a4_portrait';
            break;
          case 'book_tables':
          case 'book_all':
            // الجداول العريضة في وضع التدوير الدفتري والبقية عمودي
            _orientations[p] = (p == 6 || p == 7 || p == 8 || p == 9 || p == 13) ? 'a4_book' : 'a4_portrait';
            break;
          case 'all_a4_portrait':
            _orientations[p] = 'a4_portrait';
            break;
          case 'all_a4_landscape':
            _orientations[p] = 'a4_landscape';
            break;
          case 'all_a3_landscape':
            _orientations[p] = 'a3_landscape';
            break;
        }
      }
    });
  }

  void _saveAndClose() {
    final result = PageLayoutResult(
      pageOrientations: _orientations,
      selectedPages: widget.allowPageSelection ? _selectedPages : null,
    );
    widget.onApplied?.call(result);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final availableHeight = mq.size.height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: availableHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── هيدر الورقة السفلية ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.tune_rounded, color: AppTheme.primaryNavy, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'إعدادات مقاسات وتنسيق الصفحات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'تحديد مقاس الورق (A4 / A3) واتجاه الصفحة لملف PDF',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ─── شريط القوالب السريعة (Quick Presets) ──────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.bgSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'قوالب سريعة للتطبيق الفوري:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip(
                        icon: Icons.auto_stories_rounded,
                        label: 'كافة الصفحات دفترياً ↺',
                        color: const Color(0xFFE65100),
                        isSelected: _pageLabels.keys.every((p) =>
                            _getPageSize(p) == 'a4' && _getPageMode(p) == 'book'),
                        onTap: () => _applyPreset('book_complete'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.auto_awesome_rounded,
                        label: 'الوضع الذكي (8 و 9 دفتري)',
                        color: const Color(0xFF1565C0),
                        isSelected: _pageLabels.keys.every((p) =>
                            _getPageSize(p) == 'a4' &&
                            _getPageMode(p) == ((p == 8 || p == 9) ? 'book' : 'portrait')),
                        onTap: () => _applyPreset('smart_default'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.table_chart_rounded,
                        label: 'الجداول العريضة دفترياً',
                        color: const Color(0xFFD97706),
                        isSelected: _pageLabels.keys.every((p) =>
                            _getPageSize(p) == 'a4' &&
                            _getPageMode(p) == ((p == 6 || p == 7 || p == 8 || p == 9 || p == 13) ? 'book' : 'portrait')),
                        onTap: () => _applyPreset('book_tables'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.stay_current_portrait_rounded,
                        label: 'الكل A4 عمودي',
                        color: const Color(0xFF00897B),
                        isSelected: _pageLabels.keys.every((p) =>
                            _getPageSize(p) == 'a4' && _getPageMode(p) == 'portrait'),
                        onTap: () => _applyPreset('all_a4_portrait'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.stay_current_landscape_rounded,
                        label: 'الكل A4 أفقي',
                        color: const Color(0xFF1E88E5),
                        isSelected: _pageLabels.keys.every((p) =>
                            _getPageSize(p) == 'a4' && _getPageMode(p) == 'landscape'),
                        onTap: () => _applyPreset('all_a4_landscape'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.photo_size_select_actual_outlined,
                        label: 'الكل A3 عريض',
                        color: const Color(0xFF6A1B9A),
                        isSelected: _pageLabels.keys.every((p) =>
                            _getPageSize(p) == 'a3' && _getPageMode(p) == 'landscape'),
                        onTap: () => _applyPreset('all_a3_landscape'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderSubtle),

          // ─── قائمة بطاقات الصفحات المتجاوبة للأندرويد ─────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _pageLabels.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pageNum = _pageLabels.keys.elementAt(index);
                final pageTitle = _pageLabels[pageNum]!;
                final iconData = _pageIcons[pageNum] ?? Icons.description_outlined;
                final isSelected = _selectedPages.contains(pageNum);
                final size = _getPageSize(pageNum);
                final mode = _getPageMode(pageNum);
                final isA4 = size == 'a4';
                final isPortrait = mode == 'portrait';
                final isBook = mode == 'book';
                final isLandscape = mode == 'landscape';

                // تحديد مظهر البادج
                Color badgeBg;
                Color badgeFg;
                String badgeText;
                if (isA4 && isPortrait) {
                  badgeBg = const Color(0xFFE6FFFA);
                  badgeFg = const Color(0xFF0D9488);
                  badgeText = 'A4 عمودي';
                } else if (isA4 && isBook) {
                  badgeBg = const Color(0xFFFEF3C7);
                  badgeFg = const Color(0xFFD97706);
                  badgeText = 'A4 دفتري ↺';
                } else if (isA4 && isLandscape) {
                  badgeBg = const Color(0xFFEFF6FF);
                  badgeFg = const Color(0xFF1D4ED8);
                  badgeText = 'A4 أفقي';
                } else if (!isA4 && isBook) {
                  badgeBg = const Color(0xFFFDE8E8);
                  badgeFg = const Color(0xFF9B1C1C);
                  badgeText = 'A3 دفتري ↺';
                } else if (!isA4 && isLandscape) {
                  badgeBg = const Color(0xFFFAF5FF);
                  badgeFg = const Color(0xFF7E22CE);
                  badgeText = 'A3 عريض أفقي';
                } else {
                  badgeBg = const Color(0xFFFFFBEB);
                  badgeFg = const Color(0xFFB45309);
                  badgeText = 'A3 عمودي';
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppTheme.borderSubtle : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. عنوان الصفحة ورقمها والبادج
                      Row(
                        children: [
                          if (widget.allowPageSelection) ...[
                            Checkbox(
                              value: isSelected,
                              activeColor: AppTheme.primaryNavy,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPages.add(pageNum);
                                  } else if (_selectedPages.length > 1) {
                                    _selectedPages.remove(pageNum);
                                  }
                                });
                              },
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(iconData, size: 14, color: AppTheme.primaryNavy),
                                const SizedBox(width: 4),
                                Text(
                                  'ص $pageNum',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              pageTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AppTheme.textDark : AppTheme.textMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: badgeFg.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: badgeFg,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 2. خيارات نمط التوجيه والعرض والمقاس
                      // اختيار نمط التوجيه والعرض (عمودي vs دفتري ↺ vs أفقي كامل)
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildToggleButton(
                                label: 'عمودي',
                                icon: Icons.stay_current_portrait_rounded,
                                isSelected: isPortrait,
                                onTap: () => _updatePageMode(pageNum, 'portrait'),
                              ),
                            ),
                            Expanded(
                              child: _buildToggleButton(
                                label: 'دفتري ↺',
                                icon: Icons.auto_stories_rounded,
                                isSelected: isBook,
                                onTap: () => _updatePageMode(pageNum, 'book'),
                              ),
                            ),
                            Expanded(
                              child: _buildToggleButton(
                                label: 'أفقي كامل',
                                icon: Icons.stay_current_landscape_rounded,
                                isSelected: isLandscape,
                                onTap: () => _updatePageMode(pageNum, 'landscape'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // اختيار المقاس (A4 vs A3)
                      Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildToggleButton(
                                label: 'A4 قياسي',
                                icon: Icons.description_outlined,
                                isSelected: isA4,
                                onTap: () => _updatePageSize(pageNum, 'a4'),
                              ),
                            ),
                            Expanded(
                              child: _buildToggleButton(
                                label: 'A3 عريض',
                                icon: Icons.photo_size_select_actual_outlined,
                                isSelected: !isA4,
                                onTap: () => _updatePageSize(pageNum, 'a3'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ─── شريط التأكيد والحفظ السفلي ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppTheme.borderSubtle)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.solarGold),
                    label: Text(
                      'حفظ وتطبيق التنسيق (${_pageLabels.length} صفحة)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _saveAndClose,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
