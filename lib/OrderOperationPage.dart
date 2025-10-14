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
select distinct
  MOW.MOPER_ID
from
  MUserWork UW
  join WORKPLACES MW on MW.ID = UW.MWORKPLACES_ID
  join MOPER_WORKPLACES MOW on MOW.WORKPLACES_ID = MW.ID
where
  UW.Users_ID = ?

    """,
      "params": [ tehhclass.user_id]
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
      setState(() {

      });
    } else {
      print('Ошибка сервера: ${response.statusCode}');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  final TextEditingController _orderController = TextEditingController();

  int? selectedBatch;
  String? selectedOperation;


   List<dynamic> batches =[];

  final List<String> operations = [
    'Рубашки',
    'Фрезеровка',
    'Упаковка',
  ];

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
 MAGAZINE_ID=? and MP.Texproc_Group_ID=?
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
                          setState(() {

                          });
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
            physics: const NeverScrollableScrollPhysics(),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              return RadioListTile<int>(
                title: Text(batch['NAME']),
                value: batch['ID'],
                groupValue: selectedBatch,
                onChanged: (val) {
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
                  DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Выбери операцию',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                value: selectedOperation,
                items: operations.map((op) {
                  return DropdownMenuItem<String>(
                    value: op,
                    child: Text(op),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedOperation = val;
                  });
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
