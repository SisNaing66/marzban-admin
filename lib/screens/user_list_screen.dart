import '../i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api.dart';
import '../bulk.dart';
import '../models.dart';
import '../sales.dart';
import '../settings.dart';
import '../share_util.dart';
import '../storage.dart';
import 'create_user_screen.dart';
import 'edit_user_screen.dart';
import 'remind_screen.dart';
import 'sync_actions.dart';

class UserListScreen extends StatefulWidget {
  final MarzbanApi api;
  final String? initialSearch;
  const UserListScreen({super.key, required this.api, this.initialSearch});
  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  static final Map<String, DateTime> _lastBackup = {};
  List<VpnUser> users = [];
  bool loading = true;
  String? err, status;
  int special = 0; // 0 all, 1 expiring <=3d, 2 usage >=90%
  String sort = 'name'; // name | usage | expiry
  final selected = <String>{};
  final search = TextEditingController();

  bool get selecting => selected.isNotEmpty;

  @override
  void initState() { super.initState(); search.text = widget.initialSearch ?? ''; _load(); }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      users = await widget.api.users(search: search.text.trim(), status: status);
      selected.removeWhere((n) => !users.any((u) => u.username == n));
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

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: Text(title), content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
        ],
      )) == true;

  Future<void> _finishBulk(String title, BulkResult r) async {
    if (!mounted) return;
    setState(selected.clear);
    await showBulkResult(context, title, r);
    _load();
  }

  Future<void> _deleteMany(List<VpnUser> list) async {
    if (list.isEmpty) return;
    final label = list.length == 1 ? '"${list.first.username}"' : '${list.length} users';
    if (!await _confirm('Delete User?', 'Are you sure you want to delete $label?', 'Delete')) return;
    final r = await runBulk<VpnUser>(context, 'Deleting', list, (u) => u.username, (u) => widget.api.deleteUser(u.username));
    await _finishBulk('Delete result', r);
  }

  Future<void> _setEnabled(List<VpnUser> list, bool enable) async {
    if (list.isEmpty) return;
    final r = await runBulk<VpnUser>(context, enable ? 'Enabling' : 'Disabling', list, (u) => u.username,
        (u) => widget.api.updateUser(u.username, {'status': enable ? 'active' : 'disabled'}));
    await _finishBulk(enable ? 'Enable result' : 'Disable result', r);
  }

  /// Extend expiry / add data / reset usage for one or many users, optionally logging a sale.
  Future<void> _renewMany(List<VpnUser> list) async {
    if (list.isEmpty) return;
    final days = TextEditingController(text: '30');
    final gb = TextEditingController(text: '0');
    final price = TextEditingController();
    var reset = list.any((u) => u.status == 'limited' || u.nearLimit);
    var paid = true, allServers = false;
    final others = (await Storage.load()).where((x) => x.id != widget.api.server.id).toList();
    if (!mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(list.length == 1 ? 'Renew ${list.first.username}' : 'Renew ${list.length} users'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: days, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'ရက် ထပ်တိုး', helperText: 'No-expiry user ဆိုရင် မပြောင်းပါ')),
        TextField(controller: gb, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'GB ထပ်တိုး', helperText: 'Unlimited user ဆိုရင် မပြောင်းပါ')),
        TextField(controller: price, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: t('Price per user (optional)'), helperText: 'ထည့်ရင် ရောင်းချမှတ်တမ်းထဲ မှတ်မယ်')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: paid, title: Text('ပေးပြီး (Paid)'), onChanged: (v) => set(() => paid = v)),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: reset, title: Text('Usage ကို 0 ပြန်ထား'),
            onChanged: (v) => set(() => reset = v ?? false)),
        if (others.isNotEmpty) CheckboxListTile(contentPadding: EdgeInsets.zero, value: allServers,
            title: Text('တခြား server တွေမှာပါ Renew'), subtitle: Text('username တူတဲ့ user ကို'),
            onChanged: (v) => set(() => allServers = v ?? false)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('Renew'))),
      ],
    )));
    if (ok != true || !mounted) return;
    final d = int.tryParse(days.text.trim()) ?? 0;
    final g = double.tryParse(gb.text.trim()) ?? 0;
    final p = double.tryParse(price.text.trim()) ?? 0;
    final okUsers = <VpnUser>[];
    final otherApis = {for (final o in (allServers ? others : <ServerConfig>[])) o.id: MarzbanApi(o)};
    final otherErr = <String>[];
    final r = await runBulk<VpnUser>(context, 'Renewing', list, (u) => u.username, (u) async {
      if (reset) await widget.api.resetUsage(u.username);
      await widget.api.renew(u, days: d, gb: g);
      okUsers.add(u);
      for (final o in others.where((x) => otherApis.containsKey(x.id))) {
        try {
          final api2 = otherApis[o.id]!;
          for (final f in (await api2.users(search: u.username)).where((x) => x.username == u.username)) {
            if (reset) await api2.resetUsage(f.username);
            await api2.renew(f, days: d, gb: g);
          }
        } catch (e) {
          otherErr.add('${u.username} @ ${o.name}: ${e is String ? e : MarzbanApi.errorText(e)}');
        }
      }
    });
    r.errors.addAll(otherErr);
    if (p > 0 && okUsers.isNotEmpty) {
      await SalesStore.add([
        for (final u in okUsers)
          Sale(ts: DateTime.now().millisecondsSinceEpoch ~/ 1000, server: widget.api.server.name,
              user: u.username, kind: 'renew', days: d, gb: g, amount: p, paid: paid)
      ]);
    }
    await _finishBulk('Renew result', r);
  }

  void _show(VpnUser u) {
    final link = _fullLink(u);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (c) => SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(u.username, style: Theme.of(context).textTheme.titleLarge),
        if (u.note.isNotEmpty) Text(u.note, style: TextStyle(fontSize: 12)),
        if (AppSettings.contacts[AppSettings.contactKey(widget.api.server.id, u.username)] != null)
          InkWell(
            onTap: () { Clipboard.setData(ClipboardData(text: AppSettings.contacts[AppSettings.contactKey(widget.api.server.id, u.username)]!)); _toast('Contact copied'); },
            child: Padding(padding: EdgeInsets.only(top: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.contact_phone, size: 14), SizedBox(width: 4),
              Text(AppSettings.contacts[AppSettings.contactKey(widget.api.server.id, u.username)]!, style: TextStyle(fontSize: 12)),
            ])),
          ),
        SizedBox(height: 12),
        if (link.isNotEmpty) Container(
          color: Colors.white, padding: EdgeInsets.all(8),
          child: QrImageView(data: link, size: 220)),
        SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          if (link.isNotEmpty) FilledButton.icon(
              icon: Icon(Icons.share), label: Text(t('Share')),
              onPressed: () => shareMessage(u, link)),
          if (link.isNotEmpty) FilledButton.tonalIcon(
              icon: Icon(Icons.qr_code), label: Text(t('QR image')),
              onPressed: () async { try { await shareQrImage(u, link); } catch (e) { _toast('$e'); } }),
          if (link.isNotEmpty) FilledButton.tonalIcon(
              icon: Icon(Icons.download), label: Text(t('Save QR')),
              onPressed: () async { try { await saveQrToGallery(u, link); _toast('Saved to gallery'); } catch (e) { _toast('$e'); } }),
          FilledButton.tonalIcon(
              icon: Icon(Icons.autorenew), label: Text(t('Renew')),
              onPressed: () { Navigator.pop(c); _renewMany([u]); }),
          if (link.isNotEmpty) FilledButton.tonalIcon(
              icon: Icon(Icons.notifications_active), label: Text(t('Remind')),
              onPressed: () => shareReminder(u, link)),
          FilledButton.tonalIcon(
              icon: Icon(Icons.edit), label: Text(t('Edit')),
              onPressed: () async {
                Navigator.pop(c);
                final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EditUserScreen(api: widget.api, user: u)));
                if (ok == true) _load();
              }),
        ]),
        SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          if (link.isNotEmpty) OutlinedButton.icon(
              icon: Icon(Icons.copy), label: Text('Subscription'),
              onPressed: () { Clipboard.setData(ClipboardData(text: link)); _toast('Link Copied'); }),
          for (var i = 0; i < u.links.length; i++) OutlinedButton.icon(
              icon: Icon(Icons.link), label: Text('Config ${i + 1}'),
              onPressed: () { Clipboard.setData(ClipboardData(text: u.links[i])); _toast('Link Copied'); }),
        ]),
        Divider(height: 24),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: () async { Navigator.pop(c); await widget.api.resetUsage(u.username); _load(); }, child: Text(t('Reset usage'))),
          TextButton(onPressed: () async { Navigator.pop(c); await widget.api.revokeSub(u.username); _load(); }, child: Text(t('Revoke link'))),
          TextButton(onPressed: () { Navigator.pop(c); _setEnabled([u], u.status == 'disabled'); }, child: Text(u.status == 'disabled' ? 'Enable' : 'Disable')),
          TextButton(onPressed: () { Navigator.pop(c); _deleteMany([u]); }, child: Text(t('Delete'), style: TextStyle(color: Colors.red))),
        ]),
      ]))),
    );
  }

  List<VpnUser> _shown() {
    var l = special == 1 ? users.where((u) => u.expiringSoon).toList()
        : special == 2 ? users.where((u) => u.nearLimit).toList() : List<VpnUser>.from(users);
    switch (sort) {
      case 'usage':
        l.sort((a, b) => b.usedTraffic.compareTo(a.usedTraffic));
      case 'expiry':
        int key(VpnUser u) => (u.expire == null || u.expire == 0) ? 1 << 40 : u.expire!;
        l.sort((a, b) => key(a).compareTo(key(b)));
      default:
        l.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    }
    return l;
  }

  Widget _selectBar(List<VpnUser> shown) {
    final sel = users.where((u) => selected.contains(u.username)).toList();
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(children: [
        IconButton(icon: Icon(Icons.close), onPressed: () => setState(selected.clear)),
        Expanded(child: Text('${sel.length} selected')),
        IconButton(tooltip: t('Select all'), icon: Icon(Icons.select_all),
            onPressed: () => setState(() => selected.addAll(shown.map((u) => u.username)))),
        IconButton(tooltip: t('Renew'), icon: Icon(Icons.autorenew), onPressed: () => _renewMany(sel)),
        IconButton(tooltip: t('Enable'), icon: Icon(Icons.play_circle_outline), onPressed: () => _setEnabled(sel, true)),
        IconButton(tooltip: t('Disable'), icon: Icon(Icons.pause_circle_outline), onPressed: () => _setEnabled(sel, false)),
        IconButton(tooltip: t('Delete'), icon: Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteMany(sel)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiringN = users.where((u) => u.expiringSoon).length;
    final nearN = users.where((u) => u.nearLimit).length;
    final shown = _shown();
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) setState(selected.clear); },
      child: Scaffold(
        floatingActionButton: selecting ? null : FloatingActionButton.extended(
          icon: Icon(Icons.person_add), label: Text(t('Create VPN User')),
          onPressed: () async {
            final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CreateUserScreen(api: widget.api)));
            if (ok == true) _load();
          }),
        body: Column(children: [
          if (selecting) _selectBar(shown),
          Padding(padding: EdgeInsets.fromLTRB(12, 8, 12, 0), child: Row(children: [
            Expanded(child: TextField(
              controller: search, onSubmitted: (_) => _load(),
              decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: t('Search users'), isDense: true, border: OutlineInputBorder()))),
            SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: t('Sort'), icon: Icon(Icons.sort), initialValue: sort,
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'name', child: Text(t('Name'))),
                PopupMenuItem(value: 'usage', child: Text(t('Usage (high first)'))),
                PopupMenuItem(value: 'expiry', child: Text(t('Expiry (soon first)'))),
              ]),
            DropdownButton<String?>(
              value: status, hint: Text(t('All')),
              items: [
                DropdownMenuItem(value: null, child: Text(t('All'))),
                DropdownMenuItem(value: 'active', child: Text(t('Active'))),
                DropdownMenuItem(value: 'expired', child: Text(t('Expired'))),
                DropdownMenuItem(value: 'limited', child: Text(t('Limited'))),
                DropdownMenuItem(value: 'disabled', child: Text(t('Disabled'))),
              ],
              onChanged: (v) { status = v; _load(); }),
          ])),
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 12), children: [
            for (final e in [
              (0, 'All (${users.length})'),
              (1, 'ကုန်ခါနီး ≤3 ရက် ($expiringN)'),
              (2, 'Data ≥90% ($nearN)'),
            ]) Padding(padding: EdgeInsets.only(right: 8, top: 6, bottom: 6), child: ChoiceChip(
              label: Text(e.$2), selected: special == e.$1, onSelected: (_) => setState(() => special = e.$1))),
          ])),
          if (special != 0 && shown.isNotEmpty && !selecting)
            Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 4), child: Align(alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, children: [
                FilledButton.tonalIcon(
                  icon: Icon(Icons.autorenew), label: Text('Renew all ${shown.length}'),
                  onPressed: () => _renewMany(shown)),
                if (special == 1) FilledButton.tonalIcon(
                  icon: Icon(Icons.notifications_active), label: Text('Remind ${shown.length}'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RemindScreen(api: widget.api, users: shown)))),
              ]))),
          Expanded(child: loading
              ? Center(child: CircularProgressIndicator())
              : err != null
                  ? Center(child: Text(err!))
                  : RefreshIndicator(onRefresh: _load, child: shown.isEmpty
                      ? ListView(children: [SizedBox(height: 120), Center(child: Text(t('No users found')))])
                      : ListView.builder(
                          padding: EdgeInsets.only(bottom: 90),
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final u = shown[i];
                            final exp = u.expireDate;
                            final limit = u.dataLimit == 0 ? '∞' : fmtBytes(u.dataLimit);
                            final sel = selected.contains(u.username);
                            void toggle() => setState(() => sel ? selected.remove(u.username) : selected.add(u.username));
                            return ListTile(
                              selected: sel,
                              leading: sel
                                  ? CircleAvatar(child: Icon(Icons.check))
                                  : CircleAvatar(backgroundColor: _statusColor(u.status), child: Text(u.username.isEmpty ? '?' : u.username[0].toUpperCase())),
                              title: Text(u.username),
                              subtitle: Text('${fmtBytes(u.usedTraffic)} / $limit  •  '
                                  '${exp == null ? 'No expiry' : 'Expires: ${exp.toString().substring(0, 10)}'}'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                if (u.expiringSoon || u.nearLimit) Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                                SizedBox(width: 4),
                                Text(u.status.toUpperCase(), style: TextStyle(color: _statusColor(u.status), fontSize: 11)),
                              ]),
                              onTap: selecting ? toggle : () => _show(u),
                              onLongPress: toggle,
                            );
                          }))),
        ]),
      ),
    );
  }
}
