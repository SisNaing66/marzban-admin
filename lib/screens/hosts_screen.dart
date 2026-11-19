import 'package:flutter/material.dart';
import '../api.dart';

class HostsScreen extends StatefulWidget {
  final MarzbanApi api;
  const HostsScreen({super.key, required this.api});
  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  Map<String, dynamic> data = {};
  bool loading = true, saving = false;
  String? err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try { data = await widget.api.hosts(); } catch (e) { err = MarzbanApi.errorText(e); }
    if (mounted) setState(() => loading = false);
  }

  String _addr(dynamic a) => a is List ? a.join(',') : (a ?? '').toString();

  Future<void> _edit(String tag, int i) async {
    final h = Map<String, dynamic>.from((data[tag] as List)[i]);
    final remark = TextEditingController(text: (h['remark'] ?? '').toString());
    final address = TextEditingController(text: _addr(h['address']));
    final port = TextEditingController(text: (h['port'] ?? '').toString());
    final sni = TextEditingController(text: _addr(h['sni']));
    final host = TextEditingController(text: _addr(h['host']));
    final path = TextEditingController(text: (h['path'] ?? '').toString());
    var disabled = h['is_disabled'] == true;

    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: const Text('Edit Host'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Align(alignment: Alignment.centerLeft, child: Text('Inbound: $tag', style: const TextStyle(fontSize: 12))),
        TextField(controller: remark, decoration: const InputDecoration(labelText: 'Remark')),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
        TextField(controller: port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port (empty = inbound port)')),
        TextField(controller: sni, decoration: const InputDecoration(labelText: 'SNI')),
        TextField(controller: host, decoration: const InputDecoration(labelText: 'Host')),
        TextField(controller: path, decoration: const InputDecoration(labelText: 'Path')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Disabled'), value: disabled, onChanged: (v) => set(() => disabled = v)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    )));
    if (ok != true) return;

    // keep list-typed fields (newer Marzban) as lists
    dynamic keep(dynamic orig, String v) =>
        orig is List ? v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : v;
    h['remark'] = remark.text;
    h['address'] = keep(h['address'], address.text);
    h['port'] = port.text.trim().isEmpty ? null : int.tryParse(port.text.trim());
    h['sni'] = keep(h['sni'], sni.text);
    h['host'] = keep(h['host'], host.text);
    h['path'] = path.text;
    h['is_disabled'] = disabled;

    final copy = {for (final e in data.entries) e.key: List<dynamic>.from(e.value as List)};
    copy[tag]![i] = h;
    setState(() => saving = true);
    try {
      await widget.api.setHosts(copy);
      data = copy;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hosts saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(MarzbanApi.errorText(e))));
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (err != null) return Center(child: Text(err!));
    final items = <Widget>[];
    data.forEach((tag, list) {
      final l = list as List;
      for (var i = 0; i < l.length; i++) {
        final h = l[i] as Map;
        final off = h['is_disabled'] == true;
        items.add(ListTile(
          leading: Icon(Icons.public, color: off ? Colors.grey : null),
          title: Text((h['remark'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${_addr(h['address'])}${h['port'] == null ? '' : ':${h['port']}'}  •  $tag', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: off ? const Text('OFF', style: TextStyle(color: Colors.grey)) : null,
          onTap: saving ? null : () => _edit(tag, i),
        ));
      }
    });
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No Host Settings Found from Server.'))])
          : ListView(children: [if (saving) const LinearProgressIndicator(), ...items]),
    );
  }
}
