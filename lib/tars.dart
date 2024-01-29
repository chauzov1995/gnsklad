import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:flutter_datawedge/models/scan_result.dart';
import 'package:flutter_datawedge/models/scanner_status.dart';
import 'package:http/http.dart' as http;
import 'package:gnsklad/tehhclass.dart';

// Define a custom Form widget.
class tars extends StatefulWidget {
  tars();

  @override
  _tarsState createState() => _tarsState();
}

class _tarsState extends State<tars> with SingleTickerProviderStateMixin {
  _tarsState();

  String countasdasd = '';
  String zakazid = '';
  String nakleyka = '';

  late Animation<Color?> animation;
  late AnimationController _controller;
  final TextEditingController _controllert = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    firstinit();

    super.initState();
  }

  firstinit() {
    _controller = AnimationController(
      vsync: this, // the SingleTickerProviderStateMixin
      duration: Duration(seconds: 4),
    );

    animation = ColorTween(begin: Colors.greenAccent, end: Colors.white)
        .animate(_controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    initScanner2();
  }

  int _scannerStatus = 0;
  String _lastCode = '';

  void initScanner2() {
    FlutterDataWedge dw = FlutterDataWedge(profileName: "gnprof");

    StreamSubscription onScanSubscription =
        dw.onScanResult.listen((ScanResult result) {
      setState(() {
        _lastCode = result.data;
        print("initScanner3");
        print(_lastCode);
        // editingController.text = _lastCode;
        findtara(int.parse(_lastCode));
      });
    });

    StreamSubscription onScanSubscription2 =
        dw.onScannerStatus.listen((ScannerStatus result) {
      ScannerStatusType status = result.status;
      setState(() {
        print(status.index);
        _scannerStatus = status.index;
      });
    });
  }

  void findtara(int sh_curr) async {
    // int sh_curr = 1500000101;
    // int sh_curr = 12519856;
    if ((sh_curr > 1500000000) && (sh_curr < 1600000000)) {
      setState(() {
        countasdasd = '';
        zakazid = '';
        nakleyka = '';
      });
      res_DetalKode = sh_curr - 1500000000;
      var response = await http.get(
          Uri.parse('http://172.16.4.104:3000/getyarlik?id=$res_DetalKode'));

      //   List<postav> prrreeee = (json.decode(response.body) as List)
      //      .map((data) => postav.fromJson(data))
      //   .toList();

      var otvet = json.decode(response.body);
      if (otvet.containsKey('err')) {
        countasdasd = otvet['err'];
      } else {
        countasdasd = "${otvet['taraName']}";
      }

      setState(() {});
    } else if ((sh_curr > 12000000) && (sh_curr < 99000000)) {
      if (countasdasd == '') return;
      setState(() {
        zakazid = '';
        nakleyka = '';
      });

      int idmagazupak = sh_curr - 12000000;
      var response = await http.get(Uri.parse(
          'http://172.16.4.104:3000/setmtara?id=${idmagazupak}&mtaraid=${res_DetalKode}'));
      var otvet = json.decode(response.body);
      zakazid = otvet[0]['MAGAZINE_ID'].toString();
      nakleyka = otvet[0]['CONCATENATION'].toString();
      _controller.reset();
      _controller.forward();
      setState(() {});
      print(otvet);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _controllert.dispose();
    super.dispose();
  }

  int res_DetalKode = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: tehhclass.user_nik == ''
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
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('ВХОД'),
                    onPressed: () async {
                      var response = await http.get(Uri.parse(
                          'http://172.16.4.104:3000/getuser?nik=${_controllert.text}'));

                      print('23223');
                      var otvet = json.decode(response.body)[0];
                      print(otvet);
                      if (otvet.containsKey('err')) {
                        //countasdasd = otvet['err'];
                      } else {
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
            : _scannerStatus == 1
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      Text("Сканирую...")
                    ],
                  )
                : countasdasd == ''
                    ? Text("Отсканируй штрихкод тары")
                    : AnimatedContainer(
                        color: zakazid == ''
                            ? Colors.transparent
                            : animation.value,
                        width: double.infinity,
                        duration: Duration(milliseconds: 4),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                countasdasd,
                                style: TextStyle(fontSize: 68),
                              ),
                              countasdasd == '' || zakazid == ""
                                  ? Container()
                                  : Column(
                                      children: [
                                        SizedBox(
                                          height: 10,
                                        ),
                                        Text(
                                          "Заказ",
                                          style: TextStyle(fontSize: 24),
                                        ),
                                        Text(
                                          "${zakazid}",
                                          style: TextStyle(fontSize: 36),
                                        ),
                                        Text(
                                          "${nakleyka}",
                                          style: TextStyle(
                                              fontSize: 106,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    )
                            ])));
  }
}
