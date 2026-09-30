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

/// معالج ومحرر إعدادات مقاسات وتنسيق صفحات التقرير وفق معايير هندسية تمنع أخطاء الطباعة والتشوه البصري
class PageLayoutSettingsSheet extends StatefulWidget {
  final Map<int, String> initialOrientations;
  final Set<int>? initialSelectedPages;
  final bool allowPageSelection;
  final Map<int, String>? customPageLabels;
  final int? activeCombinerBoxesCount;
  final ValueChanged<PageLayoutResult>? onApplied;

  const PageLayoutSettingsSheet({
    super.key,
    required this.initialOrientations,
    this.initialSelectedPages,
    this.allowPageSelection = false,
    this.customPageLabels,
    this.activeCombinerBoxesCount,
    this.onApplied,
  });

  /// إظهار ورقة التنسيق السفلية كنافذة منبثقة احترافية
  static Future<PageLayoutResult?> show(
    BuildContext context, {
    required Map<int, String> initialOrientations,
    Set<int>? initialSelectedPages,
    bool allowPageSelection = false,
    Map<int, String>? customPageLabels,
    int? activeCombinerBoxesCount,
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
        activeCombinerBoxesCount: activeCombinerBoxesCount,
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
  late String _documentPaperSize; // 'a4' أو 'a3' موحد لكامل التقرير

  static const Map<int, String> _defaultPageLabels = {
    1: 'بيانات المشروع والمرفق العام والمواصفات الفنية',
    2: 'الفحص 1: منظومة الألواح والكابلات وصناديق التجميع',
    3: 'الفحص 2: لوحات القواطع ومفاتيح التبديل (42 بنداً)',
    4: 'الفحص 3: العواكس ومنظمات الشحن والتهوية والحماية',
    5: 'الفحص 4: شبكة الإنارة والتأريض وفحص راكات البطاريات',
    6: 'مصفوفة قياس خلايا البطاريات (البنك 1 و 2)',
    7: 'مصفوفة قياس خلايا البطاريات (البنك 3 و 4)',
    8: 'بيانات التشغيل والجهد والأحمال وقراءات الإنفرترات',
    9: 'أداء سلاسل التوليد الشمسي وصناديق التجميع الـ 16',
    10: 'محضر إفادة الحضور والتواقيع والختم الرسمي',
    11: 'كشف حضور فريق العمل الميداني والمهندسين',
    12: 'ملحق التوثيق الفوتوغرافي والصور الميدانية',
    13: 'جدول الاحتياجات وقطع الغيار المطلوبة للزيارة القادمة',
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

  /// الصفحات ذات الكثافة الرأسية العالية المحمية هندسياً (عمودي إلزامي)
  static const Set<int> _lockedPortraitPages = {1, 2, 3, 4, 5, 10, 11};

  /// الصفحات ذات الجداول العريضة المتعددة الأعمدة
  static const Set<int> _widePages = {8, 9};

  @override
  void initState() {
    super.initState();
    _orientations = Map<int, String>.from(widget.initialOrientations);
    _selectedPages = widget.initialSelectedPages != null
        ? Set<int>.from(widget.initialSelectedPages!)
        : _defaultPageLabels.keys.toSet();

    // فحص ما إذا كان التقرير مضبوطاً مسبقاً بمقاس A3
    bool hasA3 = false;
    for (final val in _orientations.values) {
      if (val.toLowerCase().contains('a3')) {
        hasA3 = true;
        break;
      }
    }
    _documentPaperSize = hasA3 ? 'a3' : 'a4';
  }

  Map<int, String> get _pageLabels => widget.customPageLabels ?? _defaultPageLabels;

  int get _activeCombinerBoxesCount => widget.activeCombinerBoxesCount ?? 4;
  bool get _canPage9BePortrait => _activeCombinerBoxesCount <= 8;

  bool _isLockedPortrait(int pageNum) => _lockedPortraitPages.contains(pageNum);
  bool _isWidePage(int pageNum) => _widePages.contains(pageNum);

  String _getPageMode(int pageNum) {
    if (_isLockedPortrait(pageNum)) return 'portrait';
    // الصفحة 9: مصفوفة سلاسل التوليد وصناديق التجميع (أفقي، دفتري، أو عمودي عند قلة الصناديق)
    if (pageNum == 9) {
      final raw = _orientations[9];
      if (raw != null) {
        final val = raw.toLowerCase();
        if (val.contains('book') || val.contains('rotated')) return 'book';
        if ((val.contains('portrait') || val.contains('vertical')) && _canPage9BePortrait) {
          return 'portrait';
        }
        if (val.contains('landscape') || val.contains('horizontal')) return 'landscape';
      }
      return 'landscape';
    }
    final raw = _orientations[pageNum];
    if (raw == null) {
      return _widePages.contains(pageNum) ? 'landscape' : 'portrait';
    }
    final val = raw.toLowerCase();
    if (val.contains('book') || val.contains('rotated')) return 'book';
    if (val.contains('landscape') || val.contains('horizontal')) return 'landscape';
    if (val.contains('portrait') || val.contains('vertical')) return 'portrait';
    if (_isWidePage(pageNum)) return 'landscape';
    return 'portrait';
  }

  void _updateDocumentPaperSize(String newSize) {
    setState(() {
      _documentPaperSize = newSize;
      for (final p in _pageLabels.keys) {
        final mode = _getPageMode(p);
        _orientations[p] = '${newSize}_$mode';
      }
    });
  }

  void _updatePageMode(int pageNum, String mode) {
    if (_isLockedPortrait(pageNum)) return; // محمي هندسياً لمنع انهيار التقرير
    if (pageNum == 9 && mode == 'portrait' && !_canPage9BePortrait) return; // ممنوع عمودي للصفحة 9 إذا زادت الصناديق عن 8
    setState(() {
      _orientations[pageNum] = '${_documentPaperSize}_$mode';
    });
  }

  void _applyPreset(String presetKey) {
    setState(() {
      switch (presetKey) {
        case 'smart_digital':
          // الوضع الرقمي الذكي للشاشات والواتساب:
          // الصفحات العادية عمودية A4، والجداول العريضة 8 و 9 أفقية حقيقية لتقرأ مباشرة بالجوال
          _documentPaperSize = 'a4';
          for (final p in _pageLabels.keys) {
            _orientations[p] = _widePages.contains(p) ? 'a4_landscape' : 'a4_portrait';
          }
          break;

        case 'book_binding':
          // وضع التجليد الدفتري والطباعة الورقية على الوجهين:
          // الصفحات 8 و 9 مدارة دفترياً (-90°) والباقي عمودي
          _documentPaperSize = 'a4';
          for (final p in _pageLabels.keys) {
            _orientations[p] = _widePages.contains(p) ? 'a4_book' : 'a4_portrait';
          }
          break;

        case 'book_tables':
          // الجداول العريضة مدارة دفترياً والبقية عمودي
          _documentPaperSize = 'a4';
          for (final p in _pageLabels.keys) {
            final isTable = (p == 6 || p == 7 || p == 8 || p == 9 || p == 13);
            _orientations[p] = isTable ? 'a4_book' : 'a4_portrait';
          }
          break;

        case 'all_a4_portrait':
          _documentPaperSize = 'a4';
          for (final p in _pageLabels.keys) {
            _orientations[p] = (p == 9 && !_canPage9BePortrait) ? 'a4_landscape' : 'a4_portrait';
          }
          break;

        case 'all_a3_engineering':
          _documentPaperSize = 'a3';
          for (final p in _pageLabels.keys) {
            _orientations[p] = _widePages.contains(p) ? 'a3_landscape' : 'a3_portrait';
          }
          break;
      }
    });
  }

  void _saveAndClose() {
    // التأكد من أن جميع الصفحات تحمل مقاس الورق الموحد
    for (final p in _pageLabels.keys) {
      final mode = _getPageMode(p);
      _orientations[p] = '${_documentPaperSize}_$mode';
    }

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
    final availableHeight = mq.size.height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: availableHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── هيدر الورقة السفلية ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
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
                        'تناسيق هندسية آمنة تمنع تشوه الجداول وتضمن سلامة الطباعة والعرض',
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

          // ─── موحد مقاس الورق العام لكامل التقرير ─────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.print_outlined, size: 16, color: AppTheme.primaryNavy),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'مقاس ورق التقرير الموحد (يمنع أخطاء توقف الطابعات):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDocumentSizeButton(
                        label: 'A4 القياسي المعتمد',
                        subtitle: 'موصى به للتقارير والمكاتب والمستشفيات',
                        icon: Icons.description_rounded,
                        isSelected: _documentPaperSize == 'a4',
                        onTap: () => _updateDocumentPaperSize('a4'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDocumentSizeButton(
                        label: 'A3 العريض للمطابع',
                        subtitle: 'خاص بالمطابع الهندسية وبلوتر الرسم',
                        icon: Icons.photo_size_select_actual_outlined,
                        isSelected: _documentPaperSize == 'a3',
                        onTap: () => _updateDocumentPaperSize('a3'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── شريط القوالب السريعة الهندسية (Quick Presets) ─────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'قوالب هندسية سريعة ومضمونة:',
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
                        icon: Icons.description_rounded,
                        label: 'عمودي A4 بالكامل (منظومات مدمجة)',
                        color: const Color(0xFF2E7D32),
                        isSelected: _documentPaperSize == 'a4' &&
                            _pageLabels.keys.every((p) => _getPageMode(p) == 'portrait'),
                        onTap: () => _applyPreset('all_a4_portrait'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.smartphone_rounded,
                        label: 'الوضع الرقمي الذكي (للجوال وواتساب)',
                        color: const Color(0xFF1565C0),
                        isSelected: _documentPaperSize == 'a4' &&
                            _pageLabels.keys.every((p) =>
                                _getPageMode(p) == (_widePages.contains(p) ? 'landscape' : 'portrait')),
                        onTap: () => _applyPreset('smart_digital'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.menu_book_rounded,
                        label: 'وضع التجليد الورقي والكراسات ↺',
                        color: const Color(0xFFD97706),
                        isSelected: _documentPaperSize == 'a4' &&
                            _pageLabels.keys.every((p) =>
                                _getPageMode(p) == (_widePages.contains(p) ? 'book' : 'portrait')),
                        onTap: () => _applyPreset('book_binding'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.table_rows_rounded,
                        label: 'تدوير الجداول المعقدة دفترياً',
                        color: const Color(0xFF00897B),
                        isSelected: _documentPaperSize == 'a4' &&
                            _pageLabels.keys.every((p) =>
                                _getPageMode(p) == ((p == 6 || p == 7 || p == 8 || p == 9 || p == 13) ? 'book' : 'portrait')),
                        onTap: () => _applyPreset('book_tables'),
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        icon: Icons.engineering_rounded,
                        label: 'A3 هندسي بالكامل',
                        color: const Color(0xFF6A1B9A),
                        isSelected: _documentPaperSize == 'a3',
                        onTap: () => _applyPreset('all_a3_engineering'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderSubtle),

          // ─── قائمة بطاقات الصفحات مع الحماية الذكية ────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _pageLabels.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pageNum = _pageLabels.keys.elementAt(index);
                final pageTitle = _pageLabels[pageNum]!;
                final iconData = _pageIcons[pageNum] ?? Icons.description_outlined;
                final isSelected = _selectedPages.contains(pageNum);
                final mode = _getPageMode(pageNum);
                final isLocked = _isLockedPortrait(pageNum);
                final isWide = _isWidePage(pageNum);

                // مظهر البادج التعريفي
                Color badgeBg;
                Color badgeFg;
                String badgeText;

                if (isLocked) {
                  badgeBg = const Color(0xFFE8F5E9);
                  badgeFg = const Color(0xFF2E7D32);
                  badgeText = 'عمودي موصى به (كثافة عالية)';
                } else if (mode == 'landscape') {
                  badgeBg = const Color(0xFFE3F2FD);
                  badgeFg = const Color(0xFF1565C0);
                  badgeText = 'أفقي حقيقي (للشاشات والجوال)';
                } else if (mode == 'book') {
                  badgeBg = const Color(0xFFFFF3E0);
                  badgeFg = const Color(0xFFE65100);
                  badgeText = 'دفتري مدار ↺ (للتجليد المطبوع)';
                } else {
                  badgeBg = const Color(0xFFE0F2F1);
                  badgeFg = const Color(0xFF00796B);
                  badgeText = isWide ? 'عمودي A4 (منظومة مدمجة)' : 'عمودي قياسي';
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
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. عنوان الصفحة ورقمها والبادج
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pageTitle,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? AppTheme.textDark : AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeFg.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLocked) ...[
                                        Icon(Icons.lock_outline_rounded, size: 11, color: badgeFg),
                                        const SizedBox(width: 3),
                                      ],
                                      Text(
                                        badgeText,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: badgeFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // 2. خيارات التوجيه الآمنة بحسب تصنيف الصفحة
                      if (isLocked) ...[
                        // صفحات عمودية محمية
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.shield_outlined, size: 13, color: Color(0xFF388E3C)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'تم تثبيت هذه الصفحة بالوضع العمودي لضمان سلامة الجداول الكثيفة ومربعات التواقيع والختم من التلف أو التداخل.',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF2E7D32)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (isWide) ...[
                        // صفحات عريضة (8 و 9)
                        if (pageNum == 9) ...[
                          if (_canPage9BePortrait) ...[
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
                                      label: 'عمودي A4 ($_activeCombinerBoxesCount صناديق)',
                                      icon: Icons.stay_current_portrait_rounded,
                                      isSelected: mode == 'portrait',
                                      onTap: () => _updatePageMode(pageNum, 'portrait'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildToggleButton(
                                      label: 'أفقي للشاشات',
                                      icon: Icons.stay_current_landscape_rounded,
                                      isSelected: mode == 'landscape',
                                      onTap: () => _updatePageMode(pageNum, 'landscape'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildToggleButton(
                                      label: 'دفتري مدار ↺',
                                      icon: Icons.auto_stories_rounded,
                                      isSelected: mode == 'book',
                                      onTap: () => _updatePageMode(pageNum, 'book'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'متاح العرض العمودي لأن عدد الصناديق المفعلة ($_activeCombinerBoxesCount) مناسب للمقاس الرأسي دون تزاحم.',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
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
                                      label: 'أفقي للشاشات ($_activeCombinerBoxesCount صندوقاً)',
                                      icon: Icons.stay_current_landscape_rounded,
                                      isSelected: mode == 'landscape',
                                      onTap: () => _updatePageMode(pageNum, 'landscape'),
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildToggleButton(
                                      label: 'دفتري مدار ↺ (للطباعة)',
                                      icon: Icons.auto_stories_rounded,
                                      isSelected: mode == 'book',
                                      onTap: () => _updatePageMode(pageNum, 'book'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 12, color: Color(0xFFE65100)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'الوضع الأفقي إلزامي لوجود $_activeCombinerBoxesCount صندوق تجميع لضمان وضوح كامل القراءات والسلاسل.',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else ...[
                          // صفحة 8: تتيح العمودي A4 عند قلة البيانات بالإضافة للأفقي والدفتري
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
                                    label: 'عمودي A4 (بيانات قليلة)',
                                    icon: Icons.stay_current_portrait_rounded,
                                    isSelected: mode == 'portrait',
                                    onTap: () => _updatePageMode(pageNum, 'portrait'),
                                  ),
                                ),
                                Expanded(
                                  child: _buildToggleButton(
                                    label: 'أفقي للشاشات',
                                    icon: Icons.stay_current_landscape_rounded,
                                    isSelected: mode == 'landscape',
                                    onTap: () => _updatePageMode(pageNum, 'landscape'),
                                  ),
                                ),
                                Expanded(
                                  child: _buildToggleButton(
                                    label: 'دفتري مدار ↺',
                                    icon: Icons.auto_stories_rounded,
                                    isSelected: mode == 'book',
                                    onTap: () => _updatePageMode(pageNum, 'book'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        // صفحات مرنة (6 و 7 و 12 و 13)
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
                                  isSelected: mode == 'portrait',
                                  onTap: () => _updatePageMode(pageNum, 'portrait'),
                                ),
                              ),
                              Expanded(
                                child: _buildToggleButton(
                                  label: 'أفقي حقيقي',
                                  icon: Icons.stay_current_landscape_rounded,
                                  isSelected: mode == 'landscape',
                                  onTap: () => _updatePageMode(pageNum, 'landscape'),
                                ),
                              ),
                              Expanded(
                                child: _buildToggleButton(
                                  label: 'دفتري ↺',
                                  icon: Icons.auto_stories_rounded,
                                  isSelected: mode == 'book',
                                  onTap: () => _updatePageMode(pageNum, 'book'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.solarGold),
                    label: Text(
                      'حفظ وتطبيق التنسيق (${_documentPaperSize.toUpperCase()} • ${_pageLabels.length} صفحة)',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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

  Widget _buildDocumentSizeButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNavy : const Color(0xFFCBD5E1),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primaryNavy : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? AppTheme.primaryNavy : AppTheme.textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primaryNavy),
          ],
        ),
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
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
