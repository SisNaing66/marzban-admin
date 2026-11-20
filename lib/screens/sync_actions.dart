import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../storage.dart';

class _Result {
  int created = 0, skipped = 0, failed = 0;
  final errors = <String>[];
}

/// Creates one user on [target] from [u] (a user JSON read from another server). Keeps username,
/// proxy ids/passwords (so client links keep working), expiry, limit, reset strategy, note, disabled state.
Future<void> createLike(MarzbanApi target, Map<String, dynamic> u, Map<String, List<String>> tags) async {
  final name = (u['username'] ?? '').toString();
  final srcProxies = Map<String, dynamic>.from(u['proxies'] ?? {});
  final srcInbounds = Map<String, dynamic>.from(u['inbounds'] ?? {});
  final proxies = <String, dynamic>{};
  final inbounds = <String, List<String>>{};
  srcProxies.forEach((proto, settings) {
    final tgt = tags[proto];
    if (tgt == null || tgt.isEmpty) return; // protocol not available on target
    final wanted = List<String>.from(srcInbounds[proto] ?? const []);
    final use = wanted.isEmpty ? tgt : tgt.where(wanted.contains).toList();
    inbounds[proto] = use.isEmpty ? tgt : use;
    proxies[proto] = settings ?? {};
  });
  if (proxies.isEmpty) throw 'no matching protocol on target';
  await target.createUserBody({
    'username': name,
    'proxies': proxies,
    'inbounds': inbounds,
    'expire': u['expire'] ?? 0,
    'data_limit': u['data_limit'] ?? 0,
    'data_limit_reset_strategy': u['data_limit_reset_strategy'] ?? 'no_reset',
    'status': 'active',
    'note': u['note'] ?? '',
  });
  if (u['status'] == 'disabled') await target.updateUser(name, {'status': 'disabled'});
}

/// Creates every user in [rawUsers] that does not already exist on [target].
/// Keeps username, proxy ids/passwords (so existing client links keep working),
/// expiry, data limit, reset strategy, note and disabled state.
Future<_Result> _copyUsers(MarzbanApi target, List<Map<String, dynamic>> rawUsers, ValueNotifier<String> progress) async {
  final res = _Result();
  progress.value = 'Reading target server...';
  final existing = (await target.users()).map((u) => u.username.toLowerCase()).toSet();
  final tags = await target.inboundTags();
  var i = 0;
  for (final u in rawUsers) {
    i++;
    final name = (u['username'] ?? '').toString();
    progress.value = '$i / ${rawUsers.length}  $name';
    if (existing.contains(name.toLowerCase())) { res.skipped++; continue; }
    try {
      await createLike(target, u, tags);
      res.created++;
    } catch (e) {
      res.failed++;
      res.errors.add('$name: ${e is String ? e : MarzbanApi.errorText(e)}');
    }
  }
  return res;
}

Future<void> _runWithProgress(BuildContext context, String title, Future<_Result> Function(ValueNotifier<String>) job) async {
  final progress = ValueNotifier<String>('Starting...');
  showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
          const LinearProgressIndicator(), const SizedBox(height: 12), Text(v)]),
      ),
    ),
  );
  _Result? r;
  String? fatal;
  try { r = await job(progress); } catch (e) { fatal = MarzbanApi.errorText(e); }
  if (!context.mounted) return;
  Navigator.pop(context); // close progress
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(fatal != null ? 'Failed' : 'Done'),
      content: SingleChildScrollView(child: Text(fatal ??
          'Created: ${r!.created}\nAlready existed (skipped): ${r.skipped}\nFailed: ${r.failed}'
          '${r.errors.isEmpty ? '' : '\n\n${r.errors.take(10).join('\n')}'}')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
    ),
  );
}

/// Copy all users of another saved server into this one.
Future<void> mergeUsers(BuildContext context, MarzbanApi target) async {
  final others = (await Storage.load()).where((s) => s.id != target.server.id).toList();
  if (!context.mounted) return;
  if (others.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other servers available to merge from.')));
    return;
  }
  final src = await showDialog<ServerConfig>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text('Merge into "${target.server.name}" from:'),
      children: [for (final s in others) SimpleDialogOption(onPressed: () => Navigator.pop(c, s), child: Text(s.name))],
    ),
  );
  if (src == null || !context.mounted) return;
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: const Text('Merge Users?'),
    content: Text('Users from "${src.name}" that do not exist yet will be created on "${target.server.name}". Existing users are not changed.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Merge')),
    ],
  ));
  if (ok != true || !context.mounted) return;
  await _runWithProgress(context, 'Merging users', (p) async {
    p.value = 'Reading ${src.name}...';
    final users = (await MarzbanApi(src).users()).map((u) => u.raw).toList();
    return _copyUsers(target, users, p);
  });
}

Future<void> backupNow(BuildContext context, MarzbanApi api) async {
  final m = ScaffoldMessenger.of(context);
  try {
    final users = (await api.users()).map((u) => u.raw).toList();
    await Storage.saveBackup(api.server.id, users);
    m.showSnackBar(SnackBar(content: Text('Backed up ${users.length} users')));
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text('Backup failed: ${MarzbanApi.errorText(e)}')));
  }
}

/// Re-create users from the last local backup (e.g. after reinstalling an empty Marzban).
Future<void> restoreUsers(BuildContext context, MarzbanApi api) async {
  final b = await Storage.loadBackup(api.server.id);
  if (!context.mounted) return;
  if (b == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No backup found for this server')));
    return;
  }
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: const Text('Restore Users?'),
    content: Text('Restore ${b.users.length} users from the backup made on '
        '${b.time.toString().substring(0, 16)} to "${api.server.name}"?\n\n'
        '(Use this only if you reinstalled an empty Marzban server.) Existing users are skipped.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
    ],
  ));
  if (ok != true || !context.mounted) return;
  await _runWithProgress(context, 'Restoring users', (p) => _copyUsers(api, b.users, p));
}

/// Restore users from an in-memory list (e.g. an imported backup file). Existing users are skipped.
Future<void> restoreUsersFromList(BuildContext context, MarzbanApi api, List<Map<String, dynamic>> users, String what) async {
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: const Text('Restore Users?'),
    content: Text('Restore ${users.length} users ($what) to "${api.server.name}"? Existing users are skipped.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
    ],
  ));
  if (ok != true || !context.mounted) return;
  await _runWithProgress(context, 'Restoring users', (p) => _copyUsers(api, users, p));
}
