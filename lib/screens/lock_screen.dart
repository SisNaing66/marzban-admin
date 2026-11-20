import '../i18n.dart';
import 'package:flutter/material.dart';
import '../biometric.dart';
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
    if (authRecently()) { pausedAt = null; return; } // fingerprint dialog, not a real background
    if (s == AppLifecycleState.paused) pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed) {
      final p = pausedAt;
      pausedAt = null;
      if (!locked && AppSettings.pinHash != null && p != null && DateTime.now().difference(p).inSeconds >= 30) {
        setState(() => locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      locked ? _LockScreen(onUnlock: () => setState(() => locked = false)) : widget.child;
}

class _LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  _LockScreen({required this.onUnlock});
  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final c = TextEditingController();
  String? err;

  @override
  void initState() {
    super.initState();
    if (AppSettings.biometric) WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
  }

  Future<void> _bio() async {
    if (!mounted) return;
    if (await biometricAuth('Marzban Admin ကို ဖွင့်ရန်') && mounted) widget.onUnlock();
  }

  void _try() {
    if (AppSettings.checkPin(c.text)) { widget.onUnlock(); }
    else { setState(() { err = 'PIN မှားနေပါတယ်'; c.clear(); }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock, size: 56),
          SizedBox(height: 16),
          Text('PIN ရိုက်ထည့်ပါ', style: TextStyle(fontSize: 18)),
          SizedBox(height: 16),
          TextField(
            controller: c, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8,
            textAlign: TextAlign.center, onSubmitted: (_) => _try(),
            decoration: InputDecoration(errorText: err, border: OutlineInputBorder(), counterText: '')),
          SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _try, child: Text(t('Unlock')))),
          if (AppSettings.biometric) TextButton.icon(onPressed: _bio, icon: Icon(Icons.fingerprint), label: Text('လက်ဗွေနဲ့ ဖွင့်')),
        ])))),
      );
}
