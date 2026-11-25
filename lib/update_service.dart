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

  factory UpdateRelease.parse(String body, {bool factoryManifest = false}) {
    final text = body.trim();
    String version;
    int? build;
    if (text.startsWith('{')) {
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic> ||
          data['version'] is! String ||
          (factoryManifest &&
              data['applicationId'] != 'com.nchauzov.gn.gnsklad')) {
        throw const FormatException('Некорректное описание обновления');
      }
      version = data['version'] as String;
      build = int.tryParse('${data['build']}');
      if (build == null || build <= 0) {
        throw const FormatException('Некорректный номер сборки');
      }
    } else {
      if (factoryManifest) {
        throw const FormatException('Ожидался манифест Склада');
      }
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

enum UpdateSource {
  factory('http://172.16.4.104/apps/release.json',
      'http://172.16.4.104/apps/sklad.apk'),
  ecad('https://ecad.giulianovars.ru/appsklad/version.php?format=json',
      'https://ecad.giulianovars.ru/appsklad/app-release.apk');

  const UpdateSource(this.manifestUrl, this.apkUrl);
  final String manifestUrl;
  final String apkUrl;
}

Uri _freshUri(String url) {
  final uri = Uri.parse(url);
  return uri.replace(queryParameters: {
    ...uri.queryParameters,
    't': DateTime.now().millisecondsSinceEpoch.toString(),
  });
}

Future<UpdateRelease> _fetchRelease(
    http.Client client, UpdateSource source) async {
  final request = http.Request('GET', _freshUri(source.manifestUrl))
    ..followRedirects = false
    ..headers['Cache-Control'] = 'no-cache';
  final response = await client.send(request);
  if (response.statusCode != 200) {
    throw HttpException('HTTP ${response.statusCode}');
  }
  final bytes = <int>[];
  await for (final chunk in response.stream) {
    if (bytes.length + chunk.length > 4096) {
      throw const FormatException('Слишком большой манифест');
    }
    bytes.addAll(chunk);
  }
  return UpdateRelease.parse(utf8.decode(bytes),
      factoryManifest: source == UpdateSource.factory);
}

typedef AvailableUpdate = ({UpdateSource source, UpdateRelease release});

Future<AvailableUpdate> findUpdate(http.Client Function() createClient,
    {Duration factoryTimeout = const Duration(seconds: 3)}) async {
  for (final source in UpdateSource.values) {
    final client = createClient();
    try {
      final release = await _fetchRelease(client, source).timeout(
          source == UpdateSource.factory
              ? factoryTimeout
              : const Duration(seconds: 15));
      return (source: source, release: release);
    } on Exception {
      if (source == UpdateSource.ecad) rethrow;
    } finally {
      client.close();
    }
  }
  throw StateError('Не задан источник обновлений');
}

// Streaming keeps large APKs out of memory. Failed transfers leave no partial file.
Future<void> downloadUpdate(http.Client client, Uri uri, File file,
    void Function(double?) onProgress) async {
  try {
    final response = await client
        .send(http.Request('GET', uri)..followRedirects = false)
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
  // Other screens override HttpClient globally; ECAD must validate TLS.
  static http.Client _createClient() => IOClient(
      HttpClient()..badCertificateCallback = (cert, host, port) => false);
  bool _busy = false;
  DateTime? _lastCheck;

  Future<void> checkForUpdate(BuildContext context,
      {bool force = false}) async {
    if (!Platform.isAndroid || _busy) return;
    if (!force &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(minutes: 15)) {
      return;
    }
    _busy = true;
    _lastCheck = DateTime.now();
    try {
      final info = await PackageInfo.fromPlatform();
      final update = await findUpdate(_createClient);
      final release = update.release;
      debugPrint(
          'Проверка обновлений: ${update.source.manifestUrl}, версия ${release.version}');
      if (!release.isNewerThan(info.version, int.parse(info.buildNumber)) ||
          !context.mounted) {
        return;
      }
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
        final client = _createClient();
        try {
          await _downloadAndInstall(context, client, update);
        } finally {
          client.close();
        }
      }
    } catch (e) {
      // A failed background check must not block work or claim there are no updates.
      debugPrint('Не удалось проверить обновление: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _downloadAndInstall(
      BuildContext context, http.Client client, AvailableUpdate update) async {
    final release = update.release;
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
      await downloadUpdate(client, _freshUri(update.source.apkUrl), file,
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
