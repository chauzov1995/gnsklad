import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datawedge/models/scan_result.dart';
import 'package:flutter_datawedge/models/scanner_status.dart';
import 'package:gnsklad/camera_screen19.dart';
import 'package:gnsklad/gallery_screen_s.dart';
import 'package:gnsklad/tars.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'camera_screen.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter_datawedge/flutter_datawedge.dart';

int sdkver = 21;
late Database database;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SKLAD',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Склад: Поставщики', cameras: cameras),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyHomePage({Key? key, required this.title, required this.cameras})
      : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
    FlutterDataWedge dw = FlutterDataWedge(profileName: "gnprof");
    StreamSubscription onScanSubscription =
        dw.onScanResult.listen((ScanResult result) {
      setState(() {
        _lastCode = result.data;
        print(_lastCode);
        editingController.text = _lastCode;
        filterSearchResults(_lastCode);
      });
    });

    StreamSubscription onScanSubscription2 =
        dw.onScannerStatus.listen((ScannerStatus result) {
      ScannerStatusType status = result.status;
      setState(() {
        _scannerStatus = status.toString().split('.')[1];
      });
    });
  }

  firstload() async {
// open the database
    database = await openDatabase('my_db.db', version: 1,
        onCreate: (Database db, int version) async {
      // When creating the db, create the table
      await db.execute(
          'CREATE TABLE Test (id INTEGER PRIMARY KEY, sort INTEGER NOT NULL DEFAULT 1)');
    });

    List<Map> list =
        await database.rawQuery('SELECT * FROM Test order by sort desc');
    //   print("records");
    print(list);

    //  await database.close();

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print(androidInfo.version.sdkInt);
    sdkver = androidInfo.version.sdkInt;
    http: //teplogico.ru/gn-spispost
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

    setState(() {});

    print(duplicateItems[0].name);

    items.addAll(duplicateItems);
  }

  late int selectedpost = -1;

  int _selectedIndex = 0;

  Widget getwidget() {
    switch (_selectedIndex) {
      case 0:
        return Container(
          child: Column(
            children: <Widget>[
              const SizedBox(
                height: 8,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (value) {
                    filterSearchResults(value);
                  },
                  controller: editingController,
                  decoration: InputDecoration(
                      labelText: "Поставщик",
                      hintText: "Поставщик (можно ИНН)",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon:
                            const Icon(Icons.clear_sharp, color: Colors.black),
                        onPressed: () {
                          editingController.clear();
                          filterSearchResults("");
                        },
                      ),
                      border: const OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(25.0)))),
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
                                      name: items[index],
                                      cameras: widget.cameras)
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
          ),
        );
      case 1:
        return tars();


      default:
        return Container();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(_selectedIndex==0?"Поставщики":"Тары"),
      ),
      body: getwidget(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center),
            label: 'Поставщики',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Тары',
          )
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
      /*
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          if(selectedpost>-1){

          }


        },
        tooltip: 'Increment',
        child: const Icon(Icons.camera_alt),
      ), // This trailing comma makes auto-formatting nicer for build methods.*/
    );
  }
}

class postav {
  int? id;
  String? cod;
  String? name;
  String? inn;

  postav({this.id, this.cod, this.name, this.inn});

  postav.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    cod = json['cod'];
    name = json['name'];
    inn = json['inn'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['cod'] = cod;
    data['name'] = name;
    data['inn'] = inn;
    return data;
  }
}
