import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'server_list_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final dashKey = GlobalKey<DashboardScreenState>();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: tab, children: [
          DashboardScreen(key: dashKey),
          const ServerListScreen(),
          const MoreScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) {
            if (i == 0 && tab != 0) dashKey.currentState?.refresh();
            setState(() => tab = i);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.dns), label: 'Servers'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      );
}
