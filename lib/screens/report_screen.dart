import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';

class ReportScreen extends StatefulWidget {
  final MarzbanApi api;
  const ReportScreen({super.key, required this.api});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<VpnUser>? users;
  Map<String, dynamic> sys = {};
  String? err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { users = null; err = null; });
    try {
      final r = await Future.wait<dynamic>([widget.api.users(), widget.api.system().catchError((_) => <String, dynamic>{})]);
      if (mounted) setState(() { users = r[0] as List<VpnUser>; sys = r[1] as Map<String, dynamic>; });
    } catch (e) {
      if (mounted) setState(() => err = MarzbanApi.errorText(e));
    }
  }

  Widget _kv(String k, String v) => ListTile(dense: true, title: Text(k), trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)));

  @override
  Widget build(BuildContext context) {
    final l = users;
    return Scaffold(
      appBar: AppBar(title: Text('Usage - ${widget.api.server.name}'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: err != null
          ? Center(child: Text(err!))
          : l == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(12), children: [
                  Card(child: Column(children: [
                    _kv('Users', '${l.length}'),
                    _kv('Total used', fmtBytes(l.fold<int>(0, (a, u) => a + u.usedTraffic))),
                    _kv('Total quota (limited users)', fmtBytes(l.fold<int>(0, (a, u) => a + u.dataLimit))),
                    _kv('Average per user', l.isEmpty ? '0 B' : fmtBytes(l.fold<int>(0, (a, u) => a + u.usedTraffic) / l.length)),
                    if (sys['incoming_bandwidth'] != null) _kv('Server in / out', '${fmtBytes(sys['incoming_bandwidth'])} / ${fmtBytes(sys['outgoing_bandwidth'] ?? 0)}'),
                  ])),
                  const SizedBox(height: 8),
                  Text('By status', style: Theme.of(context).textTheme.titleMedium),
                  for (final s in ['active', 'expired', 'limited', 'disabled', 'on_hold'])
                    if (l.any((u) => u.status == s)) _bar(s, l.where((u) => u.status == s).length, l.length, '${l.where((u) => u.status == s).length}'),
                  const SizedBox(height: 12),
                  Text('Top 20 by usage', style: Theme.of(context).textTheme.titleMedium),
                  ..._top(l),
                ]),
    );
  }

  Iterable<Widget> _top(List<VpnUser> l) {
    final t = List<VpnUser>.from(l)..sort((a, b) => b.usedTraffic.compareTo(a.usedTraffic));
    final top = t.take(20).toList();
    final max = top.isEmpty || top.first.usedTraffic == 0 ? 1 : top.first.usedTraffic;
    return [for (final u in top) _bar(u.username, u.usedTraffic, max, fmtBytes(u.usedTraffic))];
  }

  Widget _bar(String label, num v, num max, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(label, overflow: TextOverflow.ellipsis)), Text(text, style: const TextStyle(fontSize: 12))]),
          const SizedBox(height: 2),
          LinearProgressIndicator(value: max == 0 ? 0 : (v / max).clamp(0, 1).toDouble(), minHeight: 6, borderRadius: BorderRadius.circular(3)),
        ]),
      );
}
