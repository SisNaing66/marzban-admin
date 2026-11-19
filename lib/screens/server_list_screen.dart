import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../storage.dart';
import 'server_home_screen.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});
  @override
  State<ServerListScreen> createState() => ServerListScreenState();
}

class ServerListScreenState extends State<ServerListScreen> {
  List<ServerConfig> servers = [];
  bool loading = true;

  @override
  void initState() { super.initState(); reload(); }

  Future<void> reload() async {
    servers = await Storage.load();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _edit([ServerConfig? s]) async {
    final name = TextEditingController(text: s?.name);
    final url = TextEditingController(text: s?.url ?? 'https://');
    final user = TextEditingController(text: s?.username);
    final pass = TextEditingController(text: s?.password);
    String? err;
    bool busy = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: Text(s == null ? 'Add Server' : 'Edit Server'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Server name')),
          TextField(controller: url, keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Panel URL', hintText: 'https://panel.example.com:8000')),
          TextField(controller: user, decoration: const InputDecoration(labelText: 'Admin username')),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Admin password')),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: busy ? null : () async {
              final c = ServerConfig(id: s?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name.text.trim(), url: url.text.trim(), username: user.text.trim(), password: pass.text);
              if (c.name.isEmpty || c.url.isEmpty || c.username.isEmpty) { set(() => err = 'Fill all fields'); return; }
              set(() { busy = true; err = null; });
              try {
                await MarzbanApi(c).testLogin();
                if (s == null) { servers.add(c); } else {
                  s..name = c.name..url = c.url..username = c.username..password = c.password;
                }
                await Storage.save(servers);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                set(() { busy = false; err = 'Login failed: ${MarzbanApi.errorText(e)}'; });
              }
            },
            child: Text(busy ? 'Checking...' : 'Save'),
          ),
        ],
      )),
    );
    if (saved == true) setState(() {});
  }

  Future<void> _delete(ServerConfig s) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Delete Server?'),
      content: Text('Remove "${s.name}" from this app? (The panel itself is not touched.)'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) { servers.remove(s); await Storage.save(servers); setState(() {}); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Servers')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add Server')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : servers.isEmpty
                ? const Center(child: Text('No servers found'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: servers.length,
                    itemBuilder: (_, i) {
                      final s = servers[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.dns),
                          title: Text(s.name),
                          subtitle: Text(s.url),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServerHomeScreen(server: s))),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => v == 'edit' ? _edit(s) : _delete(s),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'del', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    }),
      );
}
