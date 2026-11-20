import 'package:dio/dio.dart';

/// Minimal Telegram Bot API client (sendMessage / sendDocument).
class Telegram {
  static Dio _dio() => Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 60)));

  static String errorText(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['description'] != null) return d['description'].toString();
      return e.response?.statusCode != null ? 'HTTP ${e.response!.statusCode}' : (e.message ?? 'Network error');
    }
    return e.toString();
  }

  static Future<void> send(String token, String chat, String text) async {
    await _dio().post('https://api.telegram.org/bot$token/sendMessage',
        data: {'chat_id': chat, 'text': text}, options: Options(contentType: Headers.formUrlEncodedContentType));
  }

  static Future<void> sendFile(String token, String chat, List<int> bytes, String filename, String caption) async {
    final form = FormData.fromMap({
      'chat_id': chat,
      'caption': caption,
      'document': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio().post('https://api.telegram.org/bot$token/sendDocument', data: form);
  }
}
