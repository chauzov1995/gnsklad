import 'dart:async';
import 'package:gnsklad/defect_photos.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnsklad/warehouse_photos.dart';

class _ManualQueue extends WarehouseQueue {
  _ManualQueue(super.root, {required super.deliver});
  @override
  void kick() {}
}

void main() {
  test(
      'glass retains the article, bytes and submission ID through a lost reply and restart',
      () async {
    final temp = await Directory.systemTemp.createTemp('gn-glass-queue-');
    addTearDown(() => temp.delete(recursive: true));
    final glass = Directory('${temp.path}/glass-defects-v1');
    final warehouse = _ManualQueue(Directory('${temp.path}/warehouse-v1'),
        deliver: (_) async {});
    final failed = _ManualQueue(glass,
        deliver: (_) async => throw const SocketException('offline'));
    await warehouse.recover();
    await failed.recover();
    final source = await File('${temp.path}/camera.jpg')
        .writeAsBytes([3, 2, 1], flush: true);
    final item =
        await failed.stage('125109', 0, source, detail: 'ZR_1582_942_Рљ');
    await failed.confirm([item]);
    await failed.drain();
    expect(await item.file.exists(), isTrue);
    expect(await warehouse.jobs(), isEmpty);
    final seen = <String>[];
    final restarted = _ManualQueue(glass, deliver: (job) async {
      seen.add(job.id);
      expect(jsonDecode(await job.source.readAsString())['detail'],
          'ZR_1582_942_Рљ');
      expect(await job.file.readAsBytes(), [3, 2, 1]);
    });
    await restarted.recover();
    final restored = (await restarted.jobs()).single;
    await restored.record({});
    await restarted.drain();
    expect(seen, [item.id]);
    expect(await restarted.jobs(), isEmpty);
    expect(await source.exists(), isTrue);
    failed.dispose();
    restarted.dispose();
    warehouse.dispose();
  });
  test(
      'Flutter defect upload, filtered list, JPEG and deletion policy over factory TLS',
      () async {
    expect(PhotoApi.base, 'https://127.0.0.1:3443');
    final temp = await Directory.systemTemp.createTemp('gn-glass-https-');
    addTearDown(() => temp.delete(recursive: true));
    final root = Directory('${temp.path}/orders');
    await Directory('${root.path}/120000/125000/125100/125109 test')
        .create(recursive: true);
    final env = Platform.environment;
    final node = await Process.start('node', [
      env['WAREHOUSE_TEST_JS']!
    ], environment: {
      'PHOTO_ROOT': root.path,
      'PHOTO_DB': '${temp.path}/registry.db',
      'PHOTO_BIND': '127.0.0.1',
      'PHOTO_TOKEN': PhotoApi.token,
      'PHOTO_TLS_KEY': env['WAREHOUSE_TEST_KEY']!,
      'PHOTO_TLS_CERT': env['WAREHOUSE_TEST_CERT']!
    });
    addTearDown(() async {
      node.kill();
      await node.exitCode;
    });
    final ready = Completer<void>();
    node.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line == 'warehouse ready' && !ready.isCompleted) ready.complete();
    });
    node.stderr.drain<void>();
    await ready.future.timeout(const Duration(seconds: 10));
    final q = _ManualQueue(Directory('${temp.path}/glass'),
        deliver: DefectPhotos.upload);
    await q.recover();
    final source = await File('${temp.path}/photo.png').writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAAEklEQVR4nGP4z8AAQVDqPwMDAEHSBfsl0XwmAAAAAElFTkSuQmCC'));
    final job = await q.stage('125109', 0, source, detail: 'ZR_К');
    await q.confirm([job]);
    await q.drain();
    expect(await q.jobs(), isEmpty);
    final photo =
        (await DefectPhotos.list(order: '125109', detail: 'ZR_К')).single;
    expect(await DefectPhotos.list(order: '111111', detail: 'ZR_К'), isEmpty);
    expect(photo['iddetal'], 'ZR_К');
    expect((await DefectPhotos.read(photo['id'] as int)).take(2), [255, 216]);
    await expectLater(
        DefectPhotos.remove(photo['id'] as int),
        throwsA(isA<PhotoProblem>()
            .having((e) => e.message, 'policy', contains('разрешение'))));
    q.dispose();
  }, skip: Platform.environment['WAREHOUSE_TEST_JS'] == null);
}
