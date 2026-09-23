import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// زر تفاعلي مخصص يمنع النقر المزدوج (Double-Tap Prevention)
/// ويعرض مؤشر تحميل تلقائي أثناء تنفيذ العمليات غير المتزامنة (Async Operations)
class DebouncedButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final Widget child;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final BorderRadius? borderRadius;
  final bool enableHaptic;
  final String? tooltip;

  const DebouncedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.elevation,
    this.borderRadius,
    this.enableHaptic = true,
    this.tooltip,
  });

  @override
  State<DebouncedButton> createState() => _DebouncedButtonState();
}

class _DebouncedButtonState extends State<DebouncedButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading || widget.onPressed == null) return;

    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }

    setState(() => _isLoading = true);

    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
    );

    final style = ElevatedButton.styleFrom(
      backgroundColor: widget.backgroundColor ?? AppTheme.primaryNavy,
      foregroundColor: widget.foregroundColor ?? Colors.white,
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      elevation: widget.elevation ?? 1,
      shape: shape,
    );

    Widget content;
    if (_isLoading) {
      content = SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.foregroundColor ?? Colors.white,
          ),
        ),
      );
    } else if (widget.icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.icon!,
          const SizedBox(width: 8),
          widget.child,
        ],
      );
    } else {
      content = widget.child;
    }

    Widget button = ElevatedButton(
      style: style,
      onPressed: widget.onPressed == null ? null : (_isLoading ? null : _handlePress),
      child: content,
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
