import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api.dart';

/// Live Xray core log from the panel's websocket (/api/core/logs).
class LogsScreen extends StatefulWidget {
  final MarzbanApi api;
  const LogsScreen({super.key, required this.api});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final lines = <String>[];
  WebSocketChannel? ch;
  StreamSubscription? sub;
  String? err;
  bool paused = false;
  final scroll = ScrollController();

  @override
  void initState() { super.initState(); _connect(); }

  @override
  void dispose() { sub?.cancel(); ch?.sink.close(); scroll.dispose(); super.dispose(); }

  Future<void> _connect() async {
    try {
      final token = await widget.api.accessToken();
      final base = Uri.parse(widget.api.server.baseUrl);
      final uri = Uri(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: '${base.path}/api/core/logs'.replaceAll('//', '/'),
        queryParameters: {'interval': '1', 'token': token},
      );
      ch = WebSocketChannel.connect(uri);
      sub = ch!.stream.listen((m) {
        if (paused || !mounted) return;
        setState(() {
          lines.addAll(m.toString().split('\n').where((l) => l.trim().isNotEmpty));
          if (lines.length > 500) lines.removeRange(0, lines.length - 500);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
        });
      }, onError: (e) { if (mounted) setState(() => err = '$e'); },
         onDone: () { if (mounted && err == null && lines.isEmpty) setState(() => err = 'Log connection ပိတ်သွားပါပြီ'); });
    } catch (e) {
      if (mounted) setState(() => err = e is String ? e : MarzbanApi.errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Core logs'), actions: [
          IconButton(tooltip: paused ? 'Resume' : 'Pause', icon: Icon(paused ? Icons.play_arrow : Icons.pause), onPressed: () => setState(() => paused = !paused)),
          IconButton(tooltip: 'Copy', icon: const Icon(Icons.copy), onPressed: () => Clipboard.setData(ClipboardData(text: lines.join('\n')))),
          IconButton(tooltip: 'Clear', icon: const Icon(Icons.delete_outline), onPressed: () => setState(lines.clear)),
        ]),
        body: err != null && lines.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Log မရပါ: $err', textAlign: TextAlign.center)))
            : lines.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scroll, padding: const EdgeInsets.all(8), itemCount: lines.length,
                    itemBuilder: (_, i) => Text(lines[i], style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
      );
}
