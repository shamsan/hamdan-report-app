import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const BreadcrumbItem({
    required this.label,
    this.onTap,
    this.icon,
  });
}

/// شريط التنقل التسلسلي - يعرض مسار التنقل الحالي
/// مثال: العملاء > وزارة الصحة > مركز الكلى عبس
class BreadcrumbBar extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final Color? backgroundColor;
  final EdgeInsets padding;

  const BreadcrumbBar({
    super.key,
    required this.items,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primaryNavy.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryNavy.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _buildItems(),
        ),
      ),
    );
  }

  List<Widget> _buildItems() {
    final widgets = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      if (item.icon != null && i == 0) {
        widgets.add(
          Icon(
            item.icon,
            size: 14,
            color: isLast ? AppTheme.primaryNavy : AppTheme.textMuted,
          ),
        );
        widgets.add(const SizedBox(width: 4));
      }

      widgets.add(
        InkWell(
          onTap: isLast ? null : item.onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                color: isLast
                    ? AppTheme.primaryNavy
                    : AppTheme.textMuted,
                decoration: isLast ? null : TextDecoration.underline,
                decorationColor: AppTheme.textMuted.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      );

      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 16,
              color: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

/// بطاقة إرشادية للحالات الفارغة
/// تُوجّه المستخدم للخطوة التالية بدلاً من مجرد "لا توجد بيانات"
class EmptyStateGuide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyStateGuide({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppTheme.solarGold;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
