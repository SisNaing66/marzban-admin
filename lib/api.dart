import 'package:dio/dio.dart';
import 'models.dart';

class MarzbanApi {
  final ServerConfig server;
  late final Dio _dio;
  String? _token;

  MarzbanApi(this.server) {
    _dio = Dio(BaseOptions(
        baseUrl: '${server.baseUrl}/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30)));
  }

  Future<void> _login() async {
    final r = await _dio.post('/admin/token',
        data: {'username': server.username, 'password': server.password},
        options: Options(contentType: Headers.formUrlEncodedContentType));
    _token = r.data['access_token'];
  }

  Future<Response> _req(String method, String path, {dynamic data, Map<String, dynamic>? query}) async {
    if (_token == null) await _login();
    Future<Response> go() => _dio.request(path,
        data: data, queryParameters: query,
        options: Options(method: method, headers: {'Authorization': 'Bearer $_token'}));
    try {
      return await go();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) { await _login(); return go(); }
      rethrow;
    }
  }

  static String errorText(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['detail'] != null) return d['detail'].toString();
      return e.response?.statusCode != null ? 'HTTP ${e.response!.statusCode}' : (e.message ?? 'Network error');
    }
    return e.toString();
  }

  Future<void> testLogin() => _login();

  Future<Map<String, dynamic>> system() async => Map<String, dynamic>.from((await _req('GET', '/system')).data);

  Future<List<VpnUser>> users({String? search, String? status}) async {
    final out = <VpnUser>[];
    var offset = 0;
    while (true) {
      final r = await _req('GET', '/users', query: {
        'offset': offset, 'limit': 100,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
      });
      final list = (r.data['users'] as List).map((e) => VpnUser.fromJson(e)).toList();
      out.addAll(list);
      if (list.length < 100) break;
      offset += 100;
    }
    return out;
  }

  Future<Map<String, List<String>>> inboundTags() async {
    final r = await _req('GET', '/inbounds');
    final m = <String, List<String>>{};
    (r.data as Map).forEach((proto, list) => m[proto] = (list as List).map((i) => i['tag'].toString()).toList());
    return m;
  }

  Future<void> createUser({
    required String username, int? expire, int dataLimit = 0, String note = '',
    String resetStrategy = 'no_reset', required Map<String, List<String>> inbounds,
  }) async {
    final proxies = {for (final p in inbounds.keys) p: <String, dynamic>{}};
    await _req('POST', '/user', data: {
      'username': username, 'proxies': proxies, 'inbounds': inbounds,
      'expire': expire ?? 0, 'data_limit': dataLimit,
      'data_limit_reset_strategy': resetStrategy, 'status': 'active', 'note': note,
    });
  }

  Future<void> createUserBody(Map<String, dynamic> body) => _req('POST', '/user', data: body);
  Future<void> updateUser(String username, Map<String, dynamic> patch) => _req('PUT', '/user/$username', data: patch);
  Future<void> deleteUser(String username) => _req('DELETE', '/user/$username');
  Future<void> resetUsage(String username) => _req('POST', '/user/$username/reset');
  Future<void> revokeSub(String username) => _req('POST', '/user/$username/revoke_sub');

  Future<Map<String, dynamic>> coreConfig() async => Map<String, dynamic>.from((await _req('GET', '/core/config')).data);
  Future<void> setCoreConfig(Map<String, dynamic> cfg) => _req('PUT', '/core/config', data: cfg);
  Future<void> restartCore() => _req('POST', '/core/restart');
}
