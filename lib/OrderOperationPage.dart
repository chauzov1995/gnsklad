import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gnsklad/tehhclass.dart';
import 'package:http/http.dart' as http;

class OrderOperationPage extends StatefulWidget {
  OrderOperationPage();

  @override
  _OrderOperationPageState createState() => _OrderOperationPageState();
}

class _OrderOperationPageState extends State<OrderOperationPage> {
  _OrderOperationPageState();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    firstload();
  }

  void firstload() {
    _orderController.text = "115874"; //закоменти
    getspisoperac();
  }

  Future<void> getspisoperac() async {
    final uri = Uri.parse('http://172.16.4.104:3000/sql');
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
      headers: {"Content-Type": "application/json"},
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      operations = json.decode(response.body);
      print('Ответ от сервера: $operations');

      //  var otvet = data[0];
      //  name = otvet['NAMEF'];
      //  kolvo = otvet['KOLVO_S'];
      setState(() {});
    } else {
      print('Ошибка сервера: ${response.statusCode}');
    }

    final List<Map<String, dynamic>> result = await tehhclass.database.rawQuery(
      'SELECT defoperac FROM Users WHERE id = ?',
      [tehhclass.user_id],
    );

    if (result.isNotEmpty) {
      final int defoperac = result.first['defoperac'] as int;
      print('defoperac = $defoperac');
      selectedOperation =
          defoperac == 0 ? operations[0]['MOPER_ID'] : defoperac;
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  final TextEditingController _orderController = TextEditingController();

  int? selectedBatch;
  int? selectedOperation;

  List<dynamic> batches = [];

  List<dynamic> operations = [];

  void _onScanQr() {
    // TODO: реализовать сканер QR
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR-сканер пока не реализован')),
    );
  }

  void _onSubmit() {
    if (_orderController.text.isEmpty ||
        selectedBatch == null ||
        selectedOperation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполни все поля')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Заказ ${_orderController.text}\nПартия: $selectedBatch\nОперация: $selectedOperation',
        ),
      ),
    );
  }

  bool isAllowed = false; // или false, в зависимости от логики

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
          // Поле ввода и иконки
          Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _orderController,
                      decoration: InputDecoration(
                        labelText: 'Номер заказа',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (value) async {
                        final uri = Uri.parse('http://172.16.4.104:3000/sql');

                        final requestBody = {
                          "nik": tehhclass.user_nik,
                          "pass": tehhclass.user_pass,
                          "sql": """
    select
 MP.COMMENT,  MP.ID,
    MP.MTEXPROCID, MP.NAME, MP.Srok,
 MP.FLAG_END,
 (select Sum(KolVo) from MPCustom where  MPARTSGROUPSID=MP.ID) as Sum_Kol_Vo,
 MP.PREF
from
 MPARTSGROUPS MP
where
 MAGAZINE_ID=? and MP.Texproc_Group_ID=? order By FLAG_END
    """,
                          "params": [value, 2]
                        };

                        final response = await http.post(
                          uri,
                          headers: {"Content-Type": "application/json"},
                          body: json.encode(requestBody),
                        );

                        if (response.statusCode == 200) {
                          batches = json.decode(response.body);
                          print('Ответ от сервера: $batches');

                          //  var otvet = data[0];
                          //  name = otvet['NAMEF'];
                          //  kolvo = otvet['KOLVO_S'];
                          setState(() {});
                        } else {
                          print('Ошибка сервера: ${response.statusCode}');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, size: 32),
                    onPressed: _onScanQr,
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
              child:
                  // Список партий
                  ListView.builder(

            shrinkWrap: true,

            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              return RadioListTile<int>(
                title: batch['FLAG_END'] == 1
                    ? Row(
                  children: [
                    Text(batch['NAME']),
                    const SizedBox(width: 10),
                    const Text(
                      "завершена",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                )
                    : Text(batch['NAME']),
                value: batch['ID'] as int,
                groupValue: selectedBatch,
                onChanged: batch['FLAG_END'] == 1
                    ? null // отключаем выбор
                    : (val) async {
                  setState(() {
                    selectedBatch = val;
                  });


                  final uri = Uri.parse('http://172.16.4.104:3000/sql');

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
                    "params": [batch['ID'], selectedOperation]
                  };

                  final response = await http.post(
                    uri,
                    headers: {"Content-Type": "application/json"},
                    body: json.encode(requestBody),
                  );

                  if (response.statusCode == 200) {
                    var asdasdasd = json.decode(response.body);
                    print('Ответ от сервера: $asdasdasd');
                    isAllowed=asdasdasd.length>0;
                    //  var otvet = data[0];
                    //  name = otvet['NAMEF'];
                    //  kolvo = otvet['KOLVO_S'];
                    setState(() {});
                  } else {
                    print('Ошибка сервера: ${response.statusCode}');
                  }



                },
              )
              ;
            },
          )),

          // const SizedBox(height: 10),
          Padding(
              padding: EdgeInsets.all(10),
              child:
                  // Список операций (заменили на ComboBox)
                  DropdownButtonFormField<int>(
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
                    child: Text(op['NAME']),
                  );
                }).toList(),
                onChanged: (val) async {
                  setState(() {
                    selectedOperation = val;
                  });

                  await tehhclass.database.rawUpdate(
                    '''
  UPDATE Users
  SET defoperac = ?
  WHERE id = ?
  ''',
                    [val, tehhclass.user_id],
                  );
                },
              )),

          // const SizedBox(height: 24),

          // Кнопка
          Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAllowed ? Colors.green : Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isAllowed ? 'Выполнить' : 'Запрещено',
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
