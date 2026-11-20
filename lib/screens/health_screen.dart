import '../i18n.dart';
import 'package:flutter/material.dart';
import '../health.dart';
import '../models.dart';

class HealthScreen extends StatefulWidget {
  final ServerConfig server;
  const HealthScreen({super.key, required this.server});
  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  List<HealthSample>? samples;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final l = await HealthStore.load(widget.server.id);
    if (mounted) setState(() => samples = l);
  }

  String _t(int ts) => DateTime.fromMillisecondsSinceEpoch(ts * 1000).toString().substring(5, 16);

  @override
  Widget build(BuildContext context) {
    final l = samples;
    return Scaffold(
      appBar: AppBar(title: Text('Health - ${widget.server.name}'), actions: [IconButton(onPressed: _load, icon: Icon(Icons.refresh))]),
      body: l == null
          ? Center(child: CircularProgressIndicator())
          : l.isEmpty
              ? Center(child: Padding(padding: EdgeInsets.all(24), child: Text(
                  'မှတ်တမ်း မရှိသေးပါ။\nHome ကို ဖွင့်ရင် (သို့) Alerts ဖွင့်ထားရင် အလိုအလျောက် မှတ်သွားမယ်။', textAlign: TextAlign.center)))
              : ListView(padding: EdgeInsets.all(12), children: _body(l)),
    );
  }

  List<Widget> _body(List<HealthSample> l) {
    final okN = l.where((s) => s.ok).length;
    final up = okN / l.length * 100;
    final ok = l.where((s) => s.ok).toList();
    // offline periods = runs of failed samples
    final events = <String>[];
    int? start, last;
    for (final s in l) {
      if (!s.ok) { start ??= s.ts; last = s.ts; }
      else if (start != null) { events.add('${_t(start)} → ${_t(s.ts)}'); start = null; }
    }
    if (start != null) events.add('${_t(start)} → ယခု (offline ဆက်ဖြစ်နေ)');
    return [
      Card(child: Padding(padding: EdgeInsets.all(14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _big('Uptime', '${up.toStringAsFixed(1)}%', up > 99 ? Colors.green : Colors.orange),
        _big('Samples', '${l.length}', null),
        _big('Offline', '${l.length - okN}', l.length - okN > 0 ? Colors.red : null),
      ]))),
      Text('${_t(l.first.ts)}  →  ${_t(l.last.ts)}', style: TextStyle(fontSize: 12)),
      SizedBox(height: 8),
      _chart('CPU %', [for (final s in l) s.ok ? s.cpu : null], Colors.indigo, max: 100),
      _chart('RAM %', [for (final s in l) s.ok ? s.mem : null], Colors.teal, max: 100),
      _chart('Online users', [for (final s in l) s.ok ? s.online.toDouble() : null], Colors.orange),
      if (ok.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4), child: Text(
          'Users: ${ok.last.users}  •  Online now: ${ok.last.online}', style: TextStyle(fontSize: 12))),
      SizedBox(height: 12),
      Text(t('Offline events'), style: Theme.of(context).textTheme.titleMedium),
      if (events.isEmpty) Padding(padding: EdgeInsets.all(8), child: Text('မရှိပါ ✓')),
      for (final e in events.reversed.take(20)) ListTile(dense: true, leading: Icon(Icons.error_outline, color: Colors.red), title: Text(e)),
    ];
  }

  Widget _big(String k, String v, Color? c) => Column(children: [
        Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
        Text(t(k), style: TextStyle(fontSize: 12)),
      ]);

  Widget _chart(String title, List<double?> v, Color c, {double? max}) {
    final vals = v.whereType<double>().toList();
    final hi = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a > b ? a : b);
    final avg = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t(title), style: TextStyle(fontWeight: FontWeight.w600))),
          Text('avg ${avg.toStringAsFixed(1)}  max ${hi.toStringAsFixed(1)}', style: TextStyle(fontSize: 12)),
        ]),
        SizedBox(height: 4),
        SizedBox(height: 90, width: double.infinity, child: CustomPaint(painter: _LinePainter(v, c, max ?? (hi < 5 ? 5 : hi * 1.15), Theme.of(context).dividerColor))),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double?> v;
  final Color color, grid;
  final double maxY;
  _LinePainter(this.v, this.color, this.maxY, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    final gp = Paint()..color = grid..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
    if (v.length < 2) return;
    final dx = size.width / (v.length - 1);
    final lp = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    final dead = Paint()..color = Colors.red.withOpacity(0.6)..strokeWidth = 2;
    final path = Path();
    var pen = false;
    for (var i = 0; i < v.length; i++) {
      final x = i * dx;
      final val = v[i];
      if (val == null) {
        pen = false;
        canvas.drawLine(Offset(x, size.height - 8), Offset(x, size.height), dead); // offline tick
        continue;
      }
      final y = size.height - (val / maxY).clamp(0.0, 1.0) * size.height;
      if (!pen) { path.moveTo(x, y); pen = true; } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, lp);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.v != v || old.maxY != maxY;
}
