import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gnsklad/tehhclass.dart';

class AppSection {
  final int id;
  final String label;
  final IconData icon;
  const AppSection(this.id, this.label, this.icon);
}

const appSections = [
  AppSection(0, 'Поставщики', Icons.business_center),
  AppSection(1, 'Фурнитура', Icons.hardware),
  AppSection(2, 'Тары', Icons.shopping_basket_outlined),
  AppSection(3, 'Брак', Icons.error_outlined),
  AppSection(5, 'Операции', Icons.build),
];

class NavigationPreferences {
  static const defaults = [0, 1, 2, 3];

  static List<int> normalize(dynamic value) {
    if (value is! List) return List.of(defaults);
    final result = value
        .whereType<int>()
        .where(
          (id) => appSections.any((section) => section.id == id),
        )
        .toSet()
        .take(4)
        .toList();
    return result.isEmpty ? List.of(defaults) : result;
  }

  static Future<void> _ensureTable() => tehhclass.database.execute(
        'CREATE TABLE IF NOT EXISTS NavigationPreferences '
        '(user_id INTEGER PRIMARY KEY, sections TEXT NOT NULL)',
      );

  static Future<List<int>> load(int userId) async {
    await _ensureTable();
    final rows = await tehhclass.database.query('NavigationPreferences',
        where: 'user_id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return List.of(defaults);
    try {
      return normalize(jsonDecode(rows.first['sections'] as String));
    } on FormatException {
      return List.of(defaults);
    }
  }

  static Future<void> save(int userId, List<int> sections) async {
    await _ensureTable();
    await tehhclass.database.rawInsert(
      'INSERT OR REPLACE INTO NavigationPreferences (user_id, sections) VALUES (?, ?)',
      [userId, jsonEncode(normalize(sections))],
    );
  }
}

class NavigationSettingsPage extends StatefulWidget {
  final List<int> sections;
  final int userId;
  const NavigationSettingsPage(
      {super.key, required this.sections, required this.userId});

  @override
  State<NavigationSettingsPage> createState() => _NavigationSettingsPageState();
}

class _NavigationSettingsPageState extends State<NavigationSettingsPage> {
  late final List<int> _selected = List.of(widget.sections);
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await NavigationPreferences.save(widget.userId, _selected);
      if (mounted) Navigator.pop(context, List<int>.of(_selected));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Не удалось сохранить настройки. Попробуйте ещё раз.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройка вкладок')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'Выберите от 1 до 4 функций для нижней панели. Все разделы всегда доступны в меню.'),
          const SizedBox(height: 16),
          Text('На нижней панели (${_selected.length}/4)',
              style: Theme.of(context).textTheme.titleMedium),
          for (var index = 0; index < _selected.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text('${index + 1}'),
              title: Text(appSections
                  .firstWhere((s) => s.id == _selected[index])
                  .label),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Выше',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: _saving || index == 0
                      ? null
                      : () => setState(() {
                            final id = _selected.removeAt(index);
                            _selected.insert(index - 1, id);
                          }),
                ),
                IconButton(
                  tooltip: 'Ниже',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: _saving || index == _selected.length - 1
                      ? null
                      : () => setState(() {
                            final id = _selected.removeAt(index);
                            _selected.insert(index + 1, id);
                          }),
                ),
                IconButton(
                  tooltip: 'Убрать с панели',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _saving || _selected.length == 1
                      ? null
                      : () => setState(() => _selected.removeAt(index)),
                ),
              ]),
            ),
          const Divider(),
          const Text('Добавить на панель'),
          for (final section
              in appSections.where((s) => !_selected.contains(s.id)))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(section.icon),
              title: Text(section.label),
              trailing: const Icon(Icons.add_circle_outline),
              enabled: !_saving && _selected.length < 4,
              onTap: () => setState(() => _selected.add(section.id)),
            ),
          if (_selected.length == 4)
            const Text(
                'Чтобы добавить другую функцию, сначала уберите одну с панели.'),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Сохранение…' : 'Сохранить')),
        ],
      ),
    );
  }
}
