import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateRelease {
  final String version;
  final int? build;
  const UpdateRelease(this.version, this.build);

  factory UpdateRelease.parse(String body) {
    final text = body.trim();
    String version;
    int? build;
    if (text.startsWith('{')) {
      final data = jsonDecode(text) as Map<String, dynamic>;
      version = data['version'] as String;
      build = int.tryParse('${data['build']}');
      if (build == null || build <= 0) {
        throw const FormatException('Некорректный номер сборки');
      }
    } else {
      version = text;
    }
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const FormatException('Некорректная версия на сервере');
    }
    return UpdateRelease(version, build);
  }

  bool isNewerThan(String currentVersion, int currentBuild) {
    if (build != null) return build! > currentBuild;
    final latest = version.split('.').map(int.parse).toList();
    final current = currentVersion.split('.').map(int.parse).toList();
    if (current.length != 3) return false;
    for (var i = 0; i < 3; i++) {
      if (latest[i] != current[i]) return latest[i] > current[i];
    }
    return false;
  }
}

// Streaming keeps large APKs out of memory. Failed transfers leave no partial file.
Future<void> downloadUpdate(http.Client client, Uri uri, File file,
    void Function(double?) onProgress) async {
  try {
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('Сервер вернул ${response.statusCode}');
    }
    final length = response.contentLength;
    var received = 0;
    final sink = await file.open(mode: FileMode.write);
    try {
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 30))) {
        await sink.writeFrom(chunk);
        received += chunk.length;
        onProgress(length != null && length > 0
            ? (received / length).clamp(0.0, 1.0)
            : null);
      }
    } finally {
      await sink.close();
    }
    if (received == 0 || (length != null && received != length)) {
      throw const FormatException('APK скачан не полностью');
    }
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  }
}

class UpdateService {
  static const _channel = MethodChannel('gnsklad/updates');
  static const _base = 'https://ecad.giulianovars.ru/appsklad';
  bool _busy = false;
  DateTime? _lastCheck;

  Future<void> checkForUpdate(BuildContext context,
      {bool force = false}) async {
    if (!Platform.isAndroid || _busy) return;
    if (!force &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(minutes: 15))
      return;
    _busy = true;
    _lastCheck = DateTime.now();
    // Other screens override HttpClient globally; updates always validate TLS.
    final client = IOClient(
        HttpClient()..badCertificateCallback = (cert, host, port) => false);
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await client.get(
          Uri.parse(
            '$_base/version.php?format=json&t=${DateTime.now().millisecondsSinceEpoch}',
          ),
          headers: {
            'Cache-Control': 'no-cache'
          }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200)
        throw HttpException('HTTP ${response.statusCode}');
      final release = UpdateRelease.parse(response.body);
      if (!release.isNewerThan(info.version, int.parse(info.buildNumber)) ||
          !context.mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Доступно обновление'),
          content: Text('Скачать и установить версию ${release.version}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Позже')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Обновить')),
          ],
        ),
      );
      if (accepted == true && context.mounted) {
        await _downloadAndInstall(context, client, release);
      }
    } catch (e) {
      // A failed background check must not block work or claim there are no updates.
      debugPrint('Не удалось проверить обновление: $e');
    } finally {
      client.close();
      _busy = false;
    }
  }

  Future<void> _downloadAndInstall(
      BuildContext context, http.Client client, UpdateRelease release) async {
    final progress = ValueNotifier<double?>(null);
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Скачивание обновления'),
            content: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, value, __) =>
                  Column(mainAxisSize: MainAxisSize.min, children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 12),
                Text(value == null
                    ? 'Подключение к серверу…'
                    : '${(value * 100).floor()}%'),
              ]),
            ),
          )),
    );
    unawaited(navigator.push(route));
    File? file;
    try {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/update.apk');
      await downloadUpdate(
          client,
          Uri.parse(
              '$_base/app-release.apk?t=${DateTime.now().millisecondsSinceEpoch}'),
          file,
          (value) => progress.value = value);
      // Verify the downloaded archive against this app and the installed build.
      await _channel.invokeMethod('validateApk', {
        'path': file.path,
        'version': release.version,
        'build': release.build,
      });
      if (route.isActive) navigator.removeRoute(route);
      if (!context.mounted) return;
      final allowed =
          await _channel.invokeMethod<bool>('requestInstallPermission');
      if (allowed != true) {
        throw const FormatException(
            'Разрешите установку обновлений для приложения «Склад» и повторите попытку');
      }
      final result = await OpenFilex.open(file.path,
          type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        throw FormatException(
            'Не удалось открыть установщик: ${result.message}');
      }
    } catch (e) {
      if (file != null && await file.exists()) await file.delete();
      if (route.isActive) navigator.removeRoute(route);
      if (!context.mounted) return;
      final message = e is TimeoutException
          ? 'Скачивание прервано: сервер не отвечает. Попробуйте ещё раз.'
          : e is PlatformException
              ? (e.message ?? 'Не удалось подготовить установку')
              : e is FormatException
                  ? e.message
                  : 'Не удалось скачать обновление. Проверьте подключение и свободное место.';
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Обновление не установлено'),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Понятно'))
                ],
              ));
    } finally {
      if (route.isActive) navigator.removeRoute(route);
      // The route may still be finishing its removal animation.
      await route.completed;
      progress.dispose();
    }
  }
}
