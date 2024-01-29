import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return  ListView(children: [ tehhclass.user_nik == ''
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
          ListTile(title: Text(tehhclass.user_nik),),
          TextButton(onPressed: (){
            tehhclass.database.rawDelete(
                'DELETE FROM Users');
            tehhclass.user_nik='';
            tehhclass.user_pass='';
            setState(() {

            });


          }, child: Text("Выход"))
        ],))],);


  }
}
