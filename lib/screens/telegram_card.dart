import 'package:flutter/material.dart';
import '../background.dart';
import '../settings.dart';
import '../telegram.dart';

/// Telegram bot settings (token + chat id stay on this phone only).
class TelegramCard extends StatefulWidget {
  const TelegramCard({super.key});
  @override
  State<TelegramCard> createState() => _TelegramCardState();
}

class _TelegramCardState extends State<TelegramCard> {
  late final token = TextEditingController(text: AppSettings.tgToken);
  late final chat = TextEditingController(text: AppSettings.tgChat);
  late bool alerts = AppSettings.tgAlerts;
  late bool backup = AppSettings.tgBackup;
  bool busy = false;
  bool hideToken = true;

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    await AppSettings.saveTelegram(token: token.text, chat: chat.text, alerts: alerts, backup: backup);
  }

  Future<void> _run(Future<String> Function() job) async {
    setState(() => busy = true);
    try {
      await _save();
      _toast(await job());
    } catch (e) {
      _toast(e is String ? e : Telegram.errorText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Telegram bot', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Alerts နဲ့ backup ဖိုင်ကို Telegram ကို ပို့မယ်။ Token ကို ဒီဖုန်းထဲမှာပဲ သိမ်းတယ်။', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: token, obscureText: hideToken, autocorrect: false, enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Bot token', border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: Icon(hideToken ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hideToken = !hideToken))),
        ),
        const SizedBox(height: 8),
        TextField(controller: chat, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Chat id', border: OutlineInputBorder())),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Alerts ကို Telegram ကိုပါ ပို့'), value: alerts, onChanged: (v) { setState(() => alerts = v); _save(); }),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Backup ဖိုင်ကို တစ်ရက်တစ်ခါ ပို့'), subtitle: const Text('Alerts (background check) ဖွင့်ထားမှ အလုပ်လုပ်မယ်'), value: backup, onChanged: (v) { setState(() => backup = v); _save(); }),
        Wrap(spacing: 8, children: [
          FilledButton.icon(
            onPressed: busy ? null : () => _run(() async {
              await Telegram.send(AppSettings.tgToken, AppSettings.tgChat, 'Marzban Admin ✓ Telegram ချိတ်ဆက်မှု အောင်မြင်ပါတယ်');
              return 'Test စာ ပို့ပြီး';
            }),
            icon: const Icon(Icons.send), label: const Text('Test')),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _run(telegramBackupAll),
            icon: const Icon(Icons.cloud_upload), label: const Text('Backup now')),
        ]),
        if (busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      ]);
}
