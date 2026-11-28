import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../hub.dart';
import '../settings.dart';

class HubScreen extends StatefulWidget {
  HubScreen({super.key});
  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  final url = TextEditingController(text: AppSettings.hubUrl);
  final user = TextEditingController(text: AppSettings.hubUser);
  final pass = TextEditingController(text: AppSettings.hubPass);
  final front = TextEditingController(text: AppSettings.hubFront);
  final uname = TextEditingController();
  final cname = TextEditingController();
  final gb = TextEditingController(text: '200');
  final days = TextEditingController(text: '30');

  List<Map<String, dynamic>>? servers;
  final picked = <int>{};
  String? status;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (AppSettings.hubUser.isNotEmpty) _loadServers();
  }

  Future<void> _saveAndTest() async {
    await AppSettings.saveHub(url: url.text, user: user.text, pass: pass.text, front: front.text);
    await _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() { busy = true; status = null; });
    try {
      final s = await HubApi().servers();
      setState(() { servers = s; picked..clear()..addAll(s.map((e) => e['id'] as int)); status = 'ချိတ်ပြီး — Server ${s.length} ခု'; });
    } catch (e) {
      setState(() { servers = null; status = 'မအောင်မြင်ပါ: ${HubApi.err(e)}'; });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _create() async {
    final name = uname.text.trim();
    final g = double.tryParse(gb.text.trim());
    if (name.isEmpty || g == null || g <= 0 || picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Username၊ GB နဲ့ Server အနည်းဆုံး ၁ ခု ရွေးပါ')));
      return;
    }
    setState(() => busy = true);
    try {
      final resp = await HubApi().createMerged(
          serverIds: picked.toList(), username: name, customerName: cname.text.trim(), gb: g,
          days: int.tryParse(days.text.trim()));
      if (!mounted) return;
      _showResult(name, resp);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('မအောင်မြင်ပါ: ${HubApi.err(e)}')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showResult(String name, dynamic resp) {
    final link = hubLinkFrom(resp, name);
    final msg = 'မင်္ဂလာပါ ${cname.text.trim().isEmpty ? name : cname.text.trim()}\n\n'
        'Username: $name\nData: ${gb.text} GB (Server အားလုံး ပေါင်းပြီး)\n'
        '${days.text.trim().isEmpty ? '' : 'သက်တမ်း: ${days.text} ရက်\n'}\nLink:\n$link';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('ဆောက်ပြီးပါပြီ'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(link),
          SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Hub ပြန်ပေးတာ (စစ်ဖို့)', style: TextStyle(fontSize: 13)),
            children: [SelectableText('$resp', style: TextStyle(fontSize: 11))],
          ),
        ])),
        actions: [
          TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: link)); }, child: Text('Link Copy')),
          TextButton(onPressed: () => Share.share(msg), child: Text('ပို့မယ်')),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text('ပိတ်')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Hub — Server အားလုံး Link')),
        body: ListView(padding: EdgeInsets.all(16), children: [
          Text('Hub ချိတ်ဆက်မှု', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          TextField(controller: url, decoration: InputDecoration(labelText: 'Hub လိပ်စာ', border: OutlineInputBorder())),
          SizedBox(height: 8),
          TextField(controller: user, decoration: InputDecoration(labelText: 'Hub Username', border: OutlineInputBorder())),
          SizedBox(height: 8),
          TextField(controller: pass, obscureText: true, decoration: InputDecoration(labelText: 'Hub Password', border: OutlineInputBorder())),
          SizedBox(height: 8),
          TextField(controller: front, decoration: InputDecoration(labelText: 'Link Front (ဥပမာ https://vip.lovetulip69.com)', border: OutlineInputBorder())),
          SizedBox(height: 8),
          Row(children: [
            FilledButton(onPressed: busy ? null : _saveAndTest, child: Text('Save + စစ်မယ်')),
            SizedBox(width: 12),
            if (busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          if (status != null) Padding(padding: EdgeInsets.only(top: 8), child: Text(status!)),
          Divider(height: 32),
          if (servers != null) ...[
            Text('Customer အသစ် (Link တစ်ခုတည်း)', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            TextField(controller: uname, decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
            SizedBox(height: 8),
            TextField(controller: cname, decoration: InputDecoration(labelText: 'Customer နာမည် (မဖြစ်မနေ မလို)', border: OutlineInputBorder())),
            SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: gb, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'စုစုပေါင်း GB', border: OutlineInputBorder()))),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: days, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'ရက်', border: OutlineInputBorder()))),
            ]),
            SizedBox(height: 8),
            Text('Server ရွေးပါ', style: TextStyle(fontWeight: FontWeight.w600)),
            for (final s in servers!)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: picked.contains(s['id']),
                title: Text('${s['name'] ?? s['id']}'),
                onChanged: (v) => setState(() => v == true ? picked.add(s['id'] as int) : picked.remove(s['id'])),
              ),
            SizedBox(height: 8),
            FilledButton.icon(onPressed: busy ? null : _create, icon: Icon(Icons.add_link), label: Text('ဆောက်မယ်')),
            SizedBox(height: 8),
            Text('စုစုပေါင်း GB ပြည့်ရင် Server အားလုံးမှာ Hub က ၅ မိနစ်ခြား စစ်ပြီး ပိတ်ပေးပါမယ်။',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ],
        ]),
      );
}
