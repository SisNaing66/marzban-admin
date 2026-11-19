import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';

/// Asks for days / GB and renews the user. Returns true if something was changed.
Future<bool> showRenewDialog(BuildContext context, MarzbanApi api, VpnUser u) async {
  final messenger = ScaffoldMessenger.of(context);
  final days = TextEditingController(text: u.expire == null || u.expire == 0 ? '0' : '30');
  final gb = TextEditingController(text: u.dataLimit > 0 ? '50' : '0');
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Renew ${u.username}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
            controller: days, keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'Add days', helperText: u.expire == null || u.expire == 0 ? 'No expiry set - unchanged' : null)),
        TextField(
            controller: gb, keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: 'Add GB', helperText: u.dataLimit == 0 ? 'Unlimited data - unchanged' : null)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Renew')),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await api.renew(u, days: int.tryParse(days.text.trim()) ?? 0, gb: double.tryParse(gb.text.trim()) ?? 0);
    messenger.showSnackBar(SnackBar(content: Text('${u.username} renewed')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(MarzbanApi.errorText(e))));
    return false;
  }
}
