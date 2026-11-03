import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnsklad/tars.dart';

void main() {
  test('barcode ranges, invalid input and scanner suffixes', () {
    expect(taraBarcode('1500000001\r\n'), 1500000001);
    expect(taraBarcode('12000001\t'), 12000001);
    for (final value in [
      '',
      'abc',
      '1500000000',
      '1600000000',
      '12000000',
      '99000000'
    ]) {
      expect(taraBarcode(value), isNull);
    }
  });
  testWidgets(
      'failed catalog retries while scanner remains subscribed; repeated scans',
      (tester) async {
    final scans = StreamController<String>.broadcast();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: tars(
            scans: scans.stream,
            loadCatalog: () async {
              if (++calls == 1) throw const FormatException();
              return {1: 'Test A', 2: 'Test B'};
            })));
    await tester.pumpAndSettle();
    expect(scans.hasListener, true);
    expect(find.textContaining('Не удалось загрузить'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(calls, 2);
    for (final entry
        in {'1500000001': 'Test A', '1500000002\r\n': 'Test B'}.entries) {
      scans.add(entry.key);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    expect(scans.hasListener, false);
    await scans.close();
  });
  testWidgets('hidden tab ignores scans; returning retries initialization',
      (tester) async {
    final scans = StreamController<String>.broadcast();
    var calls = 0;
    Future<Map<int, String>> load() async {
      if (++calls == 1) throw const FormatException();
      return {1: 'Test A', 2: 'Test B'};
    }

    Future<void> show(bool active) => tester.pumpWidget(MaterialApp(
        home: tars(
            key: const ValueKey('tars'),
            active: active,
            scans: scans.stream,
            loadCatalog: load)));
    await show(false);
    expect(calls, 0);
    await show(true);
    await tester.pumpAndSettle();
    expect(calls, 1);
    await show(false);
    scans.add('1500000001');
    await tester.pumpAndSettle();
    expect(calls, 1);
    await show(true);
    await tester.pumpAndSettle();
    expect(calls, 2);
    scans.add('1500000001');
    await tester.pumpAndSettle();
    expect(find.text('Test A'), findsOneWidget);
    await show(false);
    scans.add('1500000002');
    await tester.pumpAndSettle();
    expect(find.text('Test B'), findsNothing);
    await show(true);
    scans.add('1500000002');
    await tester.pumpAndSettle();
    expect(find.text('Test B'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await scans.close();
  });
  testWidgets(
      'resume retries; background and other-route scans cannot trigger operations',
      (tester) async {
    final scans = StreamController<String>.broadcast();
    var calls = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: tars(
            scans: scans.stream,
            loadCatalog: () async {
              if (++calls == 1) throw const FormatException();
              return {1: 'Test A', 2: 'Test B'};
            })));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    scans.add('1500000001');
    await tester.pumpAndSettle();
    expect(calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 2);
    scans.add('1500000001');
    await tester.pumpAndSettle();
    expect(find.text('Test A'), findsOneWidget);
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other'))));
    await tester.pumpAndSettle();
    scans.add('1500000002');
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Test A'), findsOneWidget);
    scans.add('invalid');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await scans.close();
  });
  testWidgets('late catalog completion after disposal is harmless',
      (tester) async {
    final scans = StreamController<String>.broadcast(),
        pending = Completer<Map<int, String>>();
    await tester.pumpWidget(MaterialApp(
        home: tars(scans: scans.stream, loadCatalog: () => pending.future)));
    await tester.pumpWidget(const SizedBox());
    pending.complete({1: 'Test A'});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(scans.hasListener, false);
    await scans.close();
  });
}
