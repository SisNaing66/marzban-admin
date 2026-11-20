import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../sales.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Sale> all = [];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool loading = true;
  bool onlyUnpaid = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    all = await SalesStore.load();
    if (mounted) setState(() => loading = false);
  }

  List<Sale> get inMonth => all.where((s) {
        final d = DateTime.fromMillisecondsSinceEpoch(s.ts * 1000);
        return d.year == month.year && d.month == month.month;
      }).toList()..sort((a, b) => b.ts.compareTo(a.ts));

  Future<void> _markPaid(Sale s) async {
    final i = all.indexOf(s);
    if (i < 0) return;
    all[i] = s.copyWith(paid: true);
    await SalesStore.replaceAll(all);
    setState(() {});
  }

  String _money(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  String _d(int ts) => DateTime.fromMillisecondsSinceEpoch(ts * 1000).toString().substring(0, 16);

  Future<void> _csv(List<Sale> l) async {
    final b = StringBuffer('date,server,user,type,days,gb,amount,paid\n');
    for (final s in l) { b.writeln('${_d(s.ts)},${s.server},${s.user},${s.kind},${s.days},${s.gb},${s.amount},${s.paid ? 'paid' : 'unpaid'}'); }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/sales-${month.year}-${month.month.toString().padLeft(2, '0')}.csv');
    await f.writeAsString(b.toString());
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')]);
  }

  Future<void> _delete(Sale s) async {
    all.remove(s);
    await SalesStore.replaceAll(all);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final month_ = inMonth;
    final l = onlyUnpaid ? month_.where((s) => !s.paid).toList() : month_;
    final total = month_.where((s) => s.paid).fold<double>(0, (a, s) => a + s.amount);
    final unpaid = all.where((s) => !s.paid).fold<double>(0, (a, s) => a + s.amount);
    final creates = l.where((s) => s.kind == 'create').length;
    final renews = l.where((s) => s.kind == 'renew').length;
    return Scaffold(
      appBar: AppBar(title: const Text('Sales'), actions: [
        IconButton(tooltip: 'Export CSV', icon: const Icon(Icons.ios_share), onPressed: l.isEmpty ? null : () => _csv(l)),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => month = DateTime(month.year, month.month - 1))),
                Text('${month.year}-${month.month.toString().padLeft(2, '0')}', style: Theme.of(context).textTheme.titleMedium),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => month = DateTime(month.year, month.month + 1))),
              ]),
              Card(margin: const EdgeInsets.symmetric(horizontal: 12), child: Padding(padding: const EdgeInsets.all(14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _big('Income', _money(total), Colors.green),
                _big('Unpaid (all)', _money(unpaid), unpaid > 0 ? Colors.orange : null),
                _big('New', '$creates', null),
                _big('Renew', '$renews', null),
              ]))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.centerLeft, child: FilterChip(
                label: const Text('Unpaid only'), selected: onlyUnpaid, onSelected: (v) => setState(() => onlyUnpaid = v)))),
              Expanded(child: l.isEmpty
                  ? const Center(child: Text('မှတ်တမ်း မရှိသေးပါ\n(Create/Renew လုပ်ချိန် Price ထည့်ရင် ဒီမှာ မှတ်မယ်)', textAlign: TextAlign.center))
                  : ListView.builder(itemCount: l.length, itemBuilder: (_, i) {
                      final s = l[i];
                      return Dismissible(
                        key: ValueKey('${s.ts}${s.user}${s.kind}$i'),
                        direction: DismissDirection.endToStart,
                        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                        onDismissed: (_) => _delete(s),
                        child: ListTile(
                          dense: true,
                          leading: Icon(s.kind == 'create' ? Icons.person_add : Icons.autorenew),
                          title: Text(s.user),
                          subtitle: Text('${_d(s.ts)}  •  ${s.server}${s.days > 0 ? '  •  ${s.days}d' : ''}${s.gb > 0 ? '  •  +${s.gb}GB' : ''}'),
                          trailing: s.paid
                              ? Text(_money(s.amount), style: const TextStyle(fontWeight: FontWeight.w600))
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(_money(s.amount), style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                                  IconButton(tooltip: 'Mark paid', icon: const Icon(Icons.check_circle_outline, color: Colors.green), onPressed: () => _markPaid(s)),
                                ]),
                        ),
                      );
                    })),
            ]),
    );
  }

  Widget _big(String k, String v, Color? c) => Column(children: [
        Text(v, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c)),
        Text(k, style: const TextStyle(fontSize: 12)),
      ]);
}
