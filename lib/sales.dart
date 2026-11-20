import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Sale {
  final int ts; // unix seconds
  final String server, user, kind; // kind: create | renew
  final int days;
  final double gb, amount;
  final bool paid;
  Sale({required this.ts, required this.server, required this.user, required this.kind,
      this.days = 0, this.gb = 0, required this.amount, this.paid = true});

  Sale copyWith({bool? paid}) => Sale(ts: ts, server: server, user: user, kind: kind, days: days, gb: gb, amount: amount, paid: paid ?? this.paid);

  Map<String, dynamic> toJson() => {'ts': ts, 'server': server, 'user': user, 'kind': kind, 'days': days, 'gb': gb, 'amount': amount, 'paid': paid};
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
      ts: (j['ts'] as num).toInt(), server: j['server'] ?? '', user: j['user'] ?? '', kind: j['kind'] ?? '',
      days: (j['days'] ?? 0).toInt(), gb: (j['gb'] ?? 0).toDouble(), amount: (j['amount'] ?? 0).toDouble(), paid: j['paid'] != false);
}

class SalesStore {
  static const _k = 'sales';

  static Future<List<Sale>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Sale.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> replaceAll(List<Sale> l) async {
    final p = await SharedPreferences.getInstance();
    if (l.length > 5000) l = l.sublist(l.length - 5000);
    await p.setString(_k, jsonEncode(l.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(List<Sale> more) async => replaceAll([...await load(), ...more]);
}
