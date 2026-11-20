import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'api.dart';
import 'health.dart';
import 'models.dart';
import 'settings.dart';
import 'storage.dart';
import 'telegram.dart';

const _taskName = 'marzban-check';
final _plugin = FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() => _plugin.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));

/// Local notification + (optionally) the same text to the Telegram bot.
Future<void> _notify(int id, String title, String body) async {
  try {
    await _plugin.show(
        id, title, body,
        const NotificationDetails(
            android: AndroidNotificationDetails('alerts', 'Alerts',
                channelDescription: 'Server offline and user expiry alerts',
                importance: Importance.high, priority: Priority.high)));
  } catch (_) {}
  if (AppSettings.tgAlerts && AppSettings.tgReady) {
    try { await Telegram.send(AppSettings.tgToken, AppSettings.tgChat, '$title\n$body'); } catch (_) {}
  }
}

String _stamp() => DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

Future<void> _sendBackup(ServerConfig s, List<VpnUser> users) => Telegram.sendFile(
    AppSettings.tgToken, AppSettings.tgChat,
    utf8.encode(const JsonEncoder.withIndent(' ').convert({
      'type': 'marzban-users', 'version': 1, 'server': s.name, 'time': DateTime.now().toIso8601String(),
      'users': users.map((u) => u.raw).toList(),
    })),
    'marzban-users-${_safe(s.name)}-${_stamp()}.json',
    '${s.name}: ${users.length} users');

/// Runs in a background isolate every ~15 minutes (Android's minimum).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try { await runChecks(); } catch (_) {}
    return true;
  });
}

Future<void> runChecks() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await _initNotifications();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  await AppSettings.load();
  final servers = await Storage.load();
  final state = Map<String, dynamic>.from(jsonDecode(prefs.getString('bg_state') ?? '{}'));
  final now = DateTime.now().millisecondsSinceEpoch;

  for (var i = 0; i < servers.length; i++) {
    final s = servers[i];
    final st = Map<String, dynamic>.from(state[s.id] ?? {});
    final api = MarzbanApi(s);
    Map<String, dynamic>? sys;
    try {
      sys = await api.system().timeout(const Duration(seconds: 20));
    } catch (_) {}
    try { await HealthStore.add(s.id, HealthSample.fromSystem(sys)); } catch (_) {}

    if (sys == null) {
      final fails = ((st['fails'] ?? 0) as int) + 1;
      st['fails'] = fails;
      // 2 failures in a row (15-30 min) -> alert once
      if (fails >= 2 && st['down'] != true) {
        st['down'] = true;
        await _notify(1000 + i * 3, '${s.name} OFFLINE', 'Server ကို ချိတ်ဆက်လို့ မရတော့ပါ');
      }
    } else {
      st['fails'] = 0;
      if (st['down'] == true) {
        st['down'] = false;
        await _notify(1001 + i * 3, '${s.name} back online', 'Server ပြန်ရောက်လာပြီ');
      }
      final summaryDue = now - ((st['summary'] ?? 0) as int) > 20 * 3600 * 1000;
      final backupDue = AppSettings.tgBackup && AppSettings.tgReady && now - ((st['backup'] ?? 0) as int) > 23 * 3600 * 1000;
      if (summaryDue || backupDue) {
        try {
          final List<VpnUser> users = await api.users().timeout(const Duration(seconds: 60));
          if (summaryDue) {
            final exp = users.where((u) => u.expiringSoon).length;
            final near = users.where((u) => u.nearLimit).length;
            if (exp > 0 || near > 0) {
              await _notify(1002 + i * 3, s.name, '၃ ရက်အတွင်း ကုန်မယ့် user $exp ယောက်၊ Data ၉၀% ကျော် $near ယောက်');
              st['summary'] = now;
            }
          }
          if (backupDue && users.isNotEmpty) {
            await _sendBackup(s, users);
            st['backup'] = now;
          }
        } catch (_) {}
      }
    }
    state[s.id] = st;
  }
  await prefs.setString('bg_state', jsonEncode(state));
}

Future<void> initBackground() => Workmanager().initialize(callbackDispatcher);

/// Asks for notification permission and schedules the periodic check. Returns false if permission was refused.
Future<bool> enableAlerts() async {
  await _initNotifications();
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  final granted = await android?.requestNotificationsPermission() ?? true;
  if (!granted) return false;
  await Workmanager().registerPeriodicTask(_taskName, _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected));
  return true;
}

Future<void> disableAlerts() => Workmanager().cancelByUniqueName(_taskName);

Future<void> sendTestNotification() async {
  await _initNotifications();
  await _notify(999, 'Marzban Admin', 'Notification အလုပ်လုပ်ပါတယ် ✓');
}

/// Sends every server's users file to the Telegram bot right now. Returns a short summary.
Future<String> telegramBackupAll() async {
  if (!AppSettings.tgReady) throw 'Telegram token / chat id မထည့်ရသေးပါ';
  final servers = await Storage.load();
  var ok = 0;
  final errs = <String>[];
  for (final s in servers) {
    try {
      final users = await MarzbanApi(s).users();
      await _sendBackup(s, users);
      ok++;
    } catch (e) {
      errs.add('${s.name}: ${e is String ? e : (MarzbanApi.errorText(e))}');
    }
  }
  return 'ပို့ပြီး $ok/${servers.length}${errs.isEmpty ? '' : '\n${errs.join('\n')}'}';
}
