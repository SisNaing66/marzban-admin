import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Storage {
  static const _k = 'servers';
  static Future<List<ServerConfig>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => ServerConfig.fromJson(e)).toList();
  }

  static Future<void> save(List<ServerConfig> l) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(l.map((e) => e.toJson()).toList()));
  }

  // Local backup of a server's users (used by Restore)
  static Future<void> saveBackup(String serverId, List<Map<String, dynamic>> users) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('backup_$serverId', jsonEncode({'time': DateTime.now().toIso8601String(), 'users': users}));
  }

  static Future<({DateTime time, List<Map<String, dynamic>> users})?> loadBackup(String serverId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('backup_$serverId');
    if (raw == null) return null;
    final j = jsonDecode(raw);
    return (
      time: DateTime.parse(j['time']),
      users: (j['users'] as List).map((e) => Map<String, dynamic>.from(e)).toList()
    );
  }
}
