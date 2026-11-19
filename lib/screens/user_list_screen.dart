import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api.dart';
import '../models.dart';
import '../share_util.dart';
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
  int special = 0; // 0 all, 1 expiring <=3d, 2 usage >=90%
  final search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      users = await widget.api.users(search: search.text.trim(), status: status);
      // auto-backup the full list at most once per 5 minutes (never overwrite with an empty list)
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

  /// Extend expiry (from the later of now / current expiry), add data, optionally reset usage, set active.
  Future<void> _renew(VpnUser u) async {
    final days = TextEditingController(text: '30');
    final gb = TextEditingController(text: '0');
    var reset = u.status == 'limited' || u.nearLimit;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text('Renew ${u.username}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: days, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ရက် ထပ်တိုး', helperText: 'No-expiry user ဆိုရင် မပြောင်းပါ')),
        TextField(controller: gb, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'GB ထပ်တိုး', helperText: 'Unlimited user ဆိုရင် မပြောင်းပါ')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: reset, title: const Text('Usage ကို 0 ပြန်ထား'),
            onChanged: (v) => set(() => reset = v ?? false)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Renew')),
      ],
    )));
    if (ok != true) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final d = int.tryParse(days.text.trim()) ?? 0;
    final addGb = double.tryParse(gb.text.trim()) ?? 0;
    final patch = <String, dynamic>{'status': 'active'};
    final cur = u.expire ?? 0;
    if (d > 0 && cur != 0) patch['expire'] = (cur > now ? cur : now) + d * 86400;
    if (addGb > 0 && u.dataLimit > 0) patch['data_limit'] = u.dataLimit + (addGb * 1073741824).round();
    try {
      if (reset) await widget.api.resetUsage(u.username);
      await widget.api.updateUser(u.username, patch);
      _toast('Renewed ${u.username}');
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
          if (link.isNotEmpty) FilledButton.icon(
              icon: const Icon(Icons.share), label: const Text('Share'),
              onPressed: () => shareMessage(u, link)),
          if (link.isNotEmpty) FilledButton.tonalIcon(
              icon: const Icon(Icons.qr_code), label: const Text('QR image'),
              onPressed: () async { try { await shareQrImage(u, link); } catch (e) { _toast('$e'); } }),
          if (link.isNotEmpty) FilledButton.tonalIcon(
              icon: const Icon(Icons.download), label: const Text('Save QR'),
              onPressed: () async { try { await saveQrToGallery(u, link); _toast('Saved to gallery'); } catch (e) { _toast('$e'); } }),
          FilledButton.tonalIcon(
              icon: const Icon(Icons.autorenew), label: const Text('Renew'),
              onPressed: () { Navigator.pop(c); _renew(u); }),
        ]),
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
  Widget build(BuildContext context) {
    final expiringN = users.where((u) => u.expiringSoon).length;
    final nearN = users.where((u) => u.nearLimit).length;
    final shown = special == 1 ? users.where((u) => u.expiringSoon).toList()
        : special == 2 ? users.where((u) => u.nearLimit).toList() : users;
    return Scaffold(
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
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final e in [
              (0, 'All (${users.length})'),
              (1, 'ကုန်ခါနီး ≤3 ရက် ($expiringN)'),
              (2, 'Data ≥90% ($nearN)'),
            ]) Padding(padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6), child: ChoiceChip(
              label: Text(e.$2), selected: special == e.$1, onSelected: (_) => setState(() => special = e.$1))),
          ])),
          Expanded(child: loading
              ? const Center(child: CircularProgressIndicator())
              : err != null
                  ? Center(child: Text(err!))
                  : RefreshIndicator(onRefresh: _load, child: shown.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No users found'))])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final u = shown[i];
                            final exp = u.expireDate;
                            final limit = u.dataLimit == 0 ? '∞' : fmtBytes(u.dataLimit);
                            return ListTile(
                              leading: CircleAvatar(backgroundColor: _statusColor(u.status), child: Text(u.username.isEmpty ? '?' : u.username[0].toUpperCase())),
                              title: Text(u.username),
                              subtitle: Text('${fmtBytes(u.usedTraffic)} / $limit  •  '
                                  '${exp == null ? 'No expiry' : 'Expires: ${exp.toString().substring(0, 10)}'}'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                if (u.expiringSoon || u.nearLimit) const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(u.status.toUpperCase(), style: TextStyle(color: _statusColor(u.status), fontSize: 11)),
                              ]),
                              onTap: () => _show(u),
                            );
                          }))),
        ]),
      );
  }
}
