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
class fotosklad extends StatefulWidget {
  final List<CameraDescription> cameras;

  fotosklad(this.cameras);

  @override
  _fotoskladState createState() => _fotoskladState();
}

class _fotoskladState extends State<fotosklad> {
  _fotoskladState();

  TextEditingController editingController = TextEditingController();

  String _scannerStatus = "Scanner status";
  String _lastCode = '';
  final bool _isEnabled = true;


  String? selectedzakaz;

  @override
  void initState() {
    super.initState();

    HttpOverrides.global = MyHttpOverrides();
    initScanner2();

    firstload();
  }

  List<dynamic> photospisurl = [];

  Future<void> selectzakaz() async {
    var response = await http
        .get(Uri.parse("https://teplogico.ru/gn1/" + selectedzakaz.toString()));
    photospisurl = json.decode(response.body);
    print(photospisurl);
    setState(() {});
  }

  void initScanner2() {


    //для новых сканеров
    tehhclass.receiver.messages.listen((BroadcastMessage? object) {

      if(tehhclass.selectedIndex==1) {
        if (object != null) {
          setState(() async {
            if (object.data!.containsKey('value')) {
              _lastCode = object.data!['value'];
            }
            if (object.data!.containsKey('scandata')) {
              _lastCode = object.data!['scandata'];
            }
            if(object.data!.containsKey('SCAN_BARCODE1')){
              _lastCode=object.data!['SCAN_BARCODE1'];
            }

            print("initScanner2");
            print(_lastCode);
            editingController.text =
                _lastCode; //tehhclass.myFocusNode2.hasFocus?"":_lastCode;
            selectedzakaz = _lastCode;
            await selectzakaz();
            //filterSearchResults(_lastCode);
          });
        }
      }


    });

    //для зебры
    StreamSubscription onScanSubscription =
      tehhclass.dw.onScanResult.listen((ScanResult result) {
        if(tehhclass.selectedIndex==1) {
          setState(() async {
            _lastCode = result.data;
            print("initScanner2");
            print(_lastCode);
            editingController.text = tehhclass.myFocusNode2.hasFocus?"":_lastCode;
            selectedzakaz = _lastCode;
            await selectzakaz();
            //filterSearchResults(_lastCode);
          });
        }
    });


  }

  @override
  void dispose() {

    editingController.dispose();
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
          child: Column(
            children: <Widget>[
              const SizedBox(
                height: 8,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  focusNode:tehhclass.myFocusNode2,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  // Only numbers can be entered
                  onSubmitted: (value) async {
                    selectedzakaz = value;
                    await selectzakaz();
                    print(selectedzakaz);
                  },
                  controller: editingController,
                  decoration: InputDecoration(
                      labelText: "Заказ",
                      hintText: "Заказ",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon:
                            const Icon(Icons.clear_sharp, color: Colors.black),
                        onPressed: () async {
                          editingController.clear();
                          tehhclass.myFocusNode2.requestFocus();
                          selectedzakaz = null;
                          await selectzakaz();

                          // filterSearchResults("");
                        },
                      ),
                      border: const OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(25.0)))),
                ),
              ),
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
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        imageUrl: photospisurl[index]['path'],
                        placeholder: (context, url) =>Center(child:
                            CircularProgressIndicator(),),
                        errorWidget: (context, url, error) => Icon(Icons.error),
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
                FloatingActionButton(
                  heroTag: "btn1",
                  backgroundColor: Colors.greenAccent,
                  child: Text(
                    "ПОЛИТОН",
                    style: TextStyle(fontSize: 10),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => camera_screen_sklad(
                                  name: editingController.text,
                                  cameras: widget.cameras,
                                  politon: 1,
                                )));
                    await selectzakaz();
                  },
//сделал загрузку дальше проверь приходят ли фотки сечерз файлкопи в нашу папку на чсерваке
                ),
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
                                name: editingController.text,
                                cameras: widget.cameras)));

                    await selectzakaz();
                  },
                )
              ]));
  }
}
