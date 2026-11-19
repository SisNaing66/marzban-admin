import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'api.dart';
import 'models.dart';
import 'storage.dart';

const _taskName = 'marzban-check';
final _plugin = FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() => _plugin.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));

Future<void> _notify(int id, String title, String body) => _plugin.show(
    id, title, body,
    const NotificationDetails(
        android: AndroidNotificationDetails('alerts', 'Alerts',
            channelDescription: 'Server offline and user expiry alerts',
            importance: Importance.high, priority: Priority.high)));

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
  final servers = await Storage.load();
  final state = Map<String, dynamic>.from(jsonDecode(prefs.getString('bg_state') ?? '{}'));
  final now = DateTime.now().millisecondsSinceEpoch;

  for (var i = 0; i < servers.length; i++) {
    final s = servers[i];
    final st = Map<String, dynamic>.from(state[s.id] ?? {});
    final api = MarzbanApi(s);
    var down = false;
    try {
      await api.system().timeout(const Duration(seconds: 20));
    } catch (_) {
      down = true;
    }

    if (down) {
      final fails = (st['fails'] ?? 0) + 1;
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
      // daily summary of expiring / near-limit users
      final last = (st['summary'] ?? 0) as int;
      if (now - last > 20 * 3600 * 1000) {
        try {
          final List<VpnUser> users = await api.users().timeout(const Duration(seconds: 40));
          final exp = users.where((u) => u.expiringSoon).length;
          final near = users.where((u) => u.nearLimit).length;
          if (exp > 0 || near > 0) {
            await _notify(1002 + i * 3, s.name, '၃ ရက်အတွင်း ကုန်မယ့် user $exp ယောက်၊ Data ၉၀% ကျော် $near ယောက်');
            st['summary'] = now;
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
