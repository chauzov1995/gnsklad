import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnsklad/navigation_settings.dart';

void main() {
  test('saved selection keeps order and rejects unknown or duplicate sections',
      () {
    expect(NavigationPreferences.normalize([5, 2, 5, 99, 0]), [5, 2, 0]);
    expect(NavigationPreferences.normalize([]), [0, 1, 2, 3]);
    expect(NavigationPreferences.normalize([5, 3, 2, 1, 0]), [5, 3, 2, 1]);
  });

  testWidgets(
      'selection supports replacing tabs, ordering, and a minimum of one',
      (tester) async {
    tester.view.physicalSize = const Size(960, 1800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: NavigationSettingsPage(
      sections: [0, 1, 2, 3],
      userId: 1,
    )));
    expect(tester.takeException(), isNull);
    final operations = find.widgetWithText(ListTile, 'Операции');
    expect(tester.widget<ListTile>(operations).enabled, isFalse);
    await tester.tap(find.byTooltip('Убрать с панели').first);
    await tester.pump();
    await tester.ensureVisible(operations);
    await tester.tap(operations);
    await tester.pump();
    expect(find.text('На нижней панели (4/4)'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Выше').last);
    await tester.tap(find.byTooltip('Выше').last);
    await tester.pump();
    final selectedTitles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .take(4)
        .map((tile) => (tile.title as Text).data)
        .toList();
    expect(selectedTitles, ['Фурнитура', 'Тары', 'Операции', 'Брак']);
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.byTooltip('Убрать с панели').first);
      await tester.tap(find.byTooltip('Убрать с панели').first);
      await tester.pump();
    }
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Убрать с панели'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
}
