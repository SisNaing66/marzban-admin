import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';

class CoreSettingsScreen extends StatefulWidget {
  final MarzbanApi api;
  const CoreSettingsScreen({super.key, required this.api});
  @override
  State<CoreSettingsScreen> createState() => _CoreSettingsScreenState();
}

class _CoreSettingsScreenState extends State<CoreSettingsScreen> {
  final ctrl = TextEditingController();
  bool loading = true, busy = false;
  String? err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      ctrl.text = const JsonEncoder.withIndent('  ').convert(await widget.api.coreConfig());
    } catch (e) { err = MarzbanApi.errorText(e); }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    Map<String, dynamic> cfg;
    try { cfg = Map<String, dynamic>.from(jsonDecode(ctrl.text)); }
    catch (_) { setState(() => err = 'Invalid JSON'); return; }
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Save & restart core?'),
      content: const Text('Incorrect config can crash the server. Are you sure?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
      ],
    ));
    if (ok != true) return;
    setState(() { busy = true; err = null; });
    try { await widget.api.setCoreConfig(cfg); } catch (e) { err = MarzbanApi.errorText(e); }
    if (mounted) setState(() => busy = false);
    if (err == null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator())
      : Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
          Expanded(child: TextField(
            controller: ctrl, maxLines: null, expands: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(border: OutlineInputBorder()))),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton(onPressed: _load, child: const Text('Reload')),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save config'))),
          ]),
        ]));
}
