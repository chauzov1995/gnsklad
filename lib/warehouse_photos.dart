import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// Bypass the legacy global permissive TLS override.
class _Strict extends HttpOverrides {}

class PhotoProblem implements Exception {
  final String message;
  const PhotoProblem(this.message);
  @override
  String toString() => message;
}

class PhotoApi {
  static const base = String.fromEnvironment('PHOTO_BASE',
      defaultValue: 'https://172.16.4.104:3443');
  static const token = String.fromEnvironment('PHOTO_TOKEN');
  static const ca = String.fromEnvironment('PHOTO_CA_B64');
  static Future<Uint8List> request(String path,
      {File? file, Duration deadline = const Duration(seconds: 55)}) async {
    final uri = Uri.parse('$base$path');
    if (token.length < 32 || uri.scheme != 'https') {
      throw const PhotoProblem('Не настроен защищённый доступ к фотосервису');
    }
    final context = SecurityContext(withTrustedRoots: true);
    if (ca.isNotEmpty) context.setTrustedCertificatesBytes(base64Decode(ca));
    final client = _Strict().createHttpClient(context);
    client.findProxy = (_) => 'DIRECT';
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      return await (() async {
        final req = await client.openUrl(file == null ? 'GET' : 'PUT', uri);
        req.followRedirects = false;
        req.headers.set('Authorization', 'Bearer $token');
        if (file != null) {
          req.headers.contentType = ContentType.binary;
          req.contentLength = await file.length();
          await req.addStream(file.openRead());
        }
        final res = await req.close();
        final b = BytesBuilder(copy: false);
        await for (final chunk in res) {
          b.add(chunk);
          if (b.length > 32 * 1024 * 1024) {
            throw const PhotoProblem('Ответ слишком большой');
          }
        }
        final bytes = b.takeBytes();
        if (res.statusCode != 200 && res.statusCode != 201) {
          String code = '';
          try {
            code = jsonDecode(utf8.decode(bytes))['error'] as String;
          } catch (_) {}
          const reasons = {
            'ambiguous_order': 'несколько папок заказа',
            'order_missing': 'нет папки заказа',
            'storage_unavailable': 'хранилище недоступно',
            'invalid_image': 'неподдерживаемое изображение',
            'file_conflict': 'конфликт архивной копии',
            'id_conflict': 'конфликт идентификатора',
            'order_moved': 'папка заказа перемещена',
            'too_large': 'слишком большой файл'
          };
          throw PhotoProblem(
              'HTTP ${res.statusCode}: ${reasons[code] ?? 'нет подтверждения'}');
        }
        return bytes;
      })()
          .timeout(deadline);
    } finally {
      client.close(force: true);
    }
  }

  static String listPath(String order) => '/v1/warehouse/$order/photos';
  static Future<List<String>> list(String order) async =>
      (jsonDecode(utf8.decode(await request(listPath(order)))) as List)
          .cast<String>();
  static Future<void> upload(PhotoJob j) async {
    final expected = (await sha256.bind(j.file.openRead()).first).toString();
    final r = jsonDecode(utf8.decode(await request(
        '${listPath(j.order)}/${j.id}?politon=${j.politon}',
        file: j.file)));
    if (r is! Map ||
        r['saved'] != true ||
        r['id'] != j.id ||
        r['order'] != j.order ||
        r['politon'] != j.politon ||
        r['sourceSha256'] != expected ||
        r['name'] != '${j.order}_${j.id}.jpg' ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(r['jpegSha256'].toString())) {
      throw const PhotoProblem('Сервер не подтвердил сохранение файла');
    }
  }
}

class PhotoJob {
  final Directory dir;
  final String order, id;
  final int politon, created;
  PhotoJob(this.dir, this.order, this.id, this.politon, this.created);
  File get file => File('${dir.path}/photo');
  File get draft => File('${dir.path}/draft');
  File get attempt => File('${dir.path}/attempt.json');
  File get source => File('${dir.path}/source.json');
  Future<void> record(Map data) async {
    final tmp = File('${dir.path}/attempt.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(attempt.path);
  }

  Future<Map> state() async {
    try {
      return jsonDecode(await attempt.readAsString()) as Map;
    } catch (_) {
      return {};
    }
  }
}

class WarehouseQueue extends ChangeNotifier {
  final Directory root;
  final Future<void> Function(PhotoJob) deliver;
  WarehouseQueue(this.root, {this.deliver = PhotoApi.upload});
  static late WarehouseQueue instance;
  static Future<void> start() async {
    instance = WarehouseQueue(Directory(
        '${(await getApplicationSupportDirectory()).path}/warehouse-v1'));
    await instance.recover();
    instance._timer =
        Timer.periodic(const Duration(seconds: 15), (_) => instance.kick());
    instance.kick();
  }

  Timer? _timer;
  bool _busy = false;
  final _rng = Random.secure();
  static final orderPattern = RegExp(r'^\d{5,6}$');
  Future<List<PhotoJob>> jobs({String? order}) async {
    final out = <PhotoJob>[];
    await for (final e in root.list()) {
      if (e is! Directory) continue;
      final m = RegExp(r'^(\d{5,6})_(\d+)_(0|1)_([0-9a-f]{32})$')
          .firstMatch(e.uri.pathSegments.where((s) => s.isNotEmpty).last);
      if (m == null || (order != null && order != m[1])) continue;
      final j = PhotoJob(e, m[1]!, m[4]!, int.parse(m[3]!), int.parse(m[2]!));
      if (await j.file.exists() ||
          await j.draft.exists() ||
          await j.source.exists()) {
        out.add(j);
      }
    }
    return out..sort((a, b) => a.created.compareTo(b.created));
  }

  Future<void> recover() async {
    await root.create(recursive: true);
    for (final j in await jobs()) {
      try {
        if (await j.file.exists()) continue;
        if (!await j.draft.exists()) {
          final meta = jsonDecode(await j.source.readAsString());
          final tmp = File('${j.dir.path}/writing');
          if (!await tmp.exists() || await tmp.length() != meta['size']) {
            final original = File(meta['path'] as String);
            await _copy(original, tmp);
          }
          if (await tmp.length() != meta['size']) {
            throw const PhotoProblem('Неполная локальная копия');
          }
          await tmp.rename(j.draft.path);
        }
        await j.draft.rename(j.file.path);
      } catch (_) {
        await j.record({
          'error': 'Прервана локальная запись: нужен исходный снимок'
        }).catchError((_) {});
      }
    }
  }

  Future<void> _copy(File source, File tmp) async {
    final h = await tmp.open(mode: FileMode.write);
    try {
      await for (final b in source.openRead()) {
        await h.writeFrom(b);
      }
      await h.flush();
    } finally {
      await h.close();
    }
  }

  Future<PhotoJob> stage(String order, int politon, File source) async {
    if (!orderPattern.hasMatch(order) || (politon != 0 && politon != 1)) {
      throw const PhotoProblem('Неверный заказ');
    }
    final id = List.generate(
        16, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final time = DateTime.now().millisecondsSinceEpoch;
    final j = PhotoJob(
        Directory('${root.path}/${order}_${time}_${politon}_$id'),
        order,
        id,
        politon,
        time);
    await j.dir.create();
    final tmp = File('${j.dir.path}/writing');
    await j.source.writeAsString(
        jsonEncode({'path': source.path, 'size': await source.length()}),
        flush: true);
    await _copy(source, tmp);
    if (await tmp.length() != await source.length()) {
      throw const PhotoProblem('Неполная локальная копия');
    }
    await tmp.rename(j.draft.path);
    notifyListeners();
    return j;
  }

  Future<void> confirm(Iterable<PhotoJob> items) async {
    for (final j in items) {
      if (await j.draft.exists()) await j.draft.rename(j.file.path);
    }
    notifyListeners();
    kick();
  }

  void kick() {
    unawaited(drain().catchError((Object e) {
      debugPrint('warehouse queue: ${e.runtimeType}');
    }));
  }

  Future<void> drain() async {
    if (_busy) return;
    _busy = true;
    try {
      for (final j in await jobs()) {
        if (!await j.file.exists()) continue;
        final prev = await j.state();
        final now = DateTime.now().millisecondsSinceEpoch;
        if ((prev['next'] ?? 0) > now) continue;
        try {
          await j.record({...prev, 'last': now, 'status': 'sending'});
          await deliver(j);
          await j.dir.delete(recursive: true);
          debugPrint('warehouse saved ${j.order} ${j.id}');
        } catch (e) {
          final count = (prev['count'] as int? ?? 0) + 1;
          final message = e is PhotoProblem
              ? e.message
              : 'Нет связи или подтверждения сервера';
          await j.record({
            'status': 'error',
            'count': count,
            'last': now,
            'next': now + min(120, 5 * (1 << min(count, 5))) * 1000,
            'error': message
          }).catchError((_) {});
          debugPrint('warehouse retained ${j.order} ${j.id}: $message');
        }
        notifyListeners();
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
