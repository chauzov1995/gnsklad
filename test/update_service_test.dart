import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gnsklad/update_service.dart';

void main() {
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
