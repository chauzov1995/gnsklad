import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gnsklad/tehhclass.dart';
import 'package:gnsklad/gn_api_config.dart';
import 'package:http/http.dart' as http;

class OrderOperationPage extends StatefulWidget {
  OrderOperationPage();

  @override
  _OrderOperationPageState createState() => _OrderOperationPageState();
}

class _OrderOperationPageState extends State<OrderOperationPage> {
  _OrderOperationPageState();

  static const double _weekItemWidth = 112;
  late final int _productionYear;
  late final int _firstProductionWeek;
  late final int _lastProductionWeek;
  late final ScrollController _weekScrollController;
  late int _selectedProductionWeek;
  Timer? _orderFilterDebounce;
  int _batchRequestId = 0;
  bool _operationsReady = false;
  bool _loadingBatches = true;
  String? _batchError;

  // ISO weeks start on Monday; week 1 contains January 4.
  DateTime _firstWeekMonday(int year) {
    final january4 = DateTime.utc(year, 1, 4);
    return january4.subtract(Duration(days: january4.weekday - 1));
  }

  void _initializeProductionWeeks() {
    final now = DateTime.now();
    _productionYear = now.year;
    final firstMonday = _firstWeekMonday(_productionYear);
    final weeksInYear =
        _firstWeekMonday(_productionYear + 1).difference(firstMonday).inDays ~/
            7;
    final today = DateTime.utc(now.year, now.month, now.day);
    final currentWeek = ((today.difference(firstMonday).inDays / 7).floor() + 1)
        .clamp(1, weeksInYear);
    _selectedProductionWeek = currentWeek;
    _firstProductionWeek = (currentWeek - 12).clamp(1, weeksInYear);
    _lastProductionWeek = (currentWeek + 12).clamp(1, weeksInYear);
    _weekScrollController = ScrollController(
      initialScrollOffset:
          (currentWeek - _firstProductionWeek) * _weekItemWidth,
    );
  }

  Widget _buildProductionWeeks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
          child: Text(
            'Неделя производства · $_productionYear',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: 56,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidePadding = ((constraints.maxWidth - _weekItemWidth) / 2)
                  .clamp(0.0, double.infinity);
              return ListView.builder(
                controller: _weekScrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                itemExtent: _weekItemWidth,
                itemCount: _lastProductionWeek - _firstProductionWeek + 1,
                itemBuilder: (context, index) {
                  final week = _firstProductionWeek + index;
                  return Center(
                    child: ChoiceChip(
                      label: Text('Неделя $week'),
                      showCheckmark: false,
                      selected: week == _selectedProductionWeek,
                      onSelected: (selected) {
                        if (!selected) return;
                        setState(() => _selectedProductionWeek = week);
                        _weekScrollController.animateTo(
                          index * _weekItemWidth,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                        _orderFilterDebounce?.cancel();
                        selzakaz();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initializeProductionWeeks();
    firstload();
  }

  Future<void> firstload() async {
    try {
      await getspisoperac();
      if (!mounted) return;
      _operationsReady = true;
      await selzakaz();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBatches = false;
        _batchError =
            'Не удалось загрузить операции. Откройте страницу повторно.';
      });
    }
  }

  Future<void> getspisoperac() async {
    final uri = Uri.parse(apiUrl).replace(queryParameters: {'endpoint': 'sql'});
    print("usersdasd");
    print(tehhclass.user_id);
    final requestBody = {
      "nik": tehhclass.user_nik,
      "pass": tehhclass.user_pass,
      "sql": """
select OW.MOPER_ID, O.Name from MOPER_WORKPLACES OW, MUSERWORK UW, MOper O where OW.WORKPLACES_ID=UW.MWORKPLACES_ID and UW.USERS_ID=? and O.ID=OW.MOPER_ID
    """,
      "params": [tehhclass.user_id]
    };

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json", "X-GN-Api-Key": apiKey},
      body: json.encode(requestBody),
    );
    if (!mounted) return;

    if (response.statusCode == 200) {
      operations = json.decode(response.body);
      print('Ответ от сервера: $operations');

      //  var otvet = data[0];
      //  name = otvet['NAMEF'];
      //  kolvo = otvet['KOLVO_S'];
      setState(() {});
    } else {
      throw Exception('Ошибка сервера: ${response.statusCode}');
    }

    final List<Map<String, dynamic>> result = await tehhclass.database.rawQuery(
      'SELECT defoperac FROM Users WHERE id = ?',
      [tehhclass.user_id],
    );

    if (!mounted) return;
    final defoperac = result.isNotEmpty ? result.first['defoperac'] : null;
    selectedOperation = operations.any((op) => op['MOPER_ID'] == defoperac)
        ? defoperac as int
        : operations.isEmpty
            ? null
            : operations.first['MOPER_ID'] as int;
    setState(() {});
  }

  @override
  void dispose() {
    _orderFilterDebounce?.cancel();
    _weekScrollController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  final TextEditingController _orderController = TextEditingController();

  int? selectedBatch;
  int? selectedOperation;

  List<dynamic> batches = [];

  List<dynamic> operations = [];

  void _onOrderFilterChanged(String value) {
    _orderFilterDebounce?.cancel();
    // Invalidate pending responses immediately, even before the debounce ends.
    _batchRequestId++;
    setState(() {
      selectedBatch = null;
      batches = [];
      _loadingBatches = true;
      _batchError = null;
    });
    _orderFilterDebounce = Timer(
      const Duration(milliseconds: 400),
      () => selzakaz(),
    );
  }

  Future<void> _onSubmit() async {
    if (_loadingBatches || selectedBatch == null || selectedOperation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выбери партию и операцию')),
      );
      return;
    }

    final uri = Uri.parse(apiUrl).replace(queryParameters: {'endpoint': 'sql'});

    final requestBody = {
      "nik": tehhclass.user_nik,
      "pass": tehhclass.user_pass,
      "sql": """
  select
 M.ID, M.MAGAZINEID, M.MAGAZINETEXPROCID, M.MOPERID,   M.MPARTSGROUPS_ID, M.MTEXPROCID,
 M.NN, M.OPERTIME,   M.DateBegin,M.DateEnd,  M.Current_Flag,
 M.UserId1, M.UserId2,  M.Prim
from
 MAGAZINETEXOPER M
where
 M.MPARTSGROUPS_ID=? AND MOPERID=?
order by
 MPARTSGROUPS_ID
    """,
      "params": [selectedBatch, selectedOperation]
    };

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json", "X-GN-Api-Key": apiKey},
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      var asdasdasd = json.decode(response.body);
      print('Ответ от сервера: $asdasdasd');

      if (asdasdasd.length > 0) {
        final uri =
            Uri.parse(apiUrl).replace(queryParameters: {'endpoint': 'sqltran'});

        final requestBody = {
          "nik": tehhclass.user_nik,
          "pass": tehhclass.user_pass,
          "queries": [
            {
              "sql":
                  "update MagazineTexOper set DateBegin=Current_TimeStamp, USERID1=? where ID=? and DateBegin is Null",
              "params": [tehhclass.user_id, asdasdasd[0]['ID']]
            },
            {
              "sql":
                  "update MagazineTexOper set DateEnd=Current_TimeStamp, USERID1=? where ID=? and DateEnd is Null",
              "params": [tehhclass.user_id, asdasdasd[0]['ID']]
            },
          ]
        };

        final response = await http.post(
          uri,
          headers: {"Content-Type": "application/json", "X-GN-Api-Key": apiKey},
          body: json.encode(requestBody),
        );

        if (response.statusCode == 200) {
          print("Транзакция выполнена успешно");

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Операция успешно выполнена',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green, // зелёный фон
              //   behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          print("Ошибка: ${response.statusCode}");
        }

        print(
            "update MagazineTexOper set DateBegin=Current_TimeStamp, USERID1=:UserID1, where ID=:MagazineTexOper_ID and DateBegin is Null");
        print(
            "update MagazineTexOper set DateEnd=Current_TimeStamp, USERID1=:UserID1, where ID=:MagazineTexOper_ID and DateEnd is Null");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Операция уже была выполнена',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red, // красный фон
            //     behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      selzakaz();
    } else {
      print('Ошибка сервера: ${response.statusCode}');
    }
  }

  Future<void> selzakaz() async {
    if (!mounted || !_operationsReady) return;
    final requestId = ++_batchRequestId;
    setState(() {
      selectedBatch = null;
      batches = [];
      _loadingBatches = true;
      _batchError = null;
    });
    final ids = operations.map((op) => op['MOPER_ID']).join(', ');
    final weekStart = _firstWeekMonday(_productionYear)
        .add(Duration(days: (_selectedProductionWeek - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final orderFilter = _orderController.text.trim();
    final params = <dynamic>[
      2,
      weekStart.toIso8601String().substring(0, 10),
      weekEnd.toIso8601String().substring(0, 10),
      if (orderFilter.isNotEmpty) '%$orderFilter%',
    ];
    final uri = Uri.parse(apiUrl).replace(queryParameters: {'endpoint': 'sql'});

    final requestBody = {
      "nik": tehhclass.user_nik,
      "pass": tehhclass.user_pass,
      "sql": """
    select
 MP.COMMENT, MP.ID, MP.MAGAZINE_ID,
    MP.MTEXPROCID, MP.NAME, MP.Srok,
 MP.FLAG_END,
 (select Sum(KolVo) from MPCustom where  MPARTSGROUPSID=MP.ID) as Sum_Kol_Vo,
 MP.PREF,
  (
    SELECT FIRST 1 M.MOPERID
    FROM MAGAZINETEXOPER M
    WHERE M.MPARTSGROUPS_ID = MP.ID AND M.Current_Flag=1
    ORDER BY M.ID DESC
  ) AS TEKOPER,
   (
    SELECT FIRST 1 MO.NAME
    FROM MAGAZINETEXOPER M
    JOIN MOper MO ON MO.ID = M.MOPERID
    WHERE M.MPARTSGROUPS_ID = MP.ID AND M.Current_Flag = 1
    ORDER BY M.ID DESC
  ) AS MOPER_NAME
from
 MPARTSGROUPS MP
where
 MP.Texproc_Group_ID=?
 AND MP.SROK >= ? AND MP.SROK < ?
 ${orderFilter.isNotEmpty ? 'AND CAST(MP.MAGAZINE_ID AS VARCHAR(32)) LIKE ?' : ''}
   AND ((
        SELECT FIRST 1 M.MOPERID
        FROM MAGAZINETEXOPER M
        WHERE M.MPARTSGROUPS_ID = MP.ID
          AND M.Current_Flag = 1
        ORDER BY M.ID DESC
    ) IN (${ids.isEmpty ? 'NULL' : ids}) OR MP.FLAG_END = 1)
 order By MP.FLAG_END 
    """,
      "params": params
    };
    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json", "X-GN-Api-Key": apiKey},
        body: json.encode(requestBody),
      );
      if (!mounted || requestId != _batchRequestId) return;

      if (response.statusCode == 200) {
        batches = json.decode(response.body);

        batches.sort((a, b) {
          // Проверяем, равен ли TEKOPER 259
          final aIsTarget = a['TEKOPER'] == selectedOperation;
          final bIsTarget = b['TEKOPER'] == selectedOperation;

          if (aIsTarget && !bIsTarget) return -1; // a раньше
          if (!aIsTarget && bIsTarget) return 1; // b раньше
          return 0; // порядок не меняем
        });

        print('Ответ от сервера: $batches');

        setState(() => _loadingBatches = false);
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (_) {
      if (!mounted || requestId != _batchRequestId) return;
      setState(() {
        _loadingBatches = false;
        _batchError = 'Не удалось загрузить партии';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выполнение операции'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductionWeeks(),
          // Поле ввода и иконки
          Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          _orderController.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _orderController.text.length,
                          );
                        }
                      },
                      child: TextField(
                        controller: _orderController,
                        decoration: InputDecoration(
                          labelText: 'Номер заказа',
                          hintText: 'Номер целиком или часть номера',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _orderController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Сбросить фильтр',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _orderController.clear();
                                    _orderFilterDebounce?.cancel();
                                    selzakaz();
                                  },
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: _onOrderFilterChanged,
                        onSubmitted: (value) async {
                          _orderFilterDebounce?.cancel();
                          await selzakaz();
                        },
                      ),
                    ),
                  ),
                ],
              )),

          Padding(
              padding: EdgeInsets.all(10),
              child: const Text(
                'Выбери партию',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              )),

          Expanded(
              child: _loadingBatches
                  ? const Center(child: CircularProgressIndicator())
                  : _batchError != null
                      ? Center(child: Text(_batchError!))
                      : batches.isEmpty
                          ? const Center(
                              child:
                                  Text('За выбранный период партии не найдены'))
                          :
                          // Список партий
                          ListView.builder(
                              shrinkWrap: true,
                              itemCount: batches.length,
                              itemBuilder: (context, index) {
                                final batch = batches[index];
                                return RadioListTile<int>(
                                  title: batch['TEKOPER'] == selectedOperation
                                      ? Text(
                                          batch['NAME'],
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600),
                                        )
                                      : Text(batch['NAME']),
                                  subtitle: Text(
                                    'Заказ №${batch['MAGAZINE_ID']} · '
                                    '${batch['FLAG_END'] == 1 ? 'Завершена' : (batch['MOPER_NAME'] ?? '')}',
                                    style: batch['FLAG_END'] == 1
                                        ? const TextStyle(color: Colors.green)
                                        : null,
                                  ),
                                  value: batch['ID'] as int,
                                  groupValue: selectedBatch,
                                  onChanged: batch['FLAG_END'] == 1 ||
                                          batch['TEKOPER'] != selectedOperation
                                      ? null // отключаем выбор
                                      : (val) {
                                          setState(() {
                                            selectedBatch = val;
                                          });
                                        },
                                );
                              },
                            )),

          // const SizedBox(height: 10),
          Padding(
              padding: EdgeInsets.all(10),
              child:
                  // Список операций (заменили на ComboBox)
                  DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Я выполняю операцию',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                value: selectedOperation,
                items: operations.map((op) {
                  return DropdownMenuItem<int>(
                    value: op['MOPER_ID'],
                    child: Text(
                      op['NAME'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) async {
                  setState(() {
                    selectedOperation = val;
                  });

                  print("Выбрана операция ${selectedOperation}");
                  await tehhclass.database.rawUpdate(
                    '''
  UPDATE Users
  SET defoperac = ?
  WHERE id = ?
  ''',
                    [val, tehhclass.user_id],
                  );
                  await selzakaz();
                },
              )),

          // const SizedBox(height: 24),

          // Кнопка
          Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_loadingBatches && selectedBatch != null
                      ? _onSubmit
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selectedBatch != null ? Colors.green : Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    selectedBatch != null ? 'Выполнить' : 'Запрещено',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
