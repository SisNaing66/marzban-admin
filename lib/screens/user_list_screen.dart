import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api.dart';
import '../models.dart';
import '../storage.dart';
import 'create_user_screen.dart';

class UserListScreen extends StatefulWidget {
  final MarzbanApi api;
  const UserListScreen({super.key, required this.api});
  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  static final Map<String, DateTime> _lastBackup = {};
  List<VpnUser> users = [];
  bool loading = true;
  String? err, status;
  final search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      users = await widget.api.users(search: search.text.trim(), status: status);
      // auto-backup the full list (never overwrite a backup with an empty list)
      // (at most once per 5 minutes so big lists don't get re-serialised on every refresh)
      final id = widget.api.server.id;
      final last = _lastBackup[id];
      if (search.text.trim().isEmpty && status == null && users.isNotEmpty &&
          (last == null || DateTime.now().difference(last).inMinutes >= 5)) {
        _lastBackup[id] = DateTime.now();
        Storage.saveBackup(id, users.map((u) => u.raw).toList());
      }
    } catch (e) {
      err = MarzbanApi.errorText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Color _statusColor(String s) => switch (s) {
        'active' => Colors.green,
        'expired' => Colors.red,
        'limited' => Colors.orange,
        'disabled' => Colors.grey,
        _ => Colors.blueGrey,
      };

  String _fullLink(VpnUser u) {
    final s = u.subscriptionUrl;
    return s.startsWith('/') ? '${widget.api.server.baseUrl}$s' : s;
  }

  Future<void> _delete(VpnUser u) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Delete User?'),
      content: Text('Are you sure you want to delete "${u.username}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ],
    ));
    if (ok != true) return;
    try { await widget.api.deleteUser(u.username); _load(); } catch (e) { _toast(MarzbanApi.errorText(e)); }
  }

  Future<void> _toggle(VpnUser u) async {
    try {
      await widget.api.updateUser(u.username, {'status': u.status == 'disabled' ? 'active' : 'disabled'});
      _load();
    } catch (e) { _toast(MarzbanApi.errorText(e)); }
  }

  void _show(VpnUser u) {
    final link = _fullLink(u);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (c) => SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(u.username, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (link.isNotEmpty) Container(
          color: Colors.white, padding: const EdgeInsets.all(8),
          child: QrImageView(data: link, size: 220)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          if (link.isNotEmpty) OutlinedButton.icon(
              icon: const Icon(Icons.copy), label: const Text('Subscription'),
              onPressed: () { Clipboard.setData(ClipboardData(text: link)); _toast('Link Copied'); }),
          for (var i = 0; i < u.links.length; i++) OutlinedButton.icon(
              icon: const Icon(Icons.link), label: Text('Config ${i + 1}'),
              onPressed: () { Clipboard.setData(ClipboardData(text: u.links[i])); _toast('Link Copied'); }),
        ]),
        const Divider(height: 24),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: () async { Navigator.pop(c); await widget.api.resetUsage(u.username); _load(); }, child: const Text('Reset usage')),
          TextButton(onPressed: () async { Navigator.pop(c); await widget.api.revokeSub(u.username); _load(); }, child: const Text('Revoke link')),
          TextButton(onPressed: () { Navigator.pop(c); _toggle(u); }, child: Text(u.status == 'disabled' ? 'Enable' : 'Disable')),
          TextButton(onPressed: () { Navigator.pop(c); _delete(u); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ]),
      ]))),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.person_add), label: const Text('Create VPN User'),
          onPressed: () async {
            final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CreateUserScreen(api: widget.api)));
            if (ok == true) _load();
          }),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Row(children: [
            Expanded(child: TextField(
              controller: search, onSubmitted: (_) => _load(),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search users', isDense: true, border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            DropdownButton<String?>(
              value: status, hint: const Text('All'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'expired', child: Text('Expired')),
                DropdownMenuItem(value: 'limited', child: Text('Limited')),
                DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
              ],
              onChanged: (v) { status = v; _load(); }),
          ])),
          Expanded(child: loading
              ? const Center(child: CircularProgressIndicator())
              : err != null
                  ? Center(child: Text(err!))
                  : RefreshIndicator(onRefresh: _load, child: users.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No users found'))])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: users.length,
                          itemBuilder: (_, i) {
                            final u = users[i];
                            final exp = u.expireDate;
                            final limit = u.dataLimit == 0 ? '∞' : fmtBytes(u.dataLimit);
                            return ListTile(
                              leading: CircleAvatar(backgroundColor: _statusColor(u.status), child: Text(u.username.isEmpty ? '?' : u.username[0].toUpperCase())),
                              title: Text(u.username),
                              subtitle: Text('${fmtBytes(u.usedTraffic)} / $limit  •  '
                                  '${exp == null ? 'No expiry' : 'Expires: ${exp.toString().substring(0, 10)}'}'),
                              trailing: Text(u.status.toUpperCase(), style: TextStyle(color: _statusColor(u.status), fontSize: 11)),
                              onTap: () => _show(u),
                            );
                          }))),
        ]),
      );
}
