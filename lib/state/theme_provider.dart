import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeMode = 'app_theme_mode';

/// Provider لإدارة وضع الثيم (فاتح / داكن / تلقائي)
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadThemeMode();
    return ThemeMode.light; // القيمة الأولية حتى يتم التحميل
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeMode);
    state = switch (stored) {
      'dark'   => ThemeMode.dark,
      'light'  => ThemeMode.light,
      'system' => ThemeMode.system,
      _        => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, switch (mode) {
      ThemeMode.dark   => 'dark',
      ThemeMode.light  => 'light',
      ThemeMode.system => 'system',
    });
  }

  Future<void> toggle() async {
    await setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
