import 'package:flutter/material.dart';
import 'background.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  try { await initBackground(); } catch (_) {}
  runApp(const MarzbanAdminApp());
}

class MarzbanAdminApp extends StatelessWidget {
  const MarzbanAdminApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: AppSettings.lang,
        builder: (_, lang, __) => ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.themeMode,
          builder: (_, mode, __) => MaterialApp(
            title: 'Marzban Admin',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
            darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, useMaterial3: true),
            // the key rebuilds every screen when the language changes (the lock gate is kept)
            home: AppLockGate(child: KeyedSubtree(key: ValueKey(lang), child: HomeShell())),
          ),
        ),
      );
}
