import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TestSqlButton extends StatefulWidget {
  const TestSqlButton({super.key});

  @override
  State<TestSqlButton> createState() => _TestSqlButtonState();
}

class _TestSqlButtonState extends State<TestSqlButton> {
  bool _loading = false;

  Future<void> _runTestQuery() async {
    setState(() => _loading = true);

    final uri = Uri.parse('http://172.16.4.104:3000/sql');

    final requestBody = {
      "nik": "sysdba",
      "pass": "TukTuk",
      "sql": """
SELECT
    mwz.ID,
    mwz.MAGAZINEID,
    mwz.MAGAZINEZAMID,
    mwz.MCUSTOMID,
    mwz.KOLVO,
    mwz.PRIM,
    mc.ART_MATERIAL,
    mc.NAME
FROM magazinewotdelkazam mwz
LEFT JOIN mcustom mc ON mc.id = mwz.MCustomID
LEFT JOIN magazinezam mz ON mz.id = mwz.MAGAZINEZAMID
WHERE mwz.MAGAZINEID = 117903
  AND mz.DATEINSERT = ?
ORDER BY mwz.ID
      """,
      "params": ["18.03.2026"]
    };

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode(requestBody),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('SQL OK');
        print(data);

        String resultText = const JsonEncoder.withIndent('  ').convert(data);

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Результат SQL'),
            content: SingleChildScrollView(
              child: SelectableText(resultText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      } else {
        print('Ошибка сервера: ${response.statusCode}');
        print(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сервера: ${response.statusCode}')),
        );
      }
    } catch (e, s) {
      print('Ошибка запроса: $e');
      print(s);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка запроса: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _runTestQuery,
      child: _loading
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : const Text('Тест SQL'),
    );
  }
}