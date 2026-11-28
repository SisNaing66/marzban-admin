import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultRemind = 'မင်္ဂလာပါ {name}\n\nသင့် VPN ({username}) သက်တမ်း {expire} မှာ ကုန်ပါတော့မယ် ({days} ရက်ပဲ ကျန်ပါတော့တယ်)။\nဆက်သုံးချင်ရင် Renew လုပ်ပေးပါနော်။';

const defaultTemplate = 'မင်္ဂလာပါ {name}\n\nUsername: {username}\nData: {gb}\nသက်တမ်း: {expire} ({days} ရက်)\n\nLink:\n{link}';

class AppSettings {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final lang = ValueNotifier<String>('my'); // my | en
  static String template = defaultTemplate;
  static String? pinHash;
  static bool alertsOn = false;
  static String tgToken = '', tgChat = '';
  static bool tgAlerts = false, tgBackup = false;
  static String remindTemplate = defaultRemind;
  static Map<String, String> contacts = {}; // "serverId|username" -> phone / @telegram (kept on this phone only)
  static bool biometric = false;
  static String hubUrl = 'https://hub.tulipvip69.com', hubUser = '', hubPass = '', hubFront = 'https://vip.lovetulip69.com';
  static List<Map<String, dynamic>> presets = []; // {name, days, gb, price}

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode.value = ThemeMode.values[(p.getInt('theme') ?? 0).clamp(0, 2)];
    lang.value = p.getString('lang') ?? 'my';
    template = p.getString('template') ?? defaultTemplate;
    pinHash = p.getString('pin');
    alertsOn = p.getBool('alerts') ?? false;
    tgToken = p.getString('tg_token') ?? '';
    tgChat = p.getString('tg_chat') ?? '';
    tgAlerts = p.getBool('tg_alerts') ?? false;
    tgBackup = p.getBool('tg_backup') ?? false;
    remindTemplate = p.getString('remind') ?? defaultRemind;
    final ct = p.getString('contacts');
    if (ct != null) contacts = Map<String, String>.from(jsonDecode(ct));
    biometric = p.getBool('bio') ?? false;
    hubUrl = p.getString('hub_url') ?? hubUrl;
    hubUser = p.getString('hub_user') ?? '';
    hubPass = p.getString('hub_pass') ?? '';
    hubFront = p.getString('hub_front') ?? hubFront;
    final pr = p.getString('presets');
    if (pr != null) presets = (jsonDecode(pr) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> setTheme(ThemeMode m) async {
    themeMode.value = m;
    (await SharedPreferences.getInstance()).setInt('theme', m.index);
  }

  static Future<void> setLang(String v) async {
    lang.value = v;
    (await SharedPreferences.getInstance()).setString('lang', v);
  }

  static Future<void> saveHub({required String url, required String user, required String pass, required String front}) async {
    hubUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    hubUser = user.trim(); hubPass = pass; hubFront = front.trim().replaceAll(RegExp(r'/+$'), '');
    final p = await SharedPreferences.getInstance();
    await p.setString('hub_url', hubUrl);
    await p.setString('hub_user', hubUser);
    await p.setString('hub_pass', hubPass);
    await p.setString('hub_front', hubFront);
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

  static Future<void> saveTelegram({required String token, required String chat, required bool alerts, required bool backup}) async {
    tgToken = token.trim(); tgChat = chat.trim(); tgAlerts = alerts; tgBackup = backup;
    final p = await SharedPreferences.getInstance();
    await p.setString('tg_token', tgToken);
    await p.setString('tg_chat', tgChat);
    await p.setBool('tg_alerts', alerts);
    await p.setBool('tg_backup', backup);
  }

  static bool get tgReady => tgToken.isNotEmpty && tgChat.isNotEmpty;

  static Future<void> setRemindTemplate(String t) async {
    remindTemplate = t;
    (await SharedPreferences.getInstance()).setString('remind', t);
  }

  static String contactKey(String serverId, String user) => '$serverId|$user';

  static Future<void> setContact(String serverId, String user, String v) async {
    final k = contactKey(serverId, user);
    if (v.trim().isEmpty) { contacts.remove(k); } else { contacts[k] = v.trim(); }
    (await SharedPreferences.getInstance()).setString('contacts', jsonEncode(contacts));
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
