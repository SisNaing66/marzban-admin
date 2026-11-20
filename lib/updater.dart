import 'dart:ffi' show Abi;
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

/// Set by CI: --dart-define=BUILD_TS=<unix seconds when this APK was built>.
const buildTs = int.fromEnvironment('BUILD_TS', defaultValue: 0);

const _repo = 'SisNaing66/marzban-admin';

String get _apkName {
  final abi = Abi.current();
  if (abi == Abi.androidArm) return 'app-armeabi-v7a-release.apk';
  if (abi == Abi.androidX64) return 'app-x86_64-release.apk';
  return 'app-arm64-v8a-release.apk';
}

String get apkUrl => 'https://github.com/$_repo/releases/download/latest/$_apkName';

/// True when the "latest" release was published well after this APK was built.
Future<bool> updateAvailable() async {
  if (buildTs == 0) return false; // local/debug build
  final r = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 8)))
      .get('https://api.github.com/repos/$_repo/releases/latest', options: Options(headers: {'Accept': 'application/vnd.github+json'}));
  final pub = DateTime.parse(r.data['published_at']).millisecondsSinceEpoch ~/ 1000;
  return pub > buildTs + 600; // release is published a few minutes after the build starts
}

Future<void> openDownload() => launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication);
