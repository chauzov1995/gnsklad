import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';

import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:flutter_datawedge/models/scan_result.dart';
import 'package:flutter_datawedge/models/scanner_status.dart';
import 'package:gnsklad/camera_screen.dart';
import 'package:gnsklad/camera_screen19.dart';
import 'package:gnsklad/camera_screen_sklad.dart';

import 'package:gnsklad/gallery_screen_s.dart';
import 'package:gnsklad/main.dart';
import 'package:gnsklad/photoobzor.dart';
import 'package:gnsklad/tehhclass.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:gnsklad/postavshikir.dart';
import 'package:gnsklad/tars.dart';
import 'package:http/http.dart' as http;

// Define a custom Form widget.
class brak extends StatefulWidget {
  final List<CameraDescription> cameras;

  brak(this.cameras);

  @override
  _brakState createState() => _brakState();
}

class _brakState extends State<brak> {
  _brakState();


  String _scannerStatus = "Scanner status";
  String _lastCode = '';
  final bool _isEnabled = true;
  final TextEditingController _commentController = TextEditingController();
  String articul = "";
  String orderId = "";
  String name = "";
  int kolvo = 0;

  String? selectedzakaz;

  @override
  void initState() {
    super.initState();

    HttpOverrides.global = MyHttpOverrides();
    initScanner4();

    firstload();
  }

  List<dynamic> photospisurl = [];

  void initScanner4() {
    //для новых сканеров
    tehhclass.receiver.messages.listen((BroadcastMessage? object) async {
      if (tehhclass.selectedIndex == 3) {
        if (object != null) {
          print(object);
          if (object.data!.containsKey('value')) {
            _lastCode = object.data!['value'];
          }
          if (object.data!.containsKey('scandata')) {
            _lastCode = object.data!['scandata'];
          }
          if (object.data!.containsKey('SCAN_BARCODE1')) {
            _lastCode = object.data!['SCAN_BARCODE1'];
          }

          print(jsonDecode(_lastCode)['article']);
          var jsonotv = jsonDecode(_lastCode);
          articul = jsonotv['article'];
          orderId = jsonotv['number'].toString().split('_')[1];
          selectedzakaz = orderId;


          final uri = Uri.parse(
              'http://172.16.4.104:3000/getmaterials?order=$orderId&artname=$articul&nik=${tehhclass.user_nik}&pass=${tehhclass.user_pass}');

          final response = await http.get(uri);
          if (response.statusCode == 200) {
            var otvet = json.decode(response.body)[0];

            name = otvet['NAMEF'];
            kolvo = otvet['CNT'];
            print(name);
            print('Ответ от сервера: $otvet');
          } else {
            print('Ошибка сервера: ${response.statusCode}');
          }

          setState(() {});

          return;

          print("initScanner4");
          print(_lastCode);

          selectedzakaz = _lastCode;
          //await selectzakaz();
          //filterSearchResults(_lastCode);
        }
      }
    });


  }

  @override
  void dispose() {

    super.dispose();
  }

  firstload() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print(androidInfo.version.sdkInt);
    sdkver = androidInfo.version.sdkInt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          child: articul == ''
              ? Center(child: Text("Отсканируй QR-код"))
              : ListView(
                  children: <Widget>[
                    Card(
                      child: ListTile(
                        title: Text(articul),
                        subtitle: Text('Заказ: ${orderId}\n${name}\nКол-во: $kolvo'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Примечание о браке:'),
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      textInputAction: TextInputAction.send, // 👈 это покажет кнопку "Отправить"
                      onSubmitted: (value) {
                        print("asdasdasd");
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Опишите проблему...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Фото:'),
                    Expanded(
                        child: Container(
                      padding: EdgeInsets.only(left: 5, right: 5, top: 5),
                      // color: Colors.amber,
                      child: GridView(
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.6,
                          crossAxisSpacing: 5.0,
                          mainAxisSpacing: 5.0,
                        ),
                        children: List.generate(
                          photospisurl.length,
                          (int index) => GestureDetector(
                            child: CachedNetworkImage(
                              imageBuilder: (context, imageProvider) =>
                                  Container(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: imageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              imageUrl: photospisurl[index]['path'],
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) =>
                                  Icon(Icons.error),
                            ),
                            onTap: () {
                              print("adsasdas");
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          photoobzor(photospisurl[index])));
                            },
                          ),
                        ),
                      ),
                    ))
                  ],
                ),
        ),
        floatingActionButton: selectedzakaz == null
            ? null
            : Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                SizedBox(
                  height: 10,
                ),
                FloatingActionButton(
                  heroTag: "btn2",
                  child: Icon(Icons.photo_camera_rounded),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => camera_screen_sklad(
                                name: orderId,
                                cameras: widget.cameras)));

                    //  await selectzakaz();
                  },
                )
              ]));
  }
}
