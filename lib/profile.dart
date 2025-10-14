import 'dart:convert';

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
  }
  @override
  void dispose() {
    _controllert.dispose();
    super.dispose();
  }
  String errtext='';

  @override
  Widget build(BuildContext context) {

    return Scaffold(

        appBar:   AppBar(
        title: Text("Пользователь"),
    ),
    body:
    ListView(children: [ tehhclass.user_nik == ''
          ? AlertDialog(
        title: const Text('Ваш логин'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[

              TextField(
                  controller: _controllert,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                  )),  errtext==''? Container():Text(errtext,style: TextStyle(color: Colors.red),)
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('ВХОД'),
            onPressed: () async {
              setState(() {
                errtext='';
              });
              var response = await http.get(Uri.parse(
                  'http://172.16.4.104:3000/getuser?nik=${_controllert.text}'));

              print('23223');
              var otvets = json.decode(response.body);
              print(otvets.length);
              if (otvets.length==0) {
                setState(() {
               errtext= "Пользователь не найден"; });
              } else {
                var otvet=otvets[0];
                tehhclass.database.rawInsert(
                    'insert into Users(ID, NIK, USERGROUP, FIO, MUSERGROUPID, USERPASSWORD) VALUES (${otvet['ID']}, "${otvet['NIK']}", ${otvet['USERGROUP']}, "${otvet['FIO']}", ${otvet['MUSERGROUPID']}, "${otvet['USERPASSWORD']}" ) ');

                tehhclass.user_nik=otvet['NIK'];
                tehhclass.user_id=otvet['ID'];
                tehhclass.user_pass=otvet['USERPASSWORD'];
                setState(() {

                });
                //countasdasd = "${otvet['taraName']}";
              }
              // tehhclass.
            },
          ),
        ],
      )
          :Container(
        child: Column(children: [

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          //  icon: const Icon(Icons.record_voice_over, size: 28),
            label: const Text('Операции', style: TextStyle(fontSize: 18)),
            onPressed: () async {

              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => OrderOperationPage()));

            },
          ),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.record_voice_over, size: 28),
            label: const Text('Сказать 1349', style: TextStyle(fontSize: 18)),
            onPressed: () async {

           tehhclass.say("1349");
         //    await _audioPlayer.play(AssetSource('sounds/woman/cells/2.mp3'));


            },
          ),


          ListTile(title: Text(tehhclass.user_nik),),
          TextButton(onPressed: (){
            tehhclass.database.rawDelete(
                'DELETE FROM Users');
            tehhclass.user_id=0;
            tehhclass.user_nik='';
            tehhclass.user_pass='';
            setState(() {

            });


          }, child: Text("Выход"))
        ],))],));


  }
}
