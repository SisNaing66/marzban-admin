import '../i18n.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import 'logs_screen.dart';

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
  String info = '';

  @override
  void initState() { super.initState(); _load(); _info(); }

  Future<void> _info() async {
    try {
      final c = await widget.api.coreInfo();
      final st = (c['started'] ?? '').toString();
      if (mounted) setState(() => info = 'Xray ${c['version']}${st.isEmpty ? '' : '  •  started ${st.length >= 16 ? st.substring(0, 16).replaceAll('T', ' ') : st}'}');
    } catch (_) {}
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(t('Restart core?')),
      content: Text('Xray ကို restart လုပ်ရင် user အားလုံး ခဏပြတ်သွားပါမယ်။'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Restart'))),
      ],
    ));
    if (ok != true) return;
    setState(() { busy = true; err = null; });
    try { await widget.api.restartCore(); } catch (e) { err = MarzbanApi.errorText(e); }
    if (mounted) {
      setState(() => busy = false);
      if (err == null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Core restarted')))); _info(); }
    }
  }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      ctrl.text = JsonEncoder.withIndent('  ').convert(await widget.api.coreConfig());
    } catch (e) { err = MarzbanApi.errorText(e); }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    Map<String, dynamic> cfg;
    try { cfg = Map<String, dynamic>.from(jsonDecode(ctrl.text)); }
    catch (_) { setState(() => err = 'Invalid JSON'); return; }
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(t('Save & restart core?')),
      content: Text(t('Incorrect config can crash the server. Are you sure?')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Save'))),
      ],
    ));
    if (ok != true) return;
    setState(() { busy = true; err = null; });
    try { await widget.api.setCoreConfig(cfg); } catch (e) { err = MarzbanApi.errorText(e); }
    if (mounted) setState(() => busy = false);
    if (err == null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Saved'))));
  }

  @override
  Widget build(BuildContext context) => loading
      ? Center(child: CircularProgressIndicator())
      : Padding(padding: EdgeInsets.all(12), child: Column(children: [
          if (info.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text(info, style: TextStyle(fontSize: 12))),
          Row(children: [
            OutlinedButton.icon(onPressed: busy ? null : _restart, icon: Icon(Icons.restart_alt), label: Text(t('Restart core'))),
            SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogsScreen(api: widget.api))),
              icon: Icon(Icons.terminal), label: Text(t('Logs'))),
          ]),
          SizedBox(height: 8),
          if (err != null) Text(err!, style: TextStyle(color: Colors.red)),
          Expanded(child: TextField(
            controller: ctrl, maxLines: null, expands: true,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(border: OutlineInputBorder()))),
          SizedBox(height: 8),
          Row(children: [
            OutlinedButton(onPressed: _load, child: Text(t('Reload'))),
            SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: busy ? null : _save, child: Text(busy ? 'Saving...' : 'Save config'))),
          ]),
        ]));
}
