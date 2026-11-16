import 'package:flutter/material.dart';
import '../api.dart';

class CreateUserScreen extends StatefulWidget {
  final MarzbanApi api;
  const CreateUserScreen({super.key, required this.api});
  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final username = TextEditingController();
  final gb = TextEditingController();
  final days = TextEditingController(text: '30');
  final note = TextEditingController();
  Map<String, List<String>> inbounds = {};
  final Set<String> selected = {}; // "proto|tag"
  bool busy = false, loadingInbounds = true;
  String? err;

  @override
  void initState() {
    super.initState();
    widget.api.inboundTags().then((m) {
      if (!mounted) return;
      setState(() {
        inbounds = m;
        for (final e in m.entries) { for (final t in e.value) { selected.add('${e.key}|$t'); } }
        loadingInbounds = false;
      });
    }).catchError((e) { if (mounted) setState(() { err = MarzbanApi.errorText(e); loadingInbounds = false; }); });
  }

  Future<void> _create() async {
    final name = username.text.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch(name)) { setState(() => err = 'Username: 3-32 letters/numbers/_'); return; }
    if (selected.isEmpty) { setState(() => err = 'Select at least one inbound'); return; }
    final d = int.tryParse(days.text.trim()) ?? 0;
    final g = double.tryParse(gb.text.trim()) ?? 0;
    final sel = <String, List<String>>{};
    for (final s in selected) { final p = s.split('|'); (sel[p[0]] ??= []).add(p[1]); }
    setState(() { busy = true; err = null; });
    try {
      await widget.api.createUser(
        username: name,
        expire: d > 0 ? DateTime.now().add(Duration(days: d)).millisecondsSinceEpoch ~/ 1000 : 0,
        dataLimit: (g * 1024 * 1024 * 1024).round(),
        note: note.text.trim(), inbounds: sel);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { busy = false; err = MarzbanApi.errorText(e); });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create VPN User')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: gb, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Data limit (GB) - empty = unlimited', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: days, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valid days - 0 = never expires', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Text('Inbounds', style: Theme.of(context).textTheme.titleMedium),
          if (loadingInbounds) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          for (final e in inbounds.entries) for (final t in e.value)
            CheckboxListTile(
              dense: true, title: Text(t), subtitle: Text(e.key),
              value: selected.contains('${e.key}|$t'),
              onChanged: (v) => setState(() => v == true ? selected.add('${e.key}|$t') : selected.remove('${e.key}|$t'))),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : _create, child: Text(busy ? 'Creating...' : 'Create')),
        ]),
      );
}
