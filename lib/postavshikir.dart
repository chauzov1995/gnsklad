import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';

import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:flutter_datawedge/models/scan_result.dart';
import 'package:flutter_datawedge/models/scanner_status.dart';
import 'package:gnsklad/camera_screen.dart';
import 'package:gnsklad/camera_screen19.dart';
import 'package:gnsklad/gallery_screen_s.dart';
import 'package:gnsklad/main.dart';
import 'package:gnsklad/tehhclass.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:gnsklad/postavshikir.dart';
import 'package:gnsklad/tars.dart';
import 'package:http/http.dart' as http;

// Define a custom Form widget.
class postavshikir extends StatefulWidget {
  final List<CameraDescription> cameras;

  postavshikir(this.cameras);

  @override
  _postavshikirState createState() => _postavshikirState();
}

class _postavshikirState extends State<postavshikir> {
  _postavshikirState();

  TextEditingController editingController = TextEditingController();

  List<postav> duplicateItems = <postav>[];
  var items = <postav>[];

  void filterSearchResults(String query) {
    List<postav> dummySearchList = <postav>[];
    dummySearchList.addAll(duplicateItems);
    if (query.isNotEmpty) {
      List<postav> dummyListData = <postav>[];
      for (var item in dummySearchList) {
        if (item.name!.toUpperCase().contains(query.toUpperCase()) ||
            item.inn!.toUpperCase().contains(query.toUpperCase())) {
          dummyListData.add(item);
        }
      }
      setState(() {
        items.clear();
        items.addAll(dummyListData);
      });
      return;
    } else {
      setState(() {
        items.clear();
        items.addAll(duplicateItems);
      });
    }
  }

  String _scannerStatus = "Scanner status";
  String _lastCode = '';
  final bool _isEnabled = true;

  @override
  void initState() {
    super.initState();

    HttpOverrides.global = MyHttpOverrides();
    initScanner2();

    firstload();
  }

  void initScanner2() {

    //для новых сканеров
    tehhclass.receiver.messages.listen((BroadcastMessage? object) {

      if (tehhclass.selectedIndex == 0) {
        if(object!=null){
        setState(() {
          print("aasdasdas");
print(object);

          if(object.data!.containsKey('value')){
            _lastCode=object.data!['value'];
          }
          if(object.data!.containsKey('scandata')){
            _lastCode=object.data!['scandata'];
          }
          if(object.data!.containsKey('SCAN_BARCODE1')){
            _lastCode=object.data!['SCAN_BARCODE1'];
          }
          print("initScanner1");
          print(_lastCode);
          editingController.text =
      _lastCode;// tehhclass.myFocusNode1.hasFocus ? "" : _lastCode;
          filterSearchResults(_lastCode);
        });
      }}
    });


    //для зебры
    StreamSubscription onScanSubscription =
        tehhclass.dw.onScanResult.listen((ScanResult result) {
      if (tehhclass.selectedIndex == 0) {
        setState(() {
          _lastCode = result.data;
          print("initScanner1");
          print(_lastCode);
          editingController.text =
              tehhclass.myFocusNode1.hasFocus ? "" : _lastCode;
          filterSearchResults(_lastCode);
        });
      }
    });
  }

  @override
  void dispose() {


    super.dispose();
  }

  firstload() async {
// open the database

    List<Map> list = await tehhclass.database
        .rawQuery('SELECT * FROM Test order by sort desc');
    //   print("records");
    print(list);

    //  await database.close();

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print(androidInfo.version.sdkInt);
    sdkver = androidInfo.version.sdkInt;

    var response = await http.get(Uri.parse('http://teplogico.ru/gn-spispost'));

    List<postav> prrreeee = (json.decode(response.body) as List)
        .map((data) => postav.fromJson(data))
        .toList();

    for (var elem in list) {
      var asdasdad = prrreeee.firstWhere((element) => element.id == elem['id']);
      duplicateItems.add(asdasdad);
      prrreeee.remove(asdasdad);
    }

    duplicateItems.addAll(prrreeee);

    //setState(() {});

    print(duplicateItems[0].name);

    items.addAll(duplicateItems);
    setState(() {});
  }

  late int selectedpost = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
      children: <Widget>[
        const SizedBox(
          height: 8,
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            focusNode: tehhclass.myFocusNode1,
            onChanged: (value) {
              filterSearchResults(value);
            },
            controller: editingController,
            decoration: InputDecoration(
                labelText: "Поставщик",
                hintText: "Поставщик (можно ИНН)",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_sharp, color: Colors.black),
                  onPressed: () {
                    editingController.clear();
                    tehhclass.myFocusNode1.requestFocus();
                    filterSearchResults("");
                  },
                ),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25.0)))),
          ),
        ),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return ListTile(
                onTap: () {
                  setState(() {
                    selectedpost = index;
                  });

                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => sdkver >= 21
                            ? CameraScreen(
                                name: items[index], cameras: widget.cameras)
                            : CameraScreen19(name: items[index]),
                      ));
                },
                //  tileColor: selectedpost==index ? Colors.blue : null,
                //  textColor: selectedpost==index ? Colors.white : null,
                title: Text('${items[index].name}'),
                subtitle: Text('ИНН: ${items[index].inn}'),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward_sharp),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                GalleryScreen2(items[index])));
                  },
                ),
              );
            },
          ),
        ),
      ],
    ));
  }
}
