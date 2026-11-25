import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../guide_data.dart';
import '../i18n.dart';

class GuideListScreen extends StatelessWidget {
  GuideListScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('How to run'))),
        body: ListView(padding: EdgeInsets.all(12), children: [
          for (final g in guides)
            Card(
              child: ListTile(
                leading: Icon(Icons.menu_book),
                title: Text(g.title),
                subtitle: Text('${g.summary}\n${g.steps.length} အဆင့်'),
                isThreeLine: true,
                trailing: Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: g))),
              ),
            ),
        ]),
      );
}

class GuideDetailScreen extends StatefulWidget {
  final Guide guide;
  GuideDetailScreen({super.key, required this.guide});
  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  final pc = PageController();
  int page = 0;

  @override
  void dispose() { pc.dispose(); super.dispose(); }

  void _go(int i) => pc.animateToPage(i, duration: Duration(milliseconds: 250), curve: Curves.easeOut);

  Widget _step(GuideStep s, int i, int n) => SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('အဆင့် ${i + 1} / $n', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          SizedBox(height: 4),
          Text(s.title, style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 12),
          if (s.image != null)
            GestureDetector(
              onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                      insetPadding: EdgeInsets.all(8),
                      child: InteractiveViewer(child: Image.asset('assets/guide/${s.image}')))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/guide/${s.image}', width: double.infinity, fit: BoxFit.fitWidth,
                    errorBuilder: (_, __, ___) => Container(
                        height: 120, alignment: Alignment.center,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Text('ပုံ မတွေ့ပါ: ${s.image}'))),
              ),
            ),
          if (s.image != null) SizedBox(height: 12),
          SelectableText(s.text, style: TextStyle(fontSize: 15, height: 1.5)),
          if (s.script != null) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
              child: SelectableText(s.script!, style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(Icons.copy, size: 16),
                label: Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: s.script!));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copy ကူးပြီးပါပြီ')));
                },
              ),
            ),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final steps = widget.guide.steps;
    return Scaffold(
      appBar: AppBar(title: Text(widget.guide.title)),
      body: Column(children: [
        LinearProgressIndicator(value: (page + 1) / steps.length),
        Expanded(
          child: PageView.builder(
            controller: pc,
            itemCount: steps.length,
            onPageChanged: (i) => setState(() => page = i),
            itemBuilder: (_, i) => _step(steps[i], i, steps.length),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              OutlinedButton(onPressed: page > 0 ? () => _go(page - 1) : null, child: Text('နောက်သို့')),
              Spacer(),
              if (page < steps.length - 1)
                FilledButton(onPressed: () => _go(page + 1), child: Text('ရှေ့ဆက်'))
              else
                FilledButton(onPressed: () => Navigator.pop(context), child: Text('ပြီးပါပြီ')),
            ]),
          ),
        ),
      ]),
    );
  }
}
