import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import 'user_list_screen.dart';
import 'core_settings_screen.dart';
import 'sync_actions.dart';

class ServerHomeScreen extends StatefulWidget {
  final ServerConfig server;
  const ServerHomeScreen({super.key, required this.server});
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
      () => UserListScreen(api: api),
      () => StatsTab(api: api),
      () => CoreSettingsScreen(api: api),
    ];
    final pages = [
      for (var i = 0; i < builders.length; i++) visited.contains(i) ? builders[i]() : const SizedBox.shrink(),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.server.name), actions: [
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'merge') mergeUsers(context, api);
            if (v == 'backup') backupNow(context, api);
            if (v == 'restore') restoreUsers(context, api);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'merge', child: Text('Merge Users (from another server)')),
            PopupMenuItem(value: 'backup', child: Text('Backup users now')),
            PopupMenuItem(value: 'restore', child: Text('Restore Users from backup')),
          ],
        ),
      ]),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() { tab = i; visited.add(i); }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.speed), label: 'Stats'),
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
  String? err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await widget.api.system();
      if (mounted) setState(() { s = r; err = null; });
    } catch (e) {
      if (mounted) setState(() => err = 'Failed to load server stats: ${MarzbanApi.errorText(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (err != null) return Center(child: Text(err!));
    if (s == null) return const Center(child: CircularProgressIndicator());
    final memT = (s!['mem_total'] ?? 0) as num, memU = (s!['mem_used'] ?? 0) as num;
    Widget tile(String k, String v, IconData i) => Card(child: ListTile(leading: Icon(i), title: Text(k), trailing: Text(v)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        tile('Version', '${s!['version']}', Icons.info),
        tile('CPU', '${s!['cpu_usage']}%  (${s!['cpu_cores']} cores)', Icons.memory),
        tile('RAM', '${fmtBytes(memU)} / ${fmtBytes(memT)}', Icons.storage),
        tile('Total users', '${s!['total_user']}', Icons.people),
        tile('Online users', '${s!['online_users'] ?? '-'}', Icons.wifi),
        tile('Active users', '${s!['users_active']}', Icons.check_circle),
        tile('Incoming', fmtBytes(s!['incoming_bandwidth'] ?? 0), Icons.download),
        tile('Outgoing', fmtBytes(s!['outgoing_bandwidth'] ?? 0), Icons.upload),
      ]),
    );
  }
}
