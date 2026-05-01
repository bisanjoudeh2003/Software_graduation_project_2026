import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {

  static const String themeKey = "dark_mode";

  bool _darkMode = false;

  bool get darkMode => _darkMode;

  ThemeService(){
    loadTheme();
  }

  /// حفظ الثيم
  static Future<void> setTheme(bool value) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(themeKey, value);

  }

  /// قراءة الثيم
  static Future<bool> getTheme() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(themeKey) ?? false;

  }

  /// تغيير الثيم
  Future<void> toggleTheme(bool value) async {

    _darkMode = value;

    await setTheme(value);

    notifyListeners();

  }

  /// تحميل الثيم عند تشغيل التطبيق
  Future<void> loadTheme() async {

    _darkMode = await getTheme();

    notifyListeners();

  }

}