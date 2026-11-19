import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'settings.dart';

String userLink(String baseUrl, VpnUser u) {
  final s = u.subscriptionUrl;
  if (s.isEmpty) return u.links.isNotEmpty ? u.links.first : '';
  return s.startsWith('/') ? '$baseUrl$s' : s;
}

String buildMessage(String template, VpnUser u, String link) {
  final d = u.expireDate;
  final dl = u.daysLeft;
  return template
      .replaceAll('{name}', u.username)
      .replaceAll('{expire}', d == null ? 'No expiry' : d.toString().substring(0, 10))
      .replaceAll('{days}', dl == null ? '∞' : '${dl < 0 ? 0 : dl}')
      .replaceAll('{used}', fmtBytes(u.usedTraffic))
      .replaceAll('{limit}', u.dataLimit == 0 ? '∞' : fmtBytes(u.dataLimit))
      .replaceAll('{link}', link);
}

/// QR code as a white-background PNG.
Future<Uint8List> qrPng(String data, {double size = 720}) async {
  const pad = 40.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = Colors.white);
  c.translate(pad, pad);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
  ).paint(c, Size(size - 2 * pad, size - 2 * pad));
  final img = await rec.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Share the message template text together with the QR image.
Future<void> shareUser(String baseUrl, VpnUser u) async {
  final link = userLink(baseUrl, u);
  final msg = buildMessage(await Settings.template(), u, link);
  if (link.isEmpty) {
    await Share.share(msg);
    return;
  }
  final png = await qrPng(link);
  final name = '${u.username}.png';
  await Share.shareXFiles(
    [XFile.fromData(png, mimeType: 'image/png', name: name)],
    text: msg,
    fileNameOverrides: [name],
  );
}

/// Save the QR image to the gallery (Pictures/Marzban Admin).
Future<void> saveQr(String baseUrl, VpnUser u) async {
  final link = userLink(baseUrl, u);
  if (link.isEmpty) throw 'No link for this user';
  if (!await Gal.hasAccess()) {
    if (!await Gal.requestAccess()) throw 'Gallery permission not granted';
  }
  await Gal.putImageBytes(await qrPng(link), album: 'Marzban Admin');
}
