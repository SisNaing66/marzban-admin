import 'package:flutter/material.dart';
import 'screens/server_list_screen.dart';

void main() => runApp(const MarzbanAdminApp());

class MarzbanAdminApp extends StatelessWidget {
  const MarzbanAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Marzban Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, useMaterial3: true),
        home: const ServerListScreen(),
      );
}
