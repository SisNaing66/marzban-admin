import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';

class BulkResult {
  int ok = 0, failed = 0;
  final errors = <String>[];
}

/// Runs [job] for every item (4 at a time) behind a progress dialog.
Future<BulkResult> runBulk<T>(BuildContext context, String title, List<T> items, String Function(T) label,
    Future<void> Function(T) job, {int parallel = 4}) async {
  final progress = ValueNotifier<String>('0 / ${items.length}');
  showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => PopScope(canPop: false, child: AlertDialog(
      title: Text(title),
      content: ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
          const LinearProgressIndicator(), const SizedBox(height: 12), Text(v)]),
      ),
    )),
  );
  final res = BulkResult();
  var done = 0, next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= items.length) return;
      final it = items[i];
      try {
        await job(it);
        res.ok++;
      } catch (e) {
        res.failed++;
        res.errors.add('${label(it)}: ${e is String ? e : MarzbanApi.errorText(e)}');
      }
      done++;
      progress.value = '$done / ${items.length}';
    }
  }
  final n = items.isEmpty ? 1 : (parallel < items.length ? parallel : items.length);
  await Future.wait(List.generate(n, (_) => worker()));
  if (context.mounted) Navigator.pop(context);
  return res;
}

Future<void> showBulkResult(BuildContext context, String title, BulkResult r, {String? extra}) {
  return showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('OK: ${r.ok}    Failed: ${r.failed}'),
        if (r.errors.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(r.errors.take(10).join('\n'), style: const TextStyle(color: Colors.red, fontSize: 12))),
        if (extra != null) Padding(padding: const EdgeInsets.only(top: 8), child: SelectableText(extra, style: const TextStyle(fontSize: 12))),
      ])),
      actions: [
        if (extra != null) TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: extra)), child: const Text('Copy')),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
      ],
    ),
  );
}
