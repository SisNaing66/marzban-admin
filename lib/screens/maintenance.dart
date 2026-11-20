import '../i18n.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../bulk.dart';
import '../models.dart';

/// Delete users that have been expired for more than N days.
Future<void> cleanExpired(BuildContext context, MarzbanApi api) async {
  final days = TextEditingController(text: '30');
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Text(t('Clean expired users')),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('သက်တမ်းကုန်ပြီး အနည်းဆုံး ဒီရက်အရေအတွက် ကျော်သွားသူတွေကို ရှာမယ်'),
      TextField(controller: days, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('Expired for more than (days)'))),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Cancel'))),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Find'))),
    ],
  ));
  if (ok != true || !context.mounted) return;
  final n = int.tryParse(days.text.trim()) ?? 30;
  final messenger = ScaffoldMessenger.of(context);
  List<VpnUser> victims;
  try {
    final cutoff = DateTime.now().subtract(Duration(days: n));
    victims = (await api.users(status: 'expired')).where((u) => u.expireDate != null && u.expireDate!.isBefore(cutoff)).toList();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(MarzbanApi.errorText(e))));
    return;
  }
  if (!context.mounted) return;
  if (victims.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(t('No users found'))));
    return;
  }
  final sample = victims.take(8).map((u) => u.username).join(', ');
  final go = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Text('Delete ${victims.length} users?'),
    content: Text('$sample${victims.length > 8 ? ' ...' : ''}\n\nဒီလုပ်ရပ်ကို ပြန်ပြင်လို့ မရပါ။'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Cancel'))),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Delete'))),
    ],
  ));
  if (go != true || !context.mounted) return;
  final r = await runBulk<VpnUser>(context, 'Deleting', victims, (u) => u.username, (u) => api.deleteUser(u.username));
  if (context.mounted) await showBulkResult(context, 'Clean result', r);
}
