import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnsklad/supplier_documents.dart';
import 'package:gnsklad/warehouse_photos.dart';

class ControlledQueue extends SupplierQueue {
  ControlledQueue(super.root, {super.deliver, super.loadCatalog});
  @override
  void kick() {} // Tests choose the exact interruption/delivery boundary.
}

void main() {
  late Directory tmp;
  late File source;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('supplier-queue-test-');
    source = File('${tmp.path}/camera.png');
    await source.writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAAEklEQVR4nGP4z8AAQVDqPwMDAEHSBfsl0XwmAAAAAElFTkSuQmCC'));
  });
  tearDown(() async {
    if (tmp.parent.absolute.path == Directory.systemTemp.absolute.path &&
        tmp.path.contains('supplier-queue-test-')) {
      await tmp.delete(recursive: true);
    }
  });
  test('calendar date is independent of timezone conversion', () {
    expect(documentDate(DateTime(2026, 11, 3, 23, 59)), '2026-11-03');
    expect(validDocumentDate('2026-02-29'), false);
    expect(validDocumentDate('2024-02-29'), true);
    expect(validDocumentDate('2026-11-03T00:00:00Z'), false);
  });
  test(
      'durable multipage document survives offline, restart and lost acknowledgement with same ID',
      () async {
    final seen = <String>[];
    final root = Directory('${tmp.path}/q');
    final q = ControlledQueue(root, deliver: (j) async {
      seen.add(j.id);
      throw TimeoutException('lost reply');
    });
    await q.recover();
    final a = await q.capture(-1000001, source),
        b = await q.capture(-1000001, source);
    final j = await q.enqueue(
        [a, b], -1000001, 'Тестовый поставщик 1', DateTime(2026, 11, 3));
    expect(j.pages.length, 2);
    expect(j.date, '2026-11-03');
    expect(utf8.decode((await j.pdf.readAsBytes()).take(8).toList()),
        startsWith('%PDF-'));
    await q.drain();
    expect(await j.pdf.exists(), true);
    expect(await q.draftPages(-1000001), isEmpty);
    final restarted = ControlledQueue(root, deliver: (j) async {
      seen.add(j.id);
    });
    await restarted.recover();
    final restored = (await restarted.jobs()).single;
    expect(restored.hash, j.hash);
    expect(restored.supplierId, -1000001);
    await restored.record({});
    await restarted.drain();
    expect(seen, [j.id, j.id]);
    expect(await restarted.jobs(), isEmpty);
    expect(await source.exists(), true);
    q.dispose();
    restarted.dispose();
  });
  test(
      'failed PDF write keeps draft pages; complete staging resumes without duplicate',
      () async {
    final q = ControlledQueue(Directory('${tmp.path}/q'));
    await q.recover();
    final page = await q.capture(42, source);
    final j = await q.enqueue([page], 42, 'Поставщик', DateTime(2026, 1, 1));
    final staging = await j.dir.rename('${q.pending.path}/.writing-${j.id}');
    await q.recover();
    expect((await q.jobs()).single.id, j.id);
    expect(await staging.exists(), false);
    expect(await q.draftPages(42), isEmpty);
    final remaining = await q.capture(42, source);
    final broken = Directory('${q.pending.path}/.writing-${'b' * 32}');
    await broken.create();
    await File('${broken.path}/meta.json').writeAsString('{}');
    await q.recover();
    expect(q.recoveryIssues, isNotEmpty);
    expect(await (await q.draftPages(42)).single.resolveSymbolicLinks(),
        await remaining.resolveSymbolicLinks());
    expect(await broken.exists(), true);
    q.dispose();
  });
  test('corrupt PDF and metadata remain on device, source pages are preserved',
      () async {
    var calls = 0;
    final q = ControlledQueue(Directory('${tmp.path}/q'), deliver: (_) async {
      calls++;
    });
    await q.recover();
    final page = await q.capture(42, source);
    final j = await q.enqueue([page], 42, 'Поставщик', DateTime(2026, 1, 1));
    await j.pdf.writeAsString('corrupt');
    await q.recover();
    await q.drain();
    expect(calls, 0);
    expect(await page.exists(), true);
    expect(await j.pdf.exists(), true);
    await File('${j.dir.path}/meta.json').writeAsString('{}');
    expect(await q.jobs(), isEmpty);
    expect(q.recoveryIssues, isNotEmpty);
    expect(await j.pdf.exists(), true);
    q.dispose();
  });
  test(
      'offline directory cache survives failed refresh, rejects conflicting IDs',
      () async {
    final rows = [
      {'id': 42, 'name': 'Поставщик', 'cod': '42', 'inn': ''}
    ];
    final root = Directory('${tmp.path}/q');
    final q = ControlledQueue(root, loadCatalog: () async => rows);
    await q.recover();
    await q.refreshCatalog();
    expect(await q.cachedCatalog(), rows);
    final offline = ControlledQueue(root,
        loadCatalog: () async => throw const SocketException('offline'));
    await expectLater(
        offline.refreshCatalog(), throwsA(isA<SocketException>()));
    expect(await offline.cachedCatalog(), rows);
    final invalid =
        ControlledQueue(root, loadCatalog: () async => [...rows, ...rows]);
    await expectLater(invalid.refreshCatalog(), throwsA(isA<PhotoProblem>()));
    expect(await invalid.cachedCatalog(), rows);
    q.dispose();
    offline.dispose();
    invalid.dispose();
  });
  test(
      'discard affects only selected supplier page; unowned files cannot enter queue',
      () async {
    final q = ControlledQueue(Directory('${tmp.path}/q'));
    await q.recover();
    final page = await q.capture(42, source);
    await q.discardPage(42, page);
    expect(await q.draftPages(42), isEmpty);
    expect(await source.exists(), true);
    await expectLater(q.enqueue([source], 42, 'Поставщик', DateTime(2026)),
        throwsA(isA<PhotoProblem>()));
    q.dispose();
  });
  test(
      'Flutter PDF -> strict TLS Node -> archive; same ID, old PDF and authenticated read',
      () async {
    expect(PhotoApi.base, 'https://127.0.0.1:3443');
    final env = Platform.environment, root = Directory('${tmp.path}/archive');
    await root.create();
    final script = env['WAREHOUSE_TEST_JS']!;
    final service = await Process.start('node', [
      script
    ], environment: {
      'PHOTO_ROOT': '${tmp.path}/orders',
      'PHOTO_DB': '${tmp.path}/registry.db',
      'PHOTO_BIND': '127.0.0.1',
      'PHOTO_TOKEN': PhotoApi.token,
      'PHOTO_TLS_KEY': env['WAREHOUSE_TEST_KEY']!,
      'PHOTO_TLS_CERT': env['WAREHOUSE_TEST_CERT']!,
      'SUPPLIER_ROOT': root.path,
      'SUPPLIER_CATALOG':
          '${File(script).parent.path}/fixtures/suppliers.test.json',
      'SUPPLIER_ALLOW_TEST_CATALOG': '1'
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
    await ready.future.timeout(const Duration(seconds: 15));
    final catalog = await SupplierApi.suppliers();
    expect(catalog.length, 2);
    final sid = catalog.first['id'] as int;
    final q = ControlledQueue(Directory('${tmp.path}/q'));
    await q.recover();
    final a = await q.capture(sid, source), b = await q.capture(sid, source);
    final job = await q.enqueue(
        [a, b], sid, catalog.first['name'] as String, DateTime(2026, 11, 3));
    await SupplierApi.upload(job);
    await SupplierApi.upload(job);
    final files = await SupplierApi.documents(sid);
    expect(files.length, 1);
    expect(files.single['name'], '03.11.2026_${job.id}.pdf');
    final bytes = await SupplierApi.read(sid, files.single['name'] as String);
    expect(bytes, await job.pdf.readAsBytes());
    final folder = Directory('${root.path}/${catalog.first['name']}');
    expect(await File('${folder.path}/${files.single['name']}').readAsBytes(),
        bytes);
    await File('${folder.path}/01.02.2020_123.pdf').writeAsBytes(bytes);
    expect((await SupplierApi.documents(sid)).length, 2);
    expect(await SupplierApi.read(sid, '01.02.2020_123.pdf'), bytes);
    await q.drain();
    expect(await q.jobs(), isEmpty);
    q.dispose();
  }, skip: Platform.environment['WAREHOUSE_TEST_JS'] == null);
  test('false success receipt retains PDF and retry identity', () async {
    expect(PhotoApi.base, 'https://127.0.0.1:3443');
    final ctx = SecurityContext()
      ..useCertificateChain(Platform.environment['WAREHOUSE_TEST_CERT']!)
      ..usePrivateKey(Platform.environment['WAREHOUSE_TEST_KEY']!);
    final server =
        await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 3443, ctx);
    addTearDown(() => server.close(force: true));
    server.listen((req) async {
      await req.drain<void>();
      req.response.write('{"saved":true}');
      await req.response.close();
    });
    final q = ControlledQueue(Directory('${tmp.path}/q'));
    await q.recover();
    final page = await q.capture(42, source),
        job = await q.enqueue([page], 42, 'Поставщик', DateTime(2026, 11, 3));
    await q.drain();
    expect((await q.jobs()).single.id, job.id);
    expect(await job.pdf.exists(), true);
    expect((await job.state())['status'], 'error');
    q.dispose();
  }, skip: Platform.environment['WAREHOUSE_TEST_JS'] == null);
}
