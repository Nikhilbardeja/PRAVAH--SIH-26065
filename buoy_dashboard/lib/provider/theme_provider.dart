import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system; // falls back to system when unset

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('theme');
    if (s == 'light') mode = ThemeMode.light;
    if (s == 'dark') mode = ThemeMode.dark;
  }

  Future<void> setMode(ThemeMode m) async {
    mode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', m == ThemeMode.dark ? 'dark' : 'light');
  }

  bool isDark(BuildContext context) =>
      mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);
}
