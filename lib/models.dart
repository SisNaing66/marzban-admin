class ServerConfig {
  final String id;
  String name, url, username, password;
  ServerConfig({required this.id, required this.name, required this.url, required this.username, required this.password});

  /// Cleans common typing mistakes: missing scheme, "/8000" instead of ":8000",
  /// trailing "/", "/dashboard" or "/api".
  String get baseUrl {
    var u = url.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) u = 'https://$u';
    u = u.replaceAllMapped(RegExp(r'^(https?://[^/:]+)/(\d{2,5})(?=/|$)'), (m) => '${m[1]}:${m[2]}');
    u = u.replaceAll(RegExp(r'/(dashboard|api)?/*$'), '');
    return u;
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url, 'username': username, 'password': password};
  factory ServerConfig.fromJson(Map<String, dynamic> j) => ServerConfig(
      id: j['id'], name: j['name'], url: j['url'], username: j['username'], password: j['password']);
}

class VpnUser {
  final String username, status, note;
  final int usedTraffic, dataLimit; // bytes, 0 = unlimited
  final int? expire; // unix seconds, null/0 = never
  final List<String> links;
  final String subscriptionUrl;
  final DateTime? onlineAt;
  final Map<String, dynamic> raw;

  VpnUser({required this.raw, required this.username, required this.status, required this.note, required this.usedTraffic,
      required this.dataLimit, required this.expire, required this.links, required this.subscriptionUrl, this.onlineAt});

  factory VpnUser.fromJson(Map<String, dynamic> j) => VpnUser(
        raw: j,
        username: j['username'] ?? '',
        status: j['status'] ?? 'active',
        note: j['note'] ?? '',
        usedTraffic: (j['used_traffic'] ?? 0).toInt(),
        dataLimit: (j['data_limit'] ?? 0).toInt(),
        expire: j['expire'] == null ? null : (j['expire'] as num).toInt(),
        links: List<String>.from(j['links'] ?? const []),
        subscriptionUrl: j['subscription_url'] ?? '',
        onlineAt: j['online_at'] == null ? null : DateTime.tryParse(j['online_at']),
      );

  int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;
  /// Days left (rounded up). null = never expires. Negative = already expired.
  int? get daysLeft => (expire == null || expire == 0) ? null : ((expire! - _now) / 86400).ceil();
  late final bool expiringSoon =
      status == 'active' && expire != null && expire! > 0 && expire! > _now && expire! - _now <= 3 * 86400;
  late final bool nearLimit = status == 'active' && dataLimit > 0 && usedTraffic / dataLimit >= 0.9;
  late final String lower = username.toLowerCase();

  int? get daysLeft => expireDate == null ? null : expireDate!.difference(DateTime.now()).inDays;
  bool get expiringSoon {
    final e = expire;
    if (status != 'active' || e == null || e == 0) return false;
    final left = e - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return left > 0 && left <= 3 * 86400;
  }
  bool get nearLimit => status == 'active' && dataLimit > 0 && usedTraffic >= dataLimit * 0.9;

  DateTime? get expireDate => (expire == null || expire == 0) ? null : DateTime.fromMillisecondsSinceEpoch(expire! * 1000);
}

String fmtBytes(num b) {
  if (b <= 0) return '0 B';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  double v = b.toDouble();
  while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 2)} ${u[i]}';
}
