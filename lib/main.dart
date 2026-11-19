import 'package:flutter/material.dart';
import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  runApp(const MarzbanAdminApp());
}

class MarzbanAdminApp extends StatelessWidget {
  const MarzbanAdminApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettings.themeMode,
        builder: (_, mode, __) => MaterialApp(
          title: 'Marzban Admin',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
          darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, useMaterial3: true),
          home: const AppLockGate(child: HomeShell()),
        ),
      );
}
