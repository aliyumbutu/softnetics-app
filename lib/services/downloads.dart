import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

String _safeName(String n) {
  final c = n.replaceAll(RegExp(r'[^\w.\- ]'), '_').trim();
  return c.isEmpty ? 'download' : c;
}

Future<File> _dir(String name) async {
  // ponytail: app documents dir only; MediaStore copy to public Downloads is a later add.
  final d = Platform.isAndroid
      ? (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory()
      : await getApplicationDocumentsDirectory();
  return File('${d.path}/${_safeName(name)}');
}

/// Download with the WebView session (cookies + UA), streamed to disk.
Future<void> downloadUrl(
  BuildContext ctx,
  Uri url,
  String name,
  String ua,
) async {
  final cookies = await CookieManager.instance().getCookies(
    url: WebUri.uri(url),
  );
  final client = http.Client();
  try {
    final req = http.Request('GET', url)
      ..headers['User-Agent'] = ua
      ..headers['Cookie'] = cookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
    final res = await client.send(req);
    if (res.statusCode >= 400) throw HttpException('HTTP ${res.statusCode}');
    final file = await _dir(name);
    await res.stream.pipe(file.openWrite());
    if (ctx.mounted) _done(ctx, file);
  } catch (e) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('Download failed')));
    }
  } finally {
    client.close();
  }
}

Future<void> saveBase64(BuildContext ctx, String name, String b64) async {
  final file = await _dir(name);
  await file.writeAsBytes(
    base64Decode(b64.contains(',') ? b64.split(',').last : b64),
  );
  if (ctx.mounted) _done(ctx, file);
}

void _done(BuildContext ctx, File f) {
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text('Saved ${f.uri.pathSegments.last}'),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () => OpenFilex.open(f.path),
      ),
      duration: const Duration(seconds: 8),
    ),
  );
}

Future<void> shareFile(File f) =>
    SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
