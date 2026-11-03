import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnsklad/warehouse_photos.dart';

void main() {
  late Directory tmp;
  late File source;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('warehouse-queue-test-');
    source = File('${tmp.path}/camera.png');
    await source.writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAAEklEQVR4nGP4z8AAQVDqPwMDAEHSBfsl0XwmAAAAAElFTkSuQmCC'));
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });
  test(
      'discarded draft never returns after recovery; confirmed jobs cannot be discarded',
      () async {
    final q = WarehouseQueue(Directory('${tmp.path}/q'),
        deliver: (_) async => throw const SocketException('offline'));
    await q.recover();
    final discarded = await q.stage('12345', 0, source);
    final kept = await q.stage('12345', 0, source);
    await q.discardDraft(discarded);
    await q.recover();
    expect((await q.jobs()).single.id, kept.id);
    expect(await source.exists(), true);
    await expectLater(q.discardDraft(kept), throwsA(isA<PhotoProblem>()));
    await q.drain();
    expect((await q.jobs()).single.id, kept.id);
  });
  test(
      'interrupted discard is excluded from recovery even with source metadata',
      () async {
    final q = WarehouseQueue(Directory('${tmp.path}/q'));
    await q.recover();
    final j = await q.stage('12345', 0, source);
    await j.dir.rename('${j.dir.path}.discarded');
    await q.recover();
    expect(await q.jobs(), isEmpty);
  });
  test('only a matching server deletion confirmation removes a pending file',
      () async {
    final q = WarehouseQueue(Directory('${tmp.path}/q'),
        deliver: (j) async => throw PhotoCancelled(
            j.order == '12345' ? j.order : '00000', '${j.order}_${j.id}.jpg'));
    await q.recover();
    await q.stage('12345', 0, source);
    final keep = await q.stage('54321', 0, source);
    await q.recover();
    await q.drain();
    expect((await q.jobs()).single.id, keep.id);
    expect(await keep.file.exists(), true);
  });
  for (final fault in [
    const SocketException('Wi-Fi disconnected'),
    const PhotoProblem('HTTP 500'),
    TimeoutException('lost response')
  ]) {
    test(
        'retains file across ${fault.runtimeType}, processes other orders and restores',
        () async {
      final root = Directory('${tmp.path}/queue');
      final delivered = <String>[];
      final q = WarehouseQueue(root, deliver: (j) async {
        if (j.order == '12345') throw fault;
        delivered.add(j.id);
      });
      await q.recover();
      final a = await q.stage('12345', 1, source);
      final b = await q.stage('987654', 0, source);
      final c = await q.stage('987654', 0, source);
      expect(b.id, isNot(c.id));
      // Simulate termination with all three photographs still on the device.
      await source.delete();
      await q.recover();
      await q.drain();
      expect(delivered, unorderedEquals([b.id, c.id]));
      expect((await q.jobs()).single.id, a.id);
      expect(await a.file.length(), greaterThan(0));
      expect((await a.state())['count'], 1);
      // Retry is due, app is relaunched, camera temp file no longer exists.
      final state = await a.state();
      await a.record({...state, 'next': 0});
      final restarted = WarehouseQueue(root, deliver: (j) async {
        expect(j.order, '12345');
        expect(j.politon, 1);
        expect(j.id, a.id);
        delivered.add(j.id);
      });
      await restarted.recover();
      await restarted.drain();
      expect(await restarted.jobs(), isEmpty);
      expect(delivered, contains(a.id));
    });
  }
  test('confirmed capture starts delivery immediately and stays until receipt',
      () async {
    final received = Completer<PhotoJob>(),
        ack = Completer<void>(),
        finished = Completer<void>();
    final q = WarehouseQueue(Directory('${tmp.path}/q'), deliver: (j) async {
      received.complete(j);
      await ack.future;
    });
    await q.recover();
    final j = await q.stage('54321', 0, source);
    await q.drain();
    expect(received.isCompleted, false);
    await q.confirm([j]);
    expect((await received.future).id, j.id);
    expect(await j.file.exists(), true);
    q.addListener(() {
      if (!finished.isCompleted) finished.complete();
    });
    ack.complete();
    await finished.future;
    expect(await q.jobs(), isEmpty);
  });
  test('Flutter client → HTTPS Node → test archive → list and open JPEG',
      () async {
    expect(PhotoApi.base, 'https://127.0.0.1:3443');
    final root = Directory('${tmp.path}/archive');
    await Directory('${root.path}/10000/12000/12300/12345 test')
        .create(recursive: true);
    final env = Platform.environment;
    final service = await Process.start('node', [
      env['WAREHOUSE_TEST_JS']!
    ], environment: {
      'PHOTO_ROOT': root.path,
      'PHOTO_DB': '${tmp.path}/test.db',
      'PHOTO_BIND': '127.0.0.1',
      'PHOTO_TOKEN': PhotoApi.token,
      'PHOTO_TLS_KEY': env['WAREHOUSE_TEST_KEY']!,
      'PHOTO_TLS_CERT': env['WAREHOUSE_TEST_CERT']!
    });
    addTearDown(() async {
      service.kill();
      await service.exitCode;
    });
    final ready = Completer<void>();
    service.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line == 'warehouse ready' && !ready.isCompleted) ready.complete();
    });
    service.stderr.drain<void>();
    await ready.future.timeout(const Duration(seconds: 10));
    final q = WarehouseQueue(Directory('${tmp.path}/queue'));
    await q.recover();
    final j = await q.stage('12345', 1, source,
        capturedAt: DateTime.now().millisecondsSinceEpoch);
    await q.recover();
    await PhotoApi.upload(j);
    await PhotoApi.upload(j);
    final names = await PhotoApi.list('12345');
    expect(names, ['12345_${j.id}.jpg']);
    final jpeg =
        await PhotoApi.request('${PhotoApi.listPath('12345')}/${names.single}');
    expect(jpeg.take(2), [255, 216]);
    await PhotoApi.delete(j.order, names.single);
    await PhotoApi.delete(j.order, names.single);
    expect(await PhotoApi.list(j.order), isEmpty);
    await expectLater(PhotoApi.upload(j), throwsA(isA<PhotoCancelled>()));
    await q.drain();
    expect(await q.jobs(), isEmpty);
  }, skip: Platform.environment['WAREHOUSE_TEST_JS'] == null);
  test(
      'capture time survives queue recovery; imported images have no capture date',
      () async {
    final q = WarehouseQueue(Directory('${tmp.path}/q'));
    await q.recover();
    final taken =
        DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    final camera = await q.stage('12345', 0, source, capturedAt: taken);
    final imported = await q.stage('12345', 0, source);
    await q.recover();
    expect(jsonDecode(await camera.source.readAsString())['capturedAt'], taken);
    expect(
        jsonDecode(await imported.source.readAsString())['capturedAt'], isNull);
  });
  test('real TLS transport rejects 500, disconnect, timeout and false receipt',
      () async {
    expect(PhotoApi.base, 'https://127.0.0.1:3443');
    final ctx = SecurityContext()
      ..useCertificateChain(Platform.environment['WAREHOUSE_TEST_CERT']!)
      ..usePrivateKey(Platform.environment['WAREHOUSE_TEST_KEY']!);
    final srv =
        await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 3443, ctx);
    addTearDown(() => srv.close(force: true));
    final q = WarehouseQueue(Directory('${tmp.path}/q'));
    await q.recover();
    final j = await q.stage('12345', 0, source);
    await q.recover();
    srv.listen((req) async {
      await req.drain<void>();
      if (req.uri.path == '/timeout') {
        return;
      }
      if (req.uri.path == '/drop') {
        final socket = await req.response.detachSocket();
        socket.destroy();
        return;
      }
      req.response.statusCode = req.uri.path == '/error'
          ? 500
          : req.uri.path == '/age'
              ? 403
              : 200;
      req.response
          .write(req.uri.path == '/age' ? '{"error":"photo_too_old"}' : '{}');
      await req.response.close();
    });
    await expectLater(PhotoApi.request('/error'), throwsA(isA<PhotoProblem>()));
    await expectLater(
        PhotoApi.request('/age', method: 'DELETE'),
        throwsA(isA<PhotoProblem>()
            .having((e) => e.message, 'message', contains('24'))));
    await expectLater(PhotoApi.request('/drop'),
        throwsA(anyOf(isA<HttpException>(), isA<SocketException>())));
    await expectLater(
        PhotoApi.request('/timeout',
            deadline: const Duration(milliseconds: 500)),
        throwsA(isA<TimeoutException>()));
    await expectLater(PhotoApi.upload(j), throwsA(isA<PhotoProblem>()));
    expect(await j.file.exists(), true);
  }, skip: Platform.environment['WAREHOUSE_TEST_JS'] == null);
}
