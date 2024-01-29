import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gnsklad/postavshikir.dart';
import 'package:gnsklad/tars.dart';
import 'package:gnsklad/tehhclass.dart';
import 'package:sqflite_common/sqlite_api.dart';


int sdkver = 21;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();
  tehhclass.database = await tehhclass.initbd(); //инициализируем бд
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




  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {


  @override
  void initState() {
    // TODO: implement initState

firstinit();
    super.initState();
  }

  Future<void> firstinit() async {
   //await tehhclass.initbd();


  }

  int _selectedIndex = 0;

  Widget getwidget() {
    switch (_selectedIndex) {
      case 0:
        return postavshikir(widget.cameras);
      case 1:
        return tars();
      case 2:
        return Container(
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
          ],),
        );

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

    return Scaffold(
      appBar: AppBar(

        title: Text(_selectedIndex==0?"Поставщики":_selectedIndex==1?"Тары":"Пользователь"),
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
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Пользователь',
          )
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
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
