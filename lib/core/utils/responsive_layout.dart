import 'package:flutter/material.dart';

/// Standard screen breakpoints for enterprise responsiveness
class ScreenBreakpoints {
  static const double mobileMax = 768;
  static const double tabletMax = 1100;
  static const double maxContentWidth = 1240;
}

class ResponsiveLayout {
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < ScreenBreakpoints.mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= ScreenBreakpoints.mobileMax && w < ScreenBreakpoints.tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ScreenBreakpoints.tabletMax;

  /// Returns value based on screen size
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}

/// A container that centers and limits content width on wide screens
class AdaptiveContentContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AdaptiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth = ScreenBreakpoints.maxContentWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
