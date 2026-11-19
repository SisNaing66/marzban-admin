import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultTemplate = 'မင်္ဂလာပါ {name}\n\nUsername: {username}\nData: {gb}\nသက်တမ်း: {expire} ({days} ရက်)\n\nLink:\n{link}';

class AppSettings {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static String template = defaultTemplate;
  static String? pinHash;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode.value = ThemeMode.values[(p.getInt('theme') ?? 0).clamp(0, 2)];
    template = p.getString('template') ?? defaultTemplate;
    pinHash = p.getString('pin');
  }

  static Future<void> setTheme(ThemeMode m) async {
    themeMode.value = m;
    (await SharedPreferences.getInstance()).setInt('theme', m.index);
  }

  static Future<void> setTemplate(String t) async {
    template = t;
    (await SharedPreferences.getInstance()).setString('template', t);
  }

  static String _hash(String pin) => sha256.convert(utf8.encode('mzb:$pin')).toString();

  static Future<void> setPin(String? pin) async {
    final p = await SharedPreferences.getInstance();
    if (pin == null) { pinHash = null; await p.remove('pin'); }
    else { pinHash = _hash(pin); await p.setString('pin', pinHash!); }
  }

  static bool checkPin(String pin) => pinHash != null && _hash(pin) == pinHash;
}
