import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../storage.dart';
import 'server_home_screen.dart';

class _Stat {
  final ServerConfig server;
  final Map<String, dynamic>? sys;
  final List<VpnUser>? users;
  final String? error;
  _Stat(this.server, {this.sys, this.users, this.error});
  bool get ok => error == null;
  int get expiring => users?.where((u) => u.expiringSoon).length ?? 0;
  int get near => users?.where((u) => u.nearLimit).length ?? 0;
  int get expired => users?.where((u) => u.status == 'expired').length ?? 0;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  List<_Stat> stats = [];
  bool loading = true;

  @override
  void initState() { super.initState(); refresh(); }

  Future<_Stat> _one(ServerConfig s) async {
    final api = MarzbanApi(s);
    try {
      final r = await Future.wait<dynamic>([api.system(), api.users()]).timeout(const Duration(seconds: 25));
      return _Stat(s, sys: r[0] as Map<String, dynamic>, users: r[1] as List<VpnUser>);
    } catch (e) {
      return _Stat(s, error: MarzbanApi.errorText(e));
    }
  }

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    final servers = await Storage.load();
    final res = await Future.wait(servers.map(_one)); // all servers in parallel
    if (mounted) setState(() { stats = res; loading = false; });
  }

  Widget _chip(IconData i, String t, {Color? c}) => Padding(
        padding: const EdgeInsets.only(right: 12, top: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 14, color: c), const SizedBox(width: 3), Text(t, style: TextStyle(fontSize: 12, color: c))]),
      );

  @override
  Widget build(BuildContext context) {
    final okList = stats.where((s) => s.ok).toList();
    int sum(int Function(_Stat) f) => okList.fold(0, (a, s) => a + f(s));
    final total = sum((s) => (s.sys?['total_user'] ?? 0) as int);
    final active = sum((s) => (s.sys?['users_active'] ?? 0) as int);
    final online = sum((s) => (s.sys?['online_users'] ?? 0) as int);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
      body: loading && stats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: refresh,
              child: stats.isEmpty
                  ? ListView(children: const [SizedBox(height: 160), Center(child: Text('Servers tab မှာ server အရင်ထည့်ပါ'))])
                  : ListView(padding: const EdgeInsets.all(12), children: [
                      Card(child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing: 24, runSpacing: 12, children: [
                        _big('Servers', '${okList.length}/${stats.length}', okList.length == stats.length ? Colors.green : Colors.orange),
                        _big('Users', '$total', null),
                        _big('Active', '$active', Colors.green),
                        _big('Online', '$online', Colors.blue),
                        _big('Expiring ≤3d', '${sum((s) => s.expiring)}', Colors.orange),
                        _big('Usage ≥90%', '${sum((s) => s.near)}', Colors.deepOrange),
                        _big('Expired', '${sum((s) => s.expired)}', Colors.red),
                      ]))),
                      if (loading) const LinearProgressIndicator(),
                      for (final s in stats) _serverCard(s),
                    ]),
            ),
    );
  }

  Widget _big(String k, String v, Color? c) => SizedBox(
        width: 92,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
          Text(k, style: const TextStyle(fontSize: 12)),
        ]),
      );

  Widget _serverCard(_Stat s) {
    final sys = s.sys ?? <String, dynamic>{};
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServerHomeScreen(server: s.server))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.circle, size: 12, color: s.ok ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(s.server.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
              Text(s.ok ? 'Online' : 'Offline', style: TextStyle(color: s.ok ? Colors.green : Colors.red, fontSize: 12)),
            ]),
            if (!s.ok) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
            if (s.ok) Wrap(children: [
              _chip(Icons.people, '${sys['total_user']} users'),
              _chip(Icons.check_circle, '${sys['users_active']} active', c: Colors.green),
              _chip(Icons.wifi, '${sys['online_users'] ?? '-'} online', c: Colors.blue),
              _chip(Icons.schedule, '${s.expiring} ≤3d', c: s.expiring > 0 ? Colors.orange : null),
              _chip(Icons.data_usage, '${s.near} ≥90%', c: s.near > 0 ? Colors.deepOrange : null),
              _chip(Icons.memory, 'CPU ${sys['cpu_usage']}%'),
              _chip(Icons.storage, 'RAM ${fmtBytes((sys['mem_used'] ?? 0) as num)} / ${fmtBytes((sys['mem_total'] ?? 0) as num)}'),
            ]),
          ]),
        ),
      ),
    );
  }
}
