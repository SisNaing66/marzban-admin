import 'package:flutter/material.dart';
import '../settings.dart';

/// Shows [child] normally; shows a PIN screen at start and after the app was in the background for 30s.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});
  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool locked = AppSettings.pinHash != null;
  DateTime? pausedAt;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed && AppSettings.pinHash != null && pausedAt != null &&
        DateTime.now().difference(pausedAt!).inSeconds >= 30) {
      setState(() => locked = true);
    }
  }

  @override
  Widget build(BuildContext context) =>
      locked ? _LockScreen(onUnlock: () => setState(() => locked = false)) : widget.child;
}

class _LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const _LockScreen({required this.onUnlock});
  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final c = TextEditingController();
  String? err;

  void _try() {
    if (AppSettings.checkPin(c.text)) { widget.onUnlock(); }
    else { setState(() { err = 'PIN မှားနေပါတယ်'; c.clear(); }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock, size: 56),
          const SizedBox(height: 16),
          const Text('PIN ရိုက်ထည့်ပါ', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: c, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8,
            textAlign: TextAlign.center, onSubmitted: (_) => _try(),
            decoration: InputDecoration(errorText: err, border: const OutlineInputBorder(), counterText: '')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _try, child: const Text('Unlock'))),
        ])))),
      );
}
