import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../storage.dart';
import 'server_home_screen.dart';

class _Hit {
  final ServerConfig server;
  final VpnUser user;
  _Hit(this.server, this.user);
}

/// Searches the same username across every saved server.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final q = TextEditingController();
  List<_Hit>? hits;
  final failed = <String>[];
  bool busy = false;

  Future<void> _search() async {
    final text = q.text.trim();
    if (text.isEmpty) return;
    setState(() { busy = true; failed.clear(); });
    final servers = await Storage.load();
    final out = <_Hit>[];
    await Future.wait(servers.map((s) async {
      try {
        for (final u in await MarzbanApi(s).users(search: text)) { out.add(_Hit(s, u)); }
      } catch (e) {
        failed.add('${s.name}: ${MarzbanApi.errorText(e)}');
      }
    }));
    out.sort((a, b) => a.user.username.toLowerCase().compareTo(b.user.username.toLowerCase()));
    if (mounted) setState(() { hits = out; busy = false; });
  }

  Color _c(String s) => switch (s) { 'active' => Colors.green, 'expired' => Colors.red, 'limited' => Colors.orange, _ => Colors.grey };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: TextField(
          controller: q, autofocus: true, textInputAction: TextInputAction.search, onSubmitted: (_) => _search(),
          decoration: const InputDecoration(hintText: 'Server အားလုံးမှာ ရှာမယ်', border: InputBorder.none),
        ), actions: [IconButton(onPressed: _search, icon: const Icon(Icons.search))]),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : hits == null
                ? const Center(child: Text('Username ရိုက်ပြီး ရှာပါ'))
                : ListView(children: [
                    if (failed.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('မရတဲ့ server: ${failed.join(' | ')}', style: const TextStyle(color: Colors.red, fontSize: 12))),
                    if (hits!.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('ရှာလို့ မတွေ့ပါ'))),
                    for (final h in hits!) ListTile(
                      leading: CircleAvatar(backgroundColor: _c(h.user.status), child: Text(h.user.username.isEmpty ? '?' : h.user.username[0].toUpperCase())),
                      title: Text(h.user.username),
                      subtitle: Text('${h.server.name}  •  ${fmtBytes(h.user.usedTraffic)} / ${h.user.dataLimit == 0 ? '∞' : fmtBytes(h.user.dataLimit)}'
                          '  •  ${h.user.expireDate == null ? 'No expiry' : h.user.expireDate.toString().substring(0, 10)}'),
                      trailing: Text(h.user.status.toUpperCase(), style: TextStyle(color: _c(h.user.status), fontSize: 11)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServerHomeScreen(server: h.server, initialSearch: h.user.username))),
                    ),
                  ]),
      );
}
