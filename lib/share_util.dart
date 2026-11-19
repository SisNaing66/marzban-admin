import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'settings.dart';

String buildMessage(VpnUser u, String link) {
  final exp = u.expireDate;
  final left = u.daysLeft;
  return AppSettings.template
      .replaceAll('{name}', u.note.isNotEmpty ? u.note : u.username)
      .replaceAll('{username}', u.username)
      .replaceAll('{link}', link)
      .replaceAll('{gb}', u.dataLimit == 0 ? 'Unlimited' : '${(u.dataLimit / 1073741824).toStringAsFixed(2)} GB')
      .replaceAll('{expire}', exp == null ? 'No expiry' : exp.toString().substring(0, 10))
      .replaceAll('{days}', left == null ? '∞' : '${left < 0 ? 0 : left}');
}

Future<void> shareMessage(VpnUser u, String link) => Share.share(buildMessage(u, link));

/// White-background QR PNG (720x720).
Future<Uint8List> qrPng(String link) async {
  final qr = QrPainter(
    data: link,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
  );
  final inner = await qr.toImage(640);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, 720, 720), Paint()..color = Colors.white);
  c.drawImage(inner, const Offset(40, 40), Paint());
  final img = await rec.endRecording().toImage(720, 720);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Opens the share sheet with the QR image + message.
Future<void> shareQrImage(VpnUser u, String link) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/${u.username}.png');
  await f.writeAsBytes(await qrPng(link));
  await Share.shareXFiles([XFile(f.path)], text: buildMessage(u, link));
}

/// Saves the QR image to the gallery (Pictures/Marzban Admin).
Future<void> saveQrToGallery(VpnUser u, String link) async {
  if (!await Gal.hasAccess()) {
    if (!await Gal.requestAccess()) throw 'Gallery permission not granted';
  }
  await Gal.putImageBytes(await qrPng(link), album: 'Marzban Admin');
}
