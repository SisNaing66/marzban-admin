import 'dart:math';
import 'package:flutter/material.dart';
import '../api.dart';
import '../bulk.dart';
import '../sales.dart';
import '../settings.dart';

class CreateUserScreen extends StatefulWidget {
  final MarzbanApi api;
  const CreateUserScreen({super.key, required this.api});
  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final username = TextEditingController();
  final count = TextEditingController(text: '1');
  final gb = TextEditingController();
  final days = TextEditingController(text: '30');
  final price = TextEditingController();
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

  static final _rnd = Random();
  String _rand(int n) => List.generate(n, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_rnd.nextInt(36)]).join();

  Future<void> _savePreset() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Save as preset'),
      content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Preset name', hintText: '1 month 50GB')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
      ],
    ));
    if (ok != true || name.text.trim().isEmpty) return;
    AppSettings.presets.add({
      'name': name.text.trim(),
      'days': int.tryParse(days.text.trim()) ?? 0,
      'gb': double.tryParse(gb.text.trim()) ?? 0,
      'price': double.tryParse(price.text.trim()) ?? 0,
    });
    await AppSettings.savePresets();
    setState(() {});
  }

  String _num(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _create() async {
    final base = username.text.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch(base)) { setState(() => err = 'Username: 3-32 letters/numbers/_'); return; }
    if (selected.isEmpty) { setState(() => err = 'Select at least one inbound'); return; }
    final n = (int.tryParse(count.text.trim()) ?? 1).clamp(1, 100);
    final names = <String>[];
    if (n == 1) { names.add(base); } else {
      final seen = <String>{};
      while (names.length < n) {
        final s = '${base}_${_rand(4)}';
        if (seen.add(s)) names.add(s);
      }
    }
    final d = int.tryParse(days.text.trim()) ?? 0;
    final g = double.tryParse(gb.text.trim()) ?? 0;
    final p = double.tryParse(price.text.trim()) ?? 0;
    final sel = <String, List<String>>{};
    for (final s in selected) { final x = s.split('|'); (sel[x[0]] ??= []).add(x[1]); }
    setState(() { busy = true; err = null; });

    final created = <String>[];
    final r = await runBulk<String>(context, 'Creating users', names, (s) => s, (name) async {
      await widget.api.createUser(
        username: name,
        expire: d > 0 ? DateTime.now().add(Duration(days: d)).millisecondsSinceEpoch ~/ 1000 : 0,
        dataLimit: (g * 1024 * 1024 * 1024).round(),
        note: note.text.trim(), inbounds: sel);
      created.add(name);
    });
    if (p > 0 && created.isNotEmpty) {
      await SalesStore.add([
        for (final u in created)
          Sale(ts: DateTime.now().millisecondsSinceEpoch ~/ 1000, server: widget.api.server.name, user: u, kind: 'create', days: d, gb: g, amount: p)
      ]);
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (n > 1 || r.failed > 0) {
      await showBulkResult(context, 'Create result', r, extra: created.isEmpty ? null : created.join('\n'));
    }
    if (mounted && created.isNotEmpty) Navigator.pop(context, true);
    if (mounted && created.isEmpty) setState(() => err = r.errors.isEmpty ? 'Nothing created' : r.errors.first);
  }

  @override
  Widget build(BuildContext context) {
    final multi = (int.tryParse(count.text.trim()) ?? 1) > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Create VPN User')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (AppSettings.presets.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final p in List<Map<String, dynamic>>.from(AppSettings.presets))
              InputChip(
                label: Text('${p['name']}'),
                onPressed: () => setState(() {
                  days.text = _num(p['days'] ?? 0);
                  gb.text = (p['gb'] ?? 0) == 0 ? '' : _num(p['gb']);
                  price.text = (p['price'] ?? 0) == 0 ? '' : _num(p['price']);
                }),
                onDeleted: () async { AppSettings.presets.remove(p); await AppSettings.savePresets(); setState(() {}); },
              ),
          ]),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Expanded(child: TextField(controller: username,
              decoration: InputDecoration(labelText: multi ? 'Username prefix' : 'Username', border: const OutlineInputBorder()))),
          IconButton(tooltip: 'Random', icon: const Icon(Icons.casino), onPressed: () => setState(() => username.text = 'u${_rand(6)}')),
        ]),
        const SizedBox(height: 12),
        TextField(controller: count, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Count (1-100)', helperText: 'ရှိရင် username နောက်မှာ random စာလုံးတွေ ထပ်ထည့်မယ်', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: gb, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Data limit (GB) - empty = unlimited', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: days, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Valid days - 0 = never expires', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: price, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price per user (optional)', helperText: 'ထည့်ရင် ရောင်းချမှတ်တမ်းထဲ မှတ်မယ်', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder())),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _savePreset, icon: const Icon(Icons.bookmark_add), label: const Text('Save days/GB/price as preset'))),
        const SizedBox(height: 8),
        Text('Inbounds', style: Theme.of(context).textTheme.titleMedium),
        if (loadingInbounds) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        for (final e in inbounds.entries) for (final t in e.value)
          CheckboxListTile(
            dense: true, title: Text(t), subtitle: Text(e.key),
            value: selected.contains('${e.key}|$t'),
            onChanged: (v) => setState(() => v == true ? selected.add('${e.key}|$t') : selected.remove('${e.key}|$t'))),
        if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : _create, child: Text(busy ? 'Creating...' : (multi ? 'Create ${count.text.trim()} users' : 'Create'))),
      ]),
    );
  }
}
