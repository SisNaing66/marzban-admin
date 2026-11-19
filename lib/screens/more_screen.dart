import 'package:flutter/material.dart';
import '../backup_io.dart';
import '../settings.dart';
import 'sales_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  late final tpl = TextEditingController(text: AppSettings.template);

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _askPin(String title) {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
      ],
    ));
  }

  Future<void> _toggleLock(bool on) async {
    if (on) {
      final a = await _askPin('PIN အသစ် (4-8 လုံး)');
      if (a == null || a.length < 4) { if (a != null) _toast('PIN အနည်းဆုံး ၄ လုံး'); return; }
      final b = await _askPin('PIN ထပ်ရိုက်ပါ');
      if (b != a) { _toast('PIN မတူပါ'); return; }
      await AppSettings.setPin(a);
    } else {
      final cur = await _askPin('လက်ရှိ PIN');
      if (cur == null) return;
      if (!AppSettings.checkPin(cur)) { _toast('PIN မှားနေပါတယ်'); return; }
      await AppSettings.setPin(null);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppSettings.themeMode,
            builder: (_, m, __) => SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {m},
              onSelectionChanged: (s) => AppSettings.setTheme(s.first),
            ),
          ),
          const Divider(height: 32),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.receipt_long), title: const Text('Sales'),
              subtitle: const Text('Create/Renew ရောင်းချမှတ်တမ်းနဲ့ လစဉ်ဝင်ငွေ'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()))),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.upload_file), title: const Text('Export app data'),
              subtitle: const Text('Server စာရင်း (password ပါ!)၊ template၊ preset၊ sales ကို ဖိုင်အဖြစ် သိမ်း'),
              onTap: () => exportAppData(context)),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.download_for_offline), title: const Text('Import app data'),
              subtitle: const Text('ဖုန်းအသစ်မှာ ဖိုင်ကနေ ပြန်သွင်း'),
              onTap: () async { if (await importAppData(context) && mounted) setState(() => tpl.text = AppSettings.template); }),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('App lock (PIN)'),
            subtitle: const Text('App ဖွင့်ချိန်နဲ့ နောက်ခံမှာ ၃၀ စက္ကန့်ကျော်ပြီးပြန်လာချိန် PIN တောင်းမယ်'),
            value: AppSettings.pinHash != null,
            onChanged: _toggleLock,
          ),
          const Divider(height: 32),
          Text('Message template', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('ထည့်လို့ရတဲ့ စာလုံးတွေ: {name} {username} {link} {gb} {expire} {days}', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          TextField(controller: tpl, maxLines: 9, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton(onPressed: () { tpl.text = defaultTemplate; }, child: const Text('Default')),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () async { await AppSettings.setTemplate(tpl.text); _toast('Saved'); }, child: const Text('Save template'))),
          ]),
        ]),
      );
}
