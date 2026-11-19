import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';
import 'models.dart';
import 'sales.dart';
import 'screens/sync_actions.dart';
import 'settings.dart';
import 'storage.dart';

String _stamp() => DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

Future<void> _shareJson(String name, Object data) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
  await Share.shareXFiles([XFile(f.path, mimeType: 'application/json')]);
}

Future<Map<String, dynamic>?> _pickJson(BuildContext context) async {
  final f = await openFile();
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  final j = jsonDecode(utf8.decode(bytes));
  if (j is! Map) throw 'Backup ဖိုင် မမှန်ပါ';
  return Map<String, dynamic>.from(j);
}

void _toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// Users of one server -> JSON file (share sheet: save to Drive/Files/Telegram...).
Future<void> exportServerUsers(BuildContext context, MarzbanApi api) async {
  try {
    final users = (await api.users()).map((u) => u.raw).toList();
    await _shareJson('marzban-users-${_safe(api.server.name)}-${_stamp()}.json',
        {'type': 'marzban-users', 'version': 1, 'server': api.server.name, 'time': DateTime.now().toIso8601String(), 'users': users});
  } catch (e) {
    if (context.mounted) _toast(context, 'Export failed: ${MarzbanApi.errorText(e)}');
  }
}

Future<void> importServerUsers(BuildContext context, MarzbanApi api) async {
  try {
    final j = await _pickJson(context);
    if (j == null || !context.mounted) return;
    if (j['type'] != 'marzban-users') throw 'ဒါ users backup ဖိုင် မဟုတ်ပါ';
    final users = (j['users'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    await restoreUsersFromList(context, api, users, 'file from ${j['server'] ?? '?'}');
  } catch (e) {
    if (context.mounted) _toast(context, '$e');
  }
}

/// Servers (with admin passwords!), message template, presets and sales log -> JSON file.
Future<void> exportAppData(BuildContext context) async {
  try {
    final sales = await SalesStore.load();
    await _shareJson('marzban-admin-data-${_stamp()}.json', {
      'type': 'marzban-app', 'version': 1, 'time': DateTime.now().toIso8601String(),
      'servers': (await Storage.load()).map((s) => s.toJson()).toList(),
      'template': AppSettings.template,
      'presets': AppSettings.presets,
      'sales': sales.map((s) => s.toJson()).toList(),
    });
  } catch (e) {
    if (context.mounted) _toast(context, 'Export failed: $e');
  }
}

/// Merges a file made by [exportAppData]. Returns true if something was imported.
Future<bool> importAppData(BuildContext context) async {
  try {
    final j = await _pickJson(context);
    if (j == null) return false;
    if (j['type'] != 'marzban-app') throw 'ဒါ app data ဖိုင် မဟုတ်ပါ';
    final servers = await Storage.load();
    var added = 0;
    for (final e in (j['servers'] as List? ?? [])) {
      final s = ServerConfig.fromJson(Map<String, dynamic>.from(e));
      if (!servers.any((x) => x.id == s.id)) { servers.add(s); added++; }
    }
    await Storage.save(servers);
    if (j['template'] is String) await AppSettings.setTemplate(j['template']);
    if (j['presets'] is List) {
      AppSettings.presets = (j['presets'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      await AppSettings.savePresets();
    }
    final old = await SalesStore.load();
    final key = (Sale s) => '${s.ts}|${s.user}|${s.server}|${s.kind}';
    final have = old.map(key).toSet();
    final more = (j['sales'] as List? ?? []).map((e) => Sale.fromJson(Map<String, dynamic>.from(e))).where((s) => !have.contains(key(s))).toList();
    await SalesStore.replaceAll([...old, ...more]..sort((a, b) => a.ts.compareTo(b.ts)));
    if (context.mounted) _toast(context, 'Imported: $added server အသစ်, ${more.length} sales');
    return true;
  } catch (e) {
    if (context.mounted) _toast(context, '$e');
    return false;
  }
}
