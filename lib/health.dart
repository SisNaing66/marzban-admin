import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HealthSample {
  final int ts; // unix seconds
  final bool ok;
  final double cpu, mem; // percent
  final int online, users;
  HealthSample({required this.ts, required this.ok, this.cpu = 0, this.mem = 0, this.online = 0, this.users = 0});

  Map<String, dynamic> toJson() => {'t': ts, 'ok': ok, 'c': cpu, 'm': mem, 'o': online, 'u': users};
  factory HealthSample.fromJson(Map<String, dynamic> j) => HealthSample(
      ts: (j['t'] as num).toInt(), ok: j['ok'] == true, cpu: (j['c'] ?? 0).toDouble(), mem: (j['m'] ?? 0).toDouble(),
      online: (j['o'] ?? 0).toInt(), users: (j['u'] ?? 0).toInt());

  /// Builds a sample from the panel's /system response (null = server unreachable).
  factory HealthSample.fromSystem(Map<String, dynamic>? sys) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (sys == null) return HealthSample(ts: now, ok: false);
    final total = (sys['mem_total'] ?? 0) as num, used = (sys['mem_used'] ?? 0) as num;
    return HealthSample(
        ts: now, ok: true,
        cpu: ((sys['cpu_usage'] ?? 0) as num).toDouble(),
        mem: total == 0 ? 0 : used / total * 100,
        online: ((sys['online_users'] ?? 0) as num).toInt(),
        users: ((sys['total_user'] ?? 0) as num).toInt());
  }
}

class HealthStore {
  static const _max = 400; // ~4 days at one sample per 15 min
  static String _k(String id) => 'health_$id';

  static Future<List<HealthSample>> load(String serverId) async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final raw = p.getString(_k(serverId));
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => HealthSample.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> add(String serverId, HealthSample s) async {
    final l = await load(serverId);
    // ignore samples closer than 2 minutes to the previous one (dashboard refreshes + background task)
    if (l.isNotEmpty && s.ts - l.last.ts < 120) return;
    l.add(s);
    final keep = l.length > _max ? l.sublist(l.length - _max) : l;
    final p = await SharedPreferences.getInstance();
    await p.setString(_k(serverId), jsonEncode(keep.map((e) => e.toJson()).toList()));
  }
}
