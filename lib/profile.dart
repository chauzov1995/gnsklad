import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gnsklad/OrderOperationPage.dart';

import 'package:gnsklad/tehhclass.dart';
import 'package:http/http.dart' as http;

// Define a custom Form widget.
class profile extends StatefulWidget {
  profile();

  @override
  _profileState createState() => _profileState();
}

class _profileState extends State<profile> {
  _profileState();

  final TextEditingController _controllert = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // Случайный цвет при запуске
    avatarColor = getRandomDarkColor();
  }

  @override
  void dispose() {
    _controllert.dispose();
    super.dispose();
  }

  String errtext = '';

  Color getRandomDarkColor() {
    final random = Random();
    // Генерируем тёмные, но насыщенные цвета (низкая яркость, разная насыщенность)
    int r = 20 + random.nextInt(100); // 20–120
    int g = 20 + random.nextInt(100);
    int b = 20 + random.nextInt(100);
    return Color.fromARGB(255, r, g, b);
  }

  late Color avatarColor;

  @override
  Widget build(BuildContext context) {
    String userNik = tehhclass.user_nik.isNotEmpty
        ? tehhclass.user_nik
        : "U"; // fallback если пусто
    String firstLetter = userNik.characters.first.toUpperCase();

    return Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: Row(
            children: [
              // Аватар с буквой
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarColor,
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Имя и фамилия
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userNik,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tehhclass.FIO,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              tooltip: 'Выход',
              onPressed: () {
                tehhclass.database.rawDelete('DELETE FROM Users');
                tehhclass.user_id = 0;
                tehhclass.user_nik = '';
                tehhclass.user_pass = '';
                tehhclass.FIO = '';
                setState(() {});
              },
            ),
          ],
        ),
        body: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),

          ),
          child: ListView(
            children: [
              tehhclass.user_nik == ''
                  ? AlertDialog(
                      title: const Text('Ваш логин'),
                      content: SingleChildScrollView(
                        child: ListBody(
                          children: <Widget>[
                            TextField(
                                controller: _controllert,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                )),
                            errtext == ''
                                ? Container()
                                : Text(
                                    errtext,
                                    style: TextStyle(color: Colors.red),
                                  )
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('ВХОД'),
                          onPressed: () async {
                            setState(() {
                              errtext = '';
                            });
                            var response = await http.get(Uri.parse(
                                'http://172.16.4.104:3000/getuser?nik=${_controllert.text}'));

                            print('23223');
                            var otvets = json.decode(response.body);
                            print(otvets.length);
                            if (otvets.length == 0) {
                              setState(() {
                                errtext = "Пользователь не найден";
                              });
                            } else {
                              var otvet = otvets[0];
                              tehhclass.database.rawInsert(
                                  'insert into Users(ID, NIK, USERGROUP, FIO, MUSERGROUPID, USERPASSWORD) VALUES (${otvet['ID']}, "${otvet['NIK']}", ${otvet['USERGROUP']}, "${otvet['FIO']}", ${otvet['MUSERGROUPID']}, "${otvet['USERPASSWORD']}" ) ');

                              tehhclass.user_nik = otvet['NIK'];
                              tehhclass.user_id = otvet['ID'];
                              tehhclass.FIO = otvet['FIO'];
                              tehhclass.user_pass = otvet['USERPASSWORD'];
                              setState(() {});
                              //countasdasd = "${otvet['taraName']}";
                            }
                            // tehhclass.
                          },
                        ),
                      ],
                    )
                  : Container(
                      child: Column(
                        children: [
                          // Переход на страницу операций
                          ListTile(
                            leading: const Icon(Icons.build,
                                size: 28, color: Colors.blue),
                            title: const Text(
                              'Операции',
                              style: TextStyle(fontSize: 18),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => OrderOperationPage()),
                              );
                            },
                          ),

                          // const Divider(),
/*
                  // Озвучка числа 1349
                  ListTile(
                    leading: const Icon(Icons.record_voice_over, size: 28, color: Colors.green),
                    title: const Text(
                      'Сказать 1349',
                      style: TextStyle(fontSize: 18),
                    ),
                    onTap: () {
                      tehhclass.say("1349");
                    },
                  ),
*/
                        ],
                      ),
                    )
            ],
          ),
        ));
  }
}
