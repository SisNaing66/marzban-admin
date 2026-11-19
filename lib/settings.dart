import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultTemplate = 'မင်္ဂလာပါ {name}\n\nUsername: {username}\nData: {gb}\nသက်တမ်း: {expire} ({days} ရက်)\n\nLink:\n{link}';

class AppSettings {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static String template = defaultTemplate;
  static String? pinHash;
  static bool alertsOn = false;
  static bool biometric = false;
  static List<Map<String, dynamic>> presets = []; // {name, days, gb, price}

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode.value = ThemeMode.values[(p.getInt('theme') ?? 0).clamp(0, 2)];
    template = p.getString('template') ?? defaultTemplate;
    pinHash = p.getString('pin');
    alertsOn = p.getBool('alerts') ?? false;
    biometric = p.getBool('bio') ?? false;
    final pr = p.getString('presets');
    if (pr != null) presets = (jsonDecode(pr) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> setTheme(ThemeMode m) async {
    themeMode.value = m;
    (await SharedPreferences.getInstance()).setInt('theme', m.index);
  }

  static Future<void> setTemplate(String t) async {
    template = t;
    (await SharedPreferences.getInstance()).setString('template', t);
  }

  static Future<void> savePresets() async =>
      (await SharedPreferences.getInstance()).setString('presets', jsonEncode(presets));

  static Future<void> setAlerts(bool v) async {
    alertsOn = v;
    (await SharedPreferences.getInstance()).setBool('alerts', v);
  }

  static Future<void> setBiometric(bool v) async {
    biometric = v;
    (await SharedPreferences.getInstance()).setBool('bio', v);
  }

  static String _hash(String pin) => sha256.convert(utf8.encode('mzb:$pin')).toString();

  static Future<void> setPin(String? pin) async {
    final p = await SharedPreferences.getInstance();
    if (pin == null) { pinHash = null; biometric = false; await p.remove('pin'); await p.setBool('bio', false); }
    else { pinHash = _hash(pin); await p.setString('pin', pinHash!); }
  }

  static bool checkPin(String pin) => pinHash != null && _hash(pin) == pinHash;
}
