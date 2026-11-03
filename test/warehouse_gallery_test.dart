import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnsklad/gallery_screen.dart';

void main() {
  late Directory tmp;
  late File photo;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('warehouse-gallery-');
    photo = File('${tmp.path}/photo.png');
    await photo.writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAAEklEQVR4nGP4z8AAQVDqPwMDAEHSBfsl0XwmAAAAAElFTkSuQmCC'));
  });
  tearDown(() => tmp.delete(recursive: true));
  testWidgets(
      'preview waits for durable removal and closes after the last photo',
      (tester) async {
    final images = [photo];
    final done = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => GalleryScreen(
                                  images: images,
                                  onDelete: (_) {
                                    calls++;
                                    return done.future;
                                  }))),
                      child: const Text('Open')),
                ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_forever));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(images, hasLength(1));
    await tester.tap(find.byIcon(Icons.delete_forever));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(images, hasLength(1));
    done.complete();
    await tester.pumpAndSettle();
    expect(images, isEmpty);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed durable removal keeps the photo in preview',
      (tester) async {
    final images = [photo];
    await tester.pumpWidget(MaterialApp(
        home: GalleryScreen(
            images: images,
            onDelete: (_) async =>
                throw const FileSystemException('disk error'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_forever));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(images, hasLength(1));
    expect(find.text('Не удалось удалить снимок. Он сохранён на устройстве.'),
        findsOneWidget);
  });
}
