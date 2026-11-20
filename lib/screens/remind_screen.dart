import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../settings.dart';
import '../share_util.dart';

/// One-tap renewal reminders for customers whose plan is about to end.
class RemindScreen extends StatefulWidget {
  final MarzbanApi api;
  final List<VpnUser> users;
  const RemindScreen({super.key, required this.api, required this.users});
  @override
  State<RemindScreen> createState() => _RemindScreenState();
}

class _RemindScreenState extends State<RemindScreen> {
  final sent = <String>{};

  String _link(VpnUser u) {
    final s = u.subscriptionUrl;
    return s.startsWith('/') ? '${widget.api.server.baseUrl}$s' : s;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Remind (${widget.users.length})')),
        body: ListView.builder(
          itemCount: widget.users.length,
          itemBuilder: (_, i) {
            final u = widget.users[i];
            final contact = AppSettings.contacts[AppSettings.contactKey(widget.api.server.id, u.username)];
            final left = u.daysLeft;
            final done = sent.contains(u.username);
            return ListTile(
              leading: CircleAvatar(child: Icon(done ? Icons.check : Icons.schedule)),
              title: Text(u.username),
              subtitle: Text('${left == null ? '' : '$left ရက်ကျန်  •  '}${contact ?? 'contact မထည့်ရသေး'}'),
              trailing: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  await shareReminder(u, _link(u));
                  if (mounted) setState(() => sent.add(u.username));
                },
              ),
            );
          },
        ),
      );
}
