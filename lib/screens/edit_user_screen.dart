import '../i18n.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../settings.dart';

class EditUserScreen extends StatefulWidget {
  final MarzbanApi api;
  final VpnUser user;
  const EditUserScreen({super.key, required this.api, required this.user});
  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late final VpnUser u = widget.user;
  late final gb = TextEditingController(
      text: u.dataLimit == 0 ? '' : (u.dataLimit / 1073741824).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), ''));
  late final note = TextEditingController(text: u.note);
  late final contact = TextEditingController(text: AppSettings.contacts[AppSettings.contactKey(widget.api.server.id, widget.user.username)] ?? '');
  late DateTime? expire = u.expireDate;
  late bool enabled = u.status != 'disabled';
  late String strategy = (u.raw['data_limit_reset_strategy'] ?? 'no_reset').toString();
  Map<String, List<String>> inbounds = {};
  final selected = <String>{};
  bool inboundsLoaded = false, busy = false;
  String? err;

  static const strategies = ['no_reset', 'day', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    if (!strategies.contains(strategy)) strategy = 'no_reset';
    final cur = Map<String, dynamic>.from(u.raw['inbounds'] ?? {});
    cur.forEach((p, l) { for (final t in (l as List)) { selected.add('$p|$t'); } });
    widget.api.inboundTags().then((m) {
      if (mounted) setState(() { inbounds = m; inboundsLoaded = true; });
    }).catchError((_) {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: (expire != null && expire!.isAfter(now)) ? expire! : now.add(Duration(days: 30)),
        firstDate: now.subtract(Duration(days: 365)), lastDate: now.add(Duration(days: 3650)));
    if (d != null) setState(() => expire = DateTime(d.year, d.month, d.day, 23, 59));
  }

  Future<void> _save() async {
    final g = double.tryParse(gb.text.trim()) ?? 0;
    final patch = <String, dynamic>{
      'data_limit': (g * 1073741824).round(),
      'expire': expire == null ? 0 : expire!.millisecondsSinceEpoch ~/ 1000,
      'note': note.text.trim(),
      'data_limit_reset_strategy': strategy,
    };
    final wasDisabled = u.status == 'disabled';
    if (wasDisabled && enabled) patch['status'] = 'active';
    if (!wasDisabled && !enabled) patch['status'] = 'disabled';
    if (!wasDisabled && enabled && (u.status == 'expired' || u.status == 'limited')) patch['status'] = 'active';
    if (inboundsLoaded) {
      if (selected.isEmpty) { setState(() => err = 'Select at least one inbound'); return; }
      final inb = <String, List<String>>{};
      for (final s in selected) { final x = s.split('|'); (inb[x[0]] ??= []).add(x[1]); }
      final rawProxies = Map<String, dynamic>.from(u.raw['proxies'] ?? {});
      patch['inbounds'] = inb;
      patch['proxies'] = {for (final p in inb.keys) p: rawProxies[p] ?? <String, dynamic>{}};
    }
    setState(() { busy = true; err = null; });
    try {
      await widget.api.updateUser(u.username, patch);
      await AppSettings.setContact(widget.api.server.id, u.username, contact.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { busy = false; err = MarzbanApi.errorText(e); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Edit ${u.username}')),
        body: ListView(padding: EdgeInsets.all(16), children: [
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('Enabled')), value: enabled, onChanged: (v) => setState(() => enabled = v)),
          SizedBox(height: 8),
          TextField(controller: gb, keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t('Data limit (GB) - empty = unlimited'), border: OutlineInputBorder())),
          SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(labelText: t('Expire date'), border: OutlineInputBorder()),
            child: Row(children: [
              Expanded(child: Text(expire == null ? 'No expiry' : expire.toString().substring(0, 10))),
              TextButton(onPressed: _pickDate, child: Text(t('Pick date'))),
              if (expire != null) TextButton(onPressed: () => setState(() => expire = null), child: Text(t('No expiry'))),
            ]),
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: strategy,
            decoration: InputDecoration(labelText: t('Data limit reset'), border: OutlineInputBorder()),
            items: [for (final s in strategies) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) => setState(() => strategy = v ?? 'no_reset'),
          ),
          SizedBox(height: 12),
          TextField(controller: note, decoration: InputDecoration(labelText: t('Note'), border: OutlineInputBorder())),
          SizedBox(height: 12),
          TextField(controller: contact, decoration: InputDecoration(labelText: 'Contact (ဖုန်း / @telegram)', helperText: 'ဒီဖုန်းထဲမှာပဲ သိမ်းမယ် (panel ကို မပို့ပါ)', border: OutlineInputBorder())),
          SizedBox(height: 16),
          Text('Inbounds', style: Theme.of(context).textTheme.titleMedium),
          if (!inboundsLoaded) Padding(padding: EdgeInsets.all(12), child: Text('Loading... (မ load ရင် inbound ကို မပြောင်းဘဲ ကျန်တာပဲ သိမ်းမယ်)', style: TextStyle(fontSize: 12))),
          for (final e in inbounds.entries) for (final t in e.value)
            CheckboxListTile(
              dense: true, title: Text(t), subtitle: Text(e.key),
              value: selected.contains('${e.key}|$t'),
              onChanged: (v) => setState(() => v == true ? selected.add('${e.key}|$t') : selected.remove('${e.key}|$t'))),
          if (err != null) Padding(padding: EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: Colors.red))),
          SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save')),
        ]),
      );
}
