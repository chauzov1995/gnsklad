import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:gnsklad/fotosklad.dart';
import 'package:gnsklad/postavshikir.dart';
import 'package:gnsklad/profile.dart';
import 'package:gnsklad/tars.dart';
import 'package:gnsklad/tehhclass.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'brak.dart';


int sdkver = 21;
late List<CameraDescription> _cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of the available cameras on the device.
  _cameras = await availableCameras();
  tehhclass.database = await tehhclass.initbd(); //инициализируем бд
  runApp(MyApp());
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


  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
      home: MyHomePage(title: 'Склад: Поставщики'),
    );
  }
}

class MyHomePage extends StatefulWidget {


  const MyHomePage({Key? key, required this.title})
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

//com.android.scanner.broadcast

    // tehhclass.receiver.isListening
  }



  Future<void> firstinit() async {


    await tehhclass.dw.initialize();
  //  await tehhclass.dw.createDefaultProfile(profileName: "gnprof");


   // print('asdasdasdsaasdasdassda');
    //print(  (await tehhclass.dw.requestActiveProfile()).flatMap(transform));

    await tehhclass.receiver.start();

    // await  tehhclass.receiver.stop();
    //await tehhclass.initbd();
  }

  @override
  void dispose() {
    tehhclass.receiver.stop();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (tehhclass.user_nik == '' && (index == 2 ||  index == 3)) {
      index = 4;
    }

    setState(() {
      tehhclass.selectedIndex = index;
    });
    tehhclass.myFocusNode1.unfocus();
    tehhclass.myFocusNode2.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: IndexedStack(children: <Widget>[
        postavshikir(_cameras),
        fotosklad(_cameras),
        tars(),
        brak(_cameras),
        profile(),
      ], index: tehhclass.selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center),
            label: 'Поставщики',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hardware),
            label: 'Фурнитура',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Тары',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.error_outlined),
            label: 'Брак',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Пользователь',
          )
        ],
        currentIndex: tehhclass.selectedIndex,
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
