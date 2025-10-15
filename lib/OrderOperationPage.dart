import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gnsklad/QRScanPage.dart';
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

  Future<void> _onScanQr() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRScanPage()),
    );
    if (result != null) {
      print(result);
      _orderController.text = result;

      selectedzakaz = result;
      await selzakaz();
    }
  }

  Future<void> _onSubmit() async {
    if (_orderController.text.isEmpty ||
        selectedBatch == null ||
        selectedOperation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполни все поля')),
      );
      return;
    }



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
      "params": [selectedBatch, selectedOperation]
    };

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      var asdasdasd = json.decode(response.body);
      print('Ответ от сервера: $asdasdasd');
      print(asdasdasd[0]['ID'].toString());

      if (asdasdasd.length > 0) {




        final uri = Uri.parse('http://172.16.4.104:3000/sqltran');

        final requestBody = {
          "nik": tehhclass.user_nik,
          "pass": tehhclass.user_pass,
          "queries": [
            {
              "sql": "update MagazineTexOper set DateBegin=Current_TimeStamp, USERID1=? where ID=? and DateBegin is Null",
              "params": [tehhclass.user_id, asdasdasd[0]['ID']]
            },
            {
              "sql": "update MagazineTexOper set DateEnd=Current_TimeStamp, USERID1=? where ID=? and DateEnd is Null",
              "params": [tehhclass.user_id, asdasdasd[0]['ID']]
            },
          ]
        };

        final response = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
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
          print("Ошибка: ${response.body}");
        }




        print("update MagazineTexOper set DateBegin=Current_TimeStamp, USERID1=:UserID1, where ID=:MagazineTexOper_ID and DateBegin is Null");
        print("update MagazineTexOper set DateEnd=Current_TimeStamp, USERID1=:UserID1, where ID=:MagazineTexOper_ID and DateEnd is Null");






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
      setState(() {
        selectedBatch=null;
      });
      selzakaz();


    } else {
      print('Ошибка сервера: ${response.statusCode}');
    }
  }

  bool isAllowed = false; // или false, в зависимости от логики
  String selectedzakaz = "";

  Future<void> selzakaz() async {



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
 MAGAZINE_ID=? and MP.Texproc_Group_ID=? order By FLAG_END 
    """,
      "params": [selectedzakaz, 2]
    };

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode(requestBody),
    );

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

      //  var otvet = data[0];
      //  name = otvet['NAMEF'];
      //  kolvo = otvet['KOLVO_S'];
      setState(() {});
    } else {
      print('Ошибка сервера: ${response.statusCode}');
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
                        selectedzakaz = value;
                        await selzakaz();
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
                          Text(
                            "завершена",
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      )
                    : batch['TEKOPER'] == selectedOperation
                        ? Text(
                            batch['NAME'],
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                          )
                        : Text(batch['NAME']),
                subtitle: Text(batch['MOPER_NAME']),
                value: batch['ID'] as int,
                groupValue: selectedBatch,
                onChanged: batch['FLAG_END'] == 1 ||
                        batch['TEKOPER'] != selectedOperation
                    ? null // отключаем выбор
                    : (val) async {
                        setState(() {
                          selectedBatch = val;
                        });

                        await selzakaz();

/*




*/
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

                  print("Выбрана операция ${selectedOperation}");
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
