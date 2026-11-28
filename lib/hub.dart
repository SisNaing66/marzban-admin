import 'package:dio/dio.dart';
import 'settings.dart';

/// Client for the SN Hub backend (hub.*): one "merged" user that exists on many
/// panels, with a shared quota that the hub keeps in sync.
class HubApi {
  final Dio _dio;
  String? _token;
  HubApi()
      : _dio = Dio(BaseOptions(
            baseUrl: AppSettings.hubUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 60)));

  static String err(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['detail'] != null) return d['detail'].toString();
      return e.response?.statusCode != null ? 'HTTP ${e.response!.statusCode}' : (e.message ?? 'Network error');
    }
    return e.toString();
  }

  Future<void> login() async {
    final r = await _dio.post('/auth/login', data: {'username': AppSettings.hubUser, 'password': AppSettings.hubPass});
    _token = r.data['token'];
  }

  Future<Response> _req(String m, String path, {dynamic data}) async {
    if (_token == null) await login();
    Future<Response> go() => _dio.request(path, data: data, options: Options(method: m, headers: {'Authorization': 'Bearer $_token'}));
    try {
      return await go();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) { await login(); return go(); }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> servers() async {
    final r = await _req('GET', '/servers');
    final d = r.data;
    final list = d is List ? d : (d is Map && d['servers'] is List ? d['servers'] as List : <dynamic>[]);
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Returns the raw JSON the hub answers with.
  Future<dynamic> createMerged({
    required List<int> serverIds, required String username, String customerName = '',
    required double gb, int? days,
  }) async =>
      (await _req('POST', '/users/merged', data: {
        'server_ids': serverIds, 'username': username, 'customer_name': customerName,
        'data_gb': gb, if (days != null) 'expire_days': days,
      })).data;
}

/// Finds a ready-made link in the hub's answer; falls back to the front short link.
String hubLinkFrom(dynamic resp, String username) {
  if (resp is Map) {
    for (final k in ['link', 'share_link', 'short_link', 'url', 'sub_url', 'subscription_url']) {
      final v = resp[k];
      if (v is String && v.startsWith('http')) return v;
    }
  }
  return '${AppSettings.hubFront}/vip/$username';
}
