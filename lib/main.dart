import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:gnsklad/fotosklad.dart';
import 'package:gnsklad/postavshikir.dart';
import 'package:gnsklad/profile.dart';
import 'package:gnsklad/tars.dart';
import 'package:gnsklad/tehhclass.dart';
import 'package:gnsklad/update_service.dart';

import 'brak.dart';
import 'OrderOperationPage.dart';
import 'navigation_settings.dart';

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
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final UpdateService updateService = UpdateService();
  List<int> _sections = List.of(NavigationPreferences.defaults);
  int _preferencesRequest = 0;

  Future<void> _loadNavigation({bool initial = false}) async {
    final request = ++_preferencesRequest;
    final userId = tehhclass.user_id;
    try {
      final sections = await NavigationPreferences.load(userId);
      if (!mounted || request != _preferencesRequest) return;
      setState(() {
        _sections = sections;
        if (initial) {
          final first = sections.first;
          tehhclass.selectedIndex = tehhclass.user_nik.isEmpty &&
                  (first == 2 || first == 3 || first == 5)
              ? 4
              : first;
        }
      });
    } catch (_) {
      if (!mounted || request != _preferencesRequest) return;
      setState(() => _sections = List.of(NavigationPreferences.defaults));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить настройки вкладок')),
      );
    }
  }

  void _onUserChanged() {
    setState(() {
      tehhclass.selectedIndex = 4;
      _sections = List.of(NavigationPreferences.defaults);
    });
    _loadNavigation();
  }

  Future<void> _configureNavigation() async {
    final userId = tehhclass.user_id;
    final result = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
          builder: (_) => NavigationSettingsPage(
                sections: _sections,
                userId: userId,
              )),
    );
    if (!mounted || result == null || userId != tehhclass.user_id) return;
    ++_preferencesRequest;
    setState(() => _sections = result);
  }

  @override
  void initState() {
    // TODO: implement initState

    firstinit();
    super.initState();
    _loadNavigation(initial: true);

//com.android.scanner.broadcast

    // tehhclass.receiver.isListening
  }

  Future<void> firstinit() async {
    updateService.checkForUpdate(context);

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
    if (tehhclass.user_nik == '' && (index == 2 || index == 3 || index == 5)) {
      index = 4;
    }

    setState(() {
      tehhclass.selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(children: <Widget>[
        postavshikir(_cameras),
        fotosklad(_cameras),
        tars(),
        brak(_cameras),
        profile(
            onOpenSection: _onItemTapped,
            onUserChanged: _onUserChanged,
            onConfigureNavigation: _configureNavigation),
        if (tehhclass.selectedIndex == 5 && tehhclass.user_nik.isNotEmpty)
          KeyedSubtree(
              key: ValueKey(tehhclass.user_id), child: OrderOperationPage())
        else
          const SizedBox.shrink(),
      ], index: tehhclass.selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          for (final id in _sections)
            BottomNavigationBarItem(
              icon: Icon(appSections.firstWhere((s) => s.id == id).icon),
              label: appSections.firstWhere((s) => s.id == id).label,
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'Меню',
          )
        ],
        currentIndex: _sections.contains(tehhclass.selectedIndex)
            ? _sections.indexOf(tehhclass.selectedIndex)
            : _sections.length,
        selectedItemColor: Colors.amber[800],
        onTap: (index) =>
            _onItemTapped(index == _sections.length ? 4 : _sections[index]),
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
