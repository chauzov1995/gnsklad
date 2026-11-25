import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gnsklad/update_service.dart';

void main() {
  const factoryBody =
      '{"applicationId":"com.nchauzov.gn.gnsklad","version":"1.0.23","build":23}';
  test('factory metadata selects the QR APK even when already current',
      () async {
    var count = 0;
    final update = await findUpdate(() => MockClient((request) async {
          count++;
          expect(request.url.host, '172.16.4.104');
          expect(request.url.path, '/apps/release.json');
          return http.Response(factoryBody, 200);
        }));
    expect(count, 1);
    expect(update.source.apkUrl, 'http://172.16.4.104/apps/sklad.apk');
    expect(update.release.isNewerThan('1.0.23', 23), isFalse);
  });

  for (final reason in [
    'timeout',
    'unreachable',
    '404',
    'redirect',
    'portal',
    'other app',
    'invalid version'
  ]) {
    test('falls back to ECAD on $reason', () async {
      final hosts = <String>[];
      final update = await findUpdate(
          () => MockClient((request) async {
                hosts.add(request.url.host);
                if (hosts.length == 2) {
                  expect(request.url.scheme, 'https');
                  expect(request.url.queryParameters['format'], 'json');
                  return http.Response('1.0.25', 200);
                }
                switch (reason) {
                  case 'timeout':
                    await Future<void>.delayed(
                        const Duration(milliseconds: 60));
                    return http.Response(factoryBody, 200);
                  case 'unreachable':
                    throw const SocketException('offline');
                  case '404':
                    return http.Response('', 404);
                  case 'redirect':
                    return http.Response('', 302,
                        headers: {'location': 'http://example.com/'});
                  case 'portal':
                    return http.Response('<html></html>', 200);
                  case 'other app':
                    return http.Response(
                        factoryBody.replaceFirst(
                            'com.nchauzov.gn.gnsklad', 'other.app'),
                        200);
                  default:
                    return http.Response('1.2.3', 200);
                }
              }),
          factoryTimeout: const Duration(milliseconds: 30));
      expect(hosts, ['172.16.4.104', 'ecad.giulianovars.ru']);
      expect(update.source.apkUrl,
          'https://ecad.giulianovars.ru/appsklad/app-release.apk');
      expect(update.release.isNewerThan('1.0.24', 24), isTrue);
    });
  }

  test('both sources offline completes with an error', () async {
    await expectLater(
        findUpdate(() =>
            MockClient((_) async => throw const SocketException('offline'))),
        throwsA(isA<SocketException>()));
  });

  test('build number detects rebuilds and prevents downgrade', () {
    final release = UpdateRelease.parse('{"version":"1.0.12","build":13}');
    expect(release.isNewerThan('1.0.12', 12), isTrue);
    expect(release.isNewerThan('1.0.12', 13), isFalse);
    expect(release.isNewerThan('1.0.12', 14), isFalse);
  });

  test('legacy response compares numeric version parts', () {
    expect(UpdateRelease.parse('1.0.13\n').isNewerThan('1.0.12', 12), isTrue);
    expect(UpdateRelease.parse('1.0.9').isNewerThan('1.0.12', 12), isFalse);
    expect(UpdateRelease.parse('1.0.12').isNewerThan('1.0.12', 12), isFalse);
    expect(UpdateRelease.parse('1.10.0').isNewerThan('1.9.9', 12), isTrue);
  });

  test('invalid responses do not offer an update', () {
    for (final body in [
      '',
      '<html>Error</html>',
      '1.0',
      '{"version":"1.0.13","build":0}'
    ]) {
      expect(() => UpdateRelease.parse(body), throwsFormatException);
    }
  });

  test('download writes chunks and reports completed progress', () async {
    final directory = await Directory.systemTemp.createTemp('gn-update-test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/update.apk');
    final client =
        MockClient.streaming((request, body) async => http.StreamedResponse(
            Stream.fromIterable([
              [80, 75],
              [3, 4]
            ]),
            200,
            contentLength: 4));
    addTearDown(client.close);
    double? progress;
    await downloadUpdate(client, Uri.https('example.com', '/app.apk'), file,
        (value) => progress = value);
    expect(await file.readAsBytes(), [80, 75, 3, 4]);
    expect(progress, 1.0);
  });

  test('truncated download deletes partial APK', () async {
    final directory = await Directory.systemTemp.createTemp('gn-update-test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/update.apk');
    final client = MockClient.streaming((request, body) async =>
        http.StreamedResponse(Stream.value([80, 75]), 200, contentLength: 4));
    addTearDown(client.close);
    await expectLater(
        downloadUpdate(
            client, Uri.https('example.com', '/app.apk'), file, (_) {}),
        throwsFormatException);
    expect(await file.exists(), isFalse);
  });
}
