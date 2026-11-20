import '../i18n.dart';
import 'package:flutter/material.dart';
import '../background.dart';
import '../backup_io.dart';
import '../biometric.dart';
import '../settings.dart';
import 'sales_screen.dart';
import 'telegram_card.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  late final tpl = TextEditingController(text: AppSettings.template);
  late final remind = TextEditingController(text: AppSettings.remindTemplate);

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _askPin(String title) {
    final c = TextEditingController();
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(t('OK'))),
      ],
    ));
  }

  Future<void> _toggleAlerts(bool on) async {
    try {
      if (on) {
        if (!await enableAlerts()) { _toast('Notification ခွင့်ပြုချက် လိုပါတယ် (Settings > Apps > Notifications)'); return; }
      } else {
        await disableAlerts();
      }
      await AppSettings.setAlerts(on);
    } catch (e) {
      _toast('$e');
    }
    setState(() {});
  }

  Future<void> _toggleBio(bool on) async {
    if (on) {
      if (!await biometricAvailable()) { _toast('ဒီဖုန်းမှာ လက်ဗွေ/မျက်နှာ မသတ်မှတ်ရသေးပါ'); return; }
      if (!await biometricAuth('လက်ဗွေ unlock ကို ဖွင့်ရန် အတည်ပြုပါ')) return;
    }
    await AppSettings.setBiometric(on);
    setState(() {});
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
        appBar: AppBar(title: Text(t('More'))),
        body: ListView(padding: EdgeInsets.all(16), children: [
          Text(t('Language'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ValueListenableBuilder<String>(
            valueListenable: AppSettings.lang,
            builder: (_, l, __) => SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'my', label: Text('မြန်မာ')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {l},
              onSelectionChanged: (s) => AppSettings.setLang(s.first),
            ),
          ),
          const Divider(height: 32),
          Text(t('Theme'), style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppSettings.themeMode,
            builder: (_, m, __) => SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(t('Auto'))),
                ButtonSegment(value: ThemeMode.light, label: Text(t('Light'))),
                ButtonSegment(value: ThemeMode.dark, label: Text(t('Dark'))),
              ],
              selected: {m},
              onSelectionChanged: (s) => AppSettings.setTheme(s.first),
            ),
          ),
          Divider(height: 32),
          TelegramCard(),
          Divider(height: 32),
          ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.receipt_long), title: Text(t('Sales')),
              subtitle: Text('Create/Renew ရောင်းချမှတ်တမ်းနဲ့ လစဉ်ဝင်ငွေ'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalesScreen()))),
          ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.upload_file), title: Text(t('Export app data')),
              subtitle: Text('Server စာရင်း (password ပါ!)၊ template၊ preset၊ sales ကို ဖိုင်အဖြစ် သိမ်း'),
              onTap: () => exportAppData(context)),
          ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.download_for_offline), title: Text(t('Import app data')),
              subtitle: Text('ဖုန်းအသစ်မှာ ဖိုင်ကနေ ပြန်သွင်း'),
              onTap: () async { if (await importAppData(context) && mounted) setState(() => tpl.text = AppSettings.template); }),
          Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('App lock (PIN)')),
            subtitle: Text('App ဖွင့်ချိန်နဲ့ နောက်ခံမှာ ၃၀ စက္ကန့်ကျော်ပြီးပြန်လာချိန် PIN တောင်းမယ်'),
            value: AppSettings.pinHash != null,
            onChanged: _toggleLock,
          ),
          if (AppSettings.pinHash != null) SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('Fingerprint unlock')),
            subtitle: Text('PIN အစား လက်ဗွေ/မျက်နှာနဲ့ ဖွင့်'),
            value: AppSettings.biometric,
            onChanged: _toggleBio,
          ),
          Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('Alerts (notification)')),
            subtitle: Text('Server offline ဖြစ်ရင်၊ user ကုန်ခါနီး/Data ၉၀% ကျော်ရင် ၁၅ မိနစ်တစ်ခါ စစ်ပြီး အသိပေး'),
            value: AppSettings.alertsOn,
            onChanged: _toggleAlerts,
          ),
          if (AppSettings.alertsOn) Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () async { try { await sendTestNotification(); } catch (e) { _toast('$e'); } },
            icon: Icon(Icons.notifications_active), label: Text(t('Test notification')))),
          Divider(height: 32),
          Text(t('Message template'), style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 4),
          Text('ထည့်လို့ရတဲ့ စာလုံးတွေ: {name} {username} {link} {gb} {expire} {days}', style: TextStyle(fontSize: 12)),
          SizedBox(height: 8),
          TextField(controller: tpl, maxLines: 9, decoration: InputDecoration(border: OutlineInputBorder())),
          SizedBox(height: 8),
          Row(children: [
            OutlinedButton(onPressed: () { tpl.text = defaultTemplate; }, child: Text(t('Default'))),
            SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () async { await AppSettings.setTemplate(tpl.text); _toast('Saved'); }, child: Text(t('Save template')))),
          ]),
          Divider(height: 32),
          Text('Reminder template (သက်တမ်းကုန်ခါနီး သတိပေးစာ)', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 4),
          Text('ထည့်လို့ရတဲ့ စာလုံးတွေ: {name} {username} {link} {gb} {expire} {days}', style: TextStyle(fontSize: 12)),
          SizedBox(height: 8),
          TextField(controller: remind, maxLines: 6, decoration: InputDecoration(border: OutlineInputBorder())),
          SizedBox(height: 8),
          Row(children: [
            OutlinedButton(onPressed: () { remind.text = defaultRemind; }, child: Text(t('Default'))),
            SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: () async { await AppSettings.setRemindTemplate(remind.text); _toast('Saved'); }, child: Text(t('Save reminder')))),
          ]),
        ]),
      );
}
