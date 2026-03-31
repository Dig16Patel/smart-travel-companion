import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_guide_app/data/theme_service.dart';

void main() {
  test('Theme Service Toggle Test', () async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({'is_dark_mode': true});
    
    final themeService = ThemeService();
    
    // Initial state should be dark (from mock)
    expect(themeService.isDarkMode, true);
    expect(themeService.themeMode, ThemeMode.dark);
    
    // Toggle to light
    await themeService.toggleTheme();
    expect(themeService.isDarkMode, false);
    expect(themeService.themeMode, ThemeMode.light);
    
    // Toggle back to dark
    await themeService.toggleTheme();
    expect(themeService.isDarkMode, true);
    expect(themeService.themeMode, ThemeMode.dark);
  });
}
