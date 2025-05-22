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
import 'package:intl/intl.dart';
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

          _commentController.text="";
          kolvosel=0;

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


          final uri = Uri.parse('http://172.16.4.104:3000/sql');

          final requestBody = {
            "nik": tehhclass.user_nik,
            "pass": tehhclass.user_pass,
            "sql": """
      SELECT 
        M.Art_Material,
        TP.MName AS NAMEF,
        sum(m.kolvo) as KOLVO_S
      FROM 
        MKonstr M
      LEFT JOIN 
        TPrice TP ON TP.Articul = M.Art_Material
      WHERE 
        M.CustomID = ? AND M.Art_Material = ?
      GROUP BY 
        TP.MName, M.Art_Material
    """,
            "params": [orderId, articul]
          };

          final response = await http.post(uri,
            headers: {"Content-Type": "application/json"},
            body: json.encode(requestBody),
          );

          if (response.statusCode == 200) {
            var data = json.decode(response.body);
            print('Ответ от сервера: $data');

            var otvet = data[0];
            name = otvet['NAMEF'];
            kolvo = otvet['KOLVO_S'];
          } else {
            print('Ошибка сервера: ${response.statusCode}');
          }


          selectzakaz();
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


  Future<void> selectzakaz() async {
    setState(() {
    photospisurl=[];
    });
    var response = await http
        .get(Uri.parse("https://teplogico.ru/gn1brak/" + orderId.toString()));
    photospisurl = json.decode(response.body);
    print(photospisurl);
    setState(() {});
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


  int kolvosel = 0;

  void _selectPage(int page) {

setState(() {
  kolvosel=page;
  print(kolvosel);
});
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
                        subtitle: Column(children: [Text('Заказ: ${orderId}\n${name}\nКол-во: $kolvo'),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: List.generate(kolvo>7?7:kolvo, (index) {
                              final pageNumber = index + 1;
                              final isSelected = pageNumber == kolvosel;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                                      foregroundColor: isSelected ? Colors.white : Colors.black,
                                      textStyle: const TextStyle(fontSize: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onPressed: () => _selectPage(pageNumber),
                                    child: Text('$pageNumber'),
                                  ),
                                ),
                              );
                            }),
                          )
                        ],)
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Примечание о браке:'),
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      textInputAction: TextInputAction.send, // 👈 это покажет кнопку "Отправить"
                      onSubmitted: (value) async {
                        print("asdasdasd");

if(kolvosel==0){
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Не выбрано количество'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating, // плавающий стиль (по желанию)
    ),
  );

  return;
}


                        final uri = Uri.parse('http://172.16.4.104:3000/sql');


                        // Получаем сегодняшнюю дату в формате ДД.ММ.ГГГГ
                        final now = DateTime.now();
                        final formattedDate = DateFormat('dd.MM.yyyy').format(now);

                        final requestBody = {
                          "nik": tehhclass.user_nik,
                          "pass": tehhclass.user_pass,
                          "sql": """
      INSERT INTO MAGAZINEZAM (
        MAGAZINEID, USERGROUPID, USERID, MPRETENTYPEID, FINDUSERID,
        PRIM, DATEINSERT, MOPERID, INSERTUSER, FLAGOK, BRAKFLAG, MERA
      )
      VALUES (    
        ?,       -- MAGAZINEID
        13,          -- USERGROUPID
        58,          -- USERID
        162,         -- MPRETENTYPEID
        328,         -- FINDUSERID
        ?,           -- PRIM
        ?,           -- DATEINSERT
        345,         -- MOPERID
        75,          -- INSERTUSER
        0,           -- FLAGOK
        0,           -- BRAKFLAG
        205          -- MERA
      ) RETURNING ID;
    """,
                          "params": [
                            orderId,
                            "Брак стекла",
                            formattedDate

                          ]
                        };

                        final response2 = await http.post(
                          uri,
                          headers: {"Content-Type": "application/json"},
                          body: json.encode(requestBody),
                        );

                        if (response2.statusCode == 200) {
                          final jsonResponse = json.decode(response2.body);

                            final insertedId = jsonResponse["ID"];
                            print("Вставлен ID: $insertedId");



                          final uri = Uri.parse('http://172.16.4.104:3000/sql');


print(_commentController.text);
print("kolvosel $kolvosel");
                          final requestBody = {
                            "nik": tehhclass.user_nik,
                            "pass": tehhclass.user_pass,
                            "sql": """
     INSERT INTO MAGAZINEWOTDELKAZAM (    
    MAGAZINEID,    
    MAGAZINEZAMID,
    MCUSTOMID,
    KOLVO,
	PRIM
)
VALUES (    
    ?,          -- MAGAZINEID    
    ?,            -- MAGAZINEZAMID (ссылка на ранее вставленную запись)
      (
        SELECT FIRST 1 ID 
        FROM MCUSTOM 
        WHERE CustomID = ? AND Art_Material = ?
    ),           -- MPCUSTOMID (ID из таблицы MCUSTOM)
    ?,            -- KOLVO
	?            -- PRIM
);
    """,
                            "params": [
                              orderId,
                              insertedId,
                              orderId,
                              articul,
                              kolvosel,
                              _commentController.text

                            ]
                          };

                          final response = await http.post(
                            uri,
                            headers: {"Content-Type": "application/json"},
                            body: json.encode(requestBody),
                          );

                          if (response.statusCode == 200) {

                            ScaffoldMessenger.of(context).showSnackBar(  SnackBar(
                              content: Text(
                                'Успешно отправлено',
                                style: TextStyle(color: Colors.white), // Белый текст
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ));

                            setState(() {
                              articul ='';
                            });


                            print("Всё ок");

                          } else {
                            print('Ошибка сервера: ${response.statusCode}');
                            print(response.body);
                          }


                        } else {
                          print('Ошибка сервера: ${response2.statusCode}');
                          print(response2.body);
                        }




                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Опишите проблему...',
                      ),
                    ),
                    const SizedBox(height: 16),
                   // const Text('Фото:'),
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
        floatingActionButton: articul == ''
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
                                cameras: widget.cameras, brak: true, iddetal: articul,)));

                       selectzakaz();
                  },
                )
              ]));
  }
}
