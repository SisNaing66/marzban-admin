import '../i18n.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import 'user_list_screen.dart';
import 'core_settings_screen.dart';
import 'hosts_screen.dart';
import 'sync_actions.dart';
import 'report_screen.dart';
import 'health_screen.dart';
import 'maintenance.dart';
import '../backup_io.dart';

class ServerHomeScreen extends StatefulWidget {
  final ServerConfig server;
  final String? initialSearch;
  const ServerHomeScreen({super.key, required this.server, this.initialSearch});
  @override
  State<ServerHomeScreen> createState() => _ServerHomeScreenState();
}

class _ServerHomeScreenState extends State<ServerHomeScreen> {
  late final MarzbanApi api = MarzbanApi(widget.server);
  int tab = 0;
  final visited = <int>{0}; // tabs load lazily, only once opened

  @override
  Widget build(BuildContext context) {
    final builders = <Widget Function()>[
      () => UserListScreen(api: api, initialSearch: widget.initialSearch),
      () => StatsTab(api: api),
      () => HostsScreen(api: api),
      () => CoreSettingsScreen(api: api),
    ];
    final pages = [
      for (var i = 0; i < builders.length; i++) visited.contains(i) ? builders[i]() : SizedBox.shrink(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.server.name), actions: [
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'merge') mergeUsers(context, api);
            if (v == 'backup') backupNow(context, api);
            if (v == 'restore') restoreUsers(context, api);
            if (v == 'report') Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(api: api)));
            if (v == 'clean') cleanExpired(context, api);
            if (v == 'health') Navigator.push(context, MaterialPageRoute(builder: (_) => HealthScreen(server: widget.server)));
            if (v == 'export') exportServerUsers(context, api);
            if (v == 'import') importServerUsers(context, api);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'merge', child: Text(t('Merge Users (from another server)'))),
            PopupMenuItem(value: 'backup', child: Text(t('Backup users now'))),
            PopupMenuItem(value: 'restore', child: Text(t('Restore Users from backup'))),
            PopupMenuItem(value: 'export', child: Text(t('Export users file (.json)'))),
            PopupMenuItem(value: 'import', child: Text(t('Import users file (.json)'))),
            PopupMenuItem(value: 'report', child: Text(t('Usage report'))),
            PopupMenuItem(value: 'health', child: Text(t('Health history'))),
            PopupMenuItem(value: 'clean', child: Text(t('Clean expired users'))),
          ],
        ),
      ]),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() { tab = i; visited.add(i); }),
        destinations: [
          NavigationDestination(icon: Icon(Icons.people), label: t('Users')),
          NavigationDestination(icon: Icon(Icons.speed), label: t('Stats')),
          NavigationDestination(icon: Icon(Icons.public), label: t('Hosts')),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Core'),
        ],
      ),
    );
  }
}

class StatsTab extends StatefulWidget {
  final MarzbanApi api;
  const StatsTab({super.key, required this.api});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  Map<String, dynamic>? s;
  int? usersUsage;
  String? err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await widget.api.system();
      if (mounted) setState(() { s = r; err = null; });
      try {
        final us = await widget.api.users();
        final sum = us.fold<int>(0, (a, u) => a + u.usedTraffic);
        if (mounted) setState(() => usersUsage = sum);
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => err = 'Failed to load server stats: ${MarzbanApi.errorText(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (err != null) return Center(child: Text(err!));
    if (s == null) return Center(child: CircularProgressIndicator());
    final memT = (s!['mem_total'] ?? 0) as num, memU = (s!['mem_used'] ?? 0) as num;
    Widget tile(String k, String v, IconData i) => Card(child: ListTile(leading: Icon(i), title: Text(t(k)), trailing: Text(v)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.all(12), children: [
        tile('Version', '${s!['version']}', Icons.info),
        tile('CPU', '${s!['cpu_usage']}%  (${s!['cpu_cores']} cores)', Icons.memory),
        tile('RAM', '${fmtBytes(memU)} / ${fmtBytes(memT)}', Icons.storage),
        tile('Total users', '${s!['total_user']}', Icons.people),
        tile('Online users', '${s!['online_users'] ?? '-'}', Icons.wifi),
        tile('Active users', '${s!['users_active']}', Icons.check_circle),
        tile('Incoming', fmtBytes(s!['incoming_bandwidth'] ?? 0), Icons.download),
        tile('Outgoing', fmtBytes(s!['outgoing_bandwidth'] ?? 0), Icons.upload),
        tile('Total traffic', fmtBytes(((s!['incoming_bandwidth'] ?? 0) as num) + ((s!['outgoing_bandwidth'] ?? 0) as num)), Icons.swap_vert),
        tile('Users usage', usersUsage == null ? '...' : fmtBytes(usersUsage!), Icons.data_usage),
      ]),
    );
  }
}
