import 'package:flutter/material.dart';

class AppTheme {
  // Executive Institutional Colors
  static const Color primaryNavy = Color(0xFF0B3A60);     // Institutional Deep Navy
  static const Color secondaryNavy = Color(0xFF06223A);   // Midnight Dark Navy
  static const Color brandCyan = Color(0xFF009FE3);       // Official UNOPS / Clean Energy Cyan
  static const Color solarGold = Color(0xFFEAA023);       // Official Reference Gold Accent
  static const Color surfaceLight = Color(0xFFF8FAFC);    // Ultra-clean enterprise background
  static const Color bgSurface = Color(0xFFF8FAFC);       // Surface alias
  static const Color cardLight = Colors.white;
  static const Color textDark = Color(0xFF0F172A);        // Rich Slate 900
  static const Color textSecondary = Color(0xFF334155);   // Slate 700
  static const Color textMuted = Color(0xFF64748B);       // Slate 500
  static const Color borderSubtle = Color(0xFFE2E8F0);    // Clean border
  static const Color borderMedium = Color(0xFFCBD5E1);    // Mid-level border
  static const Color borderFocus = Color(0xFF009FE3);     // Accent border

  // Status Indicators
  static const Color statusGood = Color(0xFF10B981);       // Emerald 600
  static const Color statusAcceptable = Color(0xFF0288D1); // Light Blue 700
  static const Color statusFollowup = Color(0xFFF59E0B);   // Amber 500
  static const Color statusRejected = Color(0xFFEF4444);   // Rose / Red 500
  static const Color statusNA = Color(0xFF64748B);         // Slate 500
  static const Color statusApproved = Color(0xFF10B981);   // Alias for approved (Emerald)
  static const Color statusPending = Color(0xFFF59E0B);    // Alias for pending (Amber)

  // Status Light Backgrounds for Pills & Badges
  static const Color statusGoodBg = Color(0xFFECFDF5);
  static const Color statusAcceptableBg = Color(0xFFE0F2FE);
  static const Color statusFollowupBg = Color(0xFFFFFBEB);
  static const Color statusRejectedBg = Color(0xFFFEF2F2);
  static const Color statusNABg = Color(0xFFF1F5F9);

  // Executive Gradients
  static const LinearGradient executiveNavyGradient = LinearGradient(
    colors: [Color(0xFF0B3A60), Color(0xFF06223A)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient solarGoldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient energyCyanGradient = LinearGradient(
    colors: [Color(0xFF009FE3), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soft Ambient Card Shadow for Android
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get cardHoverShadow => [
    BoxShadow(
      color: const Color(0xFF0B3A60).withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // Modern Enterprise Typography & Theme
  static ThemeData lightTheme({Color? primaryColor, Color? secondaryColor}) {
    final primary = primaryColor ?? primaryNavy;
    final secondary = secondaryColor ?? brandCyan;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: solarGold,
        surface: surfaceLight,
        error: statusRejected,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        outlineVariant: borderSubtle,
      ),
      scaffoldBackgroundColor: surfaceLight,
      fontFamily: 'Almarai',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Almarai', fontSize: 24, fontWeight: FontWeight.w800, color: textDark, height: 1.3),
        titleLarge: TextStyle(fontFamily: 'Almarai', fontSize: 18, fontWeight: FontWeight.w800, color: textDark, height: 1.3),
        titleMedium: TextStyle(fontFamily: 'Almarai', fontSize: 15, fontWeight: FontWeight.w700, color: textDark, height: 1.3),
        titleSmall: TextStyle(fontFamily: 'Almarai', fontSize: 13, fontWeight: FontWeight.w700, color: textDark),
        bodyLarge: TextStyle(fontFamily: 'Almarai', fontSize: 14, fontWeight: FontWeight.w500, color: textDark, height: 1.5),
        bodyMedium: TextStyle(fontFamily: 'Almarai', fontSize: 13, fontWeight: FontWeight.normal, color: textSecondary, height: 1.4),
        bodySmall: TextStyle(fontFamily: 'Almarai', fontSize: 11, fontWeight: FontWeight.normal, color: textMuted, height: 1.3),
        labelLarge: TextStyle(fontFamily: 'Almarai', fontSize: 13, fontWeight: FontWeight.w700, color: textDark),
        labelMedium: TextStyle(fontFamily: 'Almarai', fontSize: 11.5, fontWeight: FontWeight.w600, color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black26,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Almarai',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Almarai',
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.35), width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Almarai',
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondary, width: 1.8),
        ),
        labelStyle: const TextStyle(fontFamily: 'Almarai', color: textMuted, fontSize: 13),
        hintStyle: TextStyle(fontFamily: 'Almarai', color: textMuted.withValues(alpha: 0.7), fontSize: 12.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        height: 65,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontFamily: 'Almarai', fontSize: 11.5, fontWeight: FontWeight.w800, color: primary);
          }
          return const TextStyle(fontFamily: 'Almarai', fontSize: 11, fontWeight: FontWeight.w500, color: textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary, size: 23);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: borderSubtle),
        labelStyle: const TextStyle(fontFamily: 'Almarai', fontSize: 12, color: textDark),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: solarGold,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: secondaryNavy,
        selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
        unselectedIconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.6), size: 22),
        selectedLabelTextStyle: const TextStyle(fontFamily: 'Almarai', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(fontFamily: 'Almarai', color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
        indicatorColor: brandCyan,
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 20,
      ),
    );
  }

  static ThemeData darkTheme({Color? primaryColor, Color? secondaryColor}) {
    const darkSurface    = Color(0xFF1E293B);
    const darkBackground = Color(0xFF0F172A);
    const darkCard       = Color(0xFF1E293B);
    const darkBorder     = Color(0xFF334155);
    const darkTextPrimary   = Color(0xFFF1F5F9);
    const darkTextSecondary = Color(0xFF94A3B8);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary:   brandCyan,
        secondary: solarGold,
        tertiary:  statusGood,
        surface:   darkSurface,
        error:     statusRejected,
        onPrimary:   Colors.white,
        onSecondary: Colors.white,
        onSurface:   darkTextPrimary,
        surfaceContainerHighest: const Color(0xFF0F172A),
        outlineVariant: darkBorder,
      ),
      scaffoldBackgroundColor: darkBackground,
      fontFamily: 'Almarai',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Almarai', fontSize: 24, fontWeight: FontWeight.w800, color: darkTextPrimary, height: 1.3),
        titleLarge:   TextStyle(fontFamily: 'Almarai', fontSize: 18, fontWeight: FontWeight.w800, color: darkTextPrimary, height: 1.3),
        titleMedium:  TextStyle(fontFamily: 'Almarai', fontSize: 15, fontWeight: FontWeight.w700, color: darkTextPrimary, height: 1.3),
        titleSmall:   TextStyle(fontFamily: 'Almarai', fontSize: 13, fontWeight: FontWeight.w700, color: darkTextPrimary),
        bodyLarge:    TextStyle(fontFamily: 'Almarai', fontSize: 14, fontWeight: FontWeight.w500, color: darkTextPrimary, height: 1.5),
        bodyMedium:   TextStyle(fontFamily: 'Almarai', fontSize: 13, fontWeight: FontWeight.normal, color: darkTextSecondary, height: 1.4),
        bodySmall:    TextStyle(fontFamily: 'Almarai', fontSize: 11, fontWeight: FontWeight.normal, color: darkTextSecondary, height: 1.3),
        labelLarge:   TextStyle(fontFamily: 'Almarai', fontSize: 13, fontWeight: FontWeight.w700, color: darkTextPrimary),
        labelMedium:  TextStyle(fontFamily: 'Almarai', fontSize: 11.5, fontWeight: FontWeight.w600, color: darkTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black54,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Almarai',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: darkTextPrimary,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandCyan,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        border:         OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: darkBorder)),
        enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: darkBorder)),
        focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brandCyan, width: 1.8)),
        labelStyle: const TextStyle(fontFamily: 'Almarai', color: darkTextSecondary, fontSize: 13),
        hintStyle:  TextStyle(fontFamily: 'Almarai', color: darkTextSecondary.withValues(alpha: 0.6), fontSize: 12.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 3,
        height: 65,
        indicatorColor: brandCyan.withValues(alpha: 0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontFamily: 'Almarai', fontSize: 11.5, fontWeight: FontWeight.w800, color: brandCyan);
          }
          return const TextStyle(fontFamily: 'Almarai', fontSize: 11, fontWeight: FontWeight.w500, color: darkTextSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: brandCyan, size: 23);
          }
          return const IconThemeData(color: darkTextSecondary, size: 22);
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF06223A),
        selectedIconTheme:   IconThemeData(color: Colors.white, size: 24),
        unselectedIconTheme: IconThemeData(color: Colors.white54, size: 22),
        selectedLabelTextStyle:   TextStyle(fontFamily: 'Almarai', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelTextStyle: TextStyle(fontFamily: 'Almarai', color: Colors.white54, fontSize: 11),
        indicatorColor: brandCyan,
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1, space: 20),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: darkBorder),
        labelStyle: const TextStyle(fontFamily: 'Almarai', fontSize: 12, color: darkTextPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: solarGold,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
