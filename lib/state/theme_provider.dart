import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeMode = 'app_theme_mode';

/// Provider لإدارة وضع الثيم (الافتراضي الفاتح دائماً)
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _resetToLight();
    return ThemeMode.light;
  }

  Future<void> _resetToLight() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, 'light');
    state = ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = ThemeMode.light;
  }

  Future<void> toggle() async {
    state = ThemeMode.light;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
