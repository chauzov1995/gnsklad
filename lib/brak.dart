import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';

import 'package:flutter_datawedge/flutter_datawedge.dart';

import 'package:gnsklad/camera_screen.dart';
import 'package:gnsklad/camera_screen19.dart';
import 'package:gnsklad/camera_screen_sklad.dart';

import 'package:gnsklad/gallery_screen_s.dart';
import 'package:gnsklad/main.dart';
import 'package:gnsklad/photoobzor.dart';
import 'package:gnsklad/tehhclass.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:gnsklad/postavshikir.dart';
import 'package:gnsklad/tars.dart';
import 'package:http/http.dart' as http;

import 'QRScanPage.dart';

// Define a custom Form widget.
class brak extends StatefulWidget {
  final List<CameraDescription> cameras;

  brak(this.cameras);

  @override
  _brakState createState() => _brakState();
}

class _brakState extends State<brak> with WidgetsBindingObserver {
  _brakState();

  String _scannerStatus = "Scanner status";
  String _lastCode = '';
  final bool _isEnabled = true;
  final TextEditingController _commentController = TextEditingController();
  String articul = "";
  String orderId = "";
  String name = "";
  String salon_zak = "";
  int kolvo = 0;

  String? selectedzakaz;
  double _keyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    HttpOverrides.global = MyHttpOverrides();
    initScanner4();

    firstload();
  }

  List<dynamic> photospisurl = [];

  qrscanres() async {
    if (_commentController.text != "") {
      bool? shouldProceed = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Внимание'),
            content: Text('Вы не отправили замечание о браке. Продолжить?'),
            actions: [
              TextButton(
                child: Text('Отмена'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              ElevatedButton(
                child: Text('Да'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (shouldProceed == true) {
        _commentController.text = "";
        // выполнить переход или действие
      } else {
        return;
      }
    }

    kolvosel = 0;
    _isSending = false;
    salon_zak = "";

    print(jsonDecode(_lastCode)['article']);
    var jsonotv = jsonDecode(_lastCode);
    articul = jsonotv['article'];
    salon_zak = jsonotv['number'].toString();
    orderId = salon_zak.split('_')[1].substring(0, 6);
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

    print(requestBody);

    final response = await http.post(
      uri,
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
          qrscanres();
        }
      }
    });

    //для зебры
    StreamSubscription onScanSubscription =
        tehhclass.dw.onScanResult.listen((ScanResult result) {
      if (tehhclass.selectedIndex == 3) {
        _lastCode = result.data;
        setState(() {});
        qrscanres();

        /*
          print("initScanner2");
          print(_lastCode);
          editingController.text = tehhclass.myFocusNode2.hasFocus?"":_lastCode;
          selectedzakaz = _lastCode;
          await selectzakaz();*/
        //filterSearchResults(_lastCode);
      }
    });
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;

    if (_keyboardHeight > 0 && bottomInset == 0) {
      // Клавиатура была открыта и закрылась
      FocusScope.of(context).unfocus();
    }

    _keyboardHeight = bottomInset;
  }

  Future<void> selectzakaz() async {
    setState(() {
      photospisurl = [];
    });
    var response = await http
        .get(Uri.parse("https://teplogico.ru/gn1brak/" + articul.toString()));
    photospisurl = json.decode(response.body);
    print(photospisurl);
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      kolvosel = page;
      print(kolvosel);
    });
  }

  bool _isSending = false;

  Future<void> sendEmail() async {
    setState(() => _isSending = true);
    String telopisma = "";
    final uri = Uri.parse('http://172.16.4.104:3000/sql');

    // Получаем сегодняшнюю дату в формате ДД.ММ.ГГГГ
    final now = DateTime.now();
    final formattedDate = DateFormat('dd.MM.yyyy').format(now);

    final requestBody = {
      "nik": tehhclass.user_nik,
      "pass": tehhclass.user_pass,
      "sql": """
  SELECT
    mc.art_material,
    mc.name,
    mwz.kolvo,
    mwz.prim,
    (
        SELECT SUM(mk.kolvo)
        FROM MKonstr mk
        WHERE mk.Art_Material = mc.art_material AND mk.CUSTOMID = mwz.MAGAZINEID
    ) AS sum_kolvo_from_konstr
FROM
    magazinewotdelkazam mwz
LEFT JOIN mcustom mc ON mc.id = mwz.MCustomID
LEFT JOIN magazinezam mz ON mz.id = mwz.MAGAZINEZAMID
WHERE
    mwz.MAGAZINEID = ? and mz.DATEINSERT=?

    """,
      "params": [orderId, formattedDate]
    };

    final response44 = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode(requestBody),
    );

    if (response44.statusCode == 200) {
      var data = json.decode(response44.body);
      print('Ответ от сервера: $data');

      for (var p in data) {
        telopisma += '''
  ${p['ART_MATERIAL']} - ${p['NAME']} - ${p['KOLVO']}шт (из ${p['SUM_KOLVO_FROM_KONSTR']}-х) - ${p['PRIM']}.
''';
      }
    } else {
      print('Ошибка сервера: ${response44.statusCode}');
      return;
    }

    print("asdasd");

    const username = 'robo@giulianovars.ru';
    const password = '91B009E0055'; // Лучше хранить в .env или защищённо

    final smtpServer = SmtpServer(
      'smtp.yandex.ru',
      port: 465,
      ssl: true,
      username: username,
      password: password,
    );
    print("https://teplogico.ru/gn1brakrassil/" + orderId.toString());
    var response = await http.get(
        Uri.parse("https://teplogico.ru/gn1brakrassil/" + orderId.toString()));
    print(json.decode(response.body));
    List<dynamic> urls = json.decode(response.body);
    print("asdasd");
    print(urls);

    // Скачиваем все файлы
    final tempDir = await getTemporaryDirectory();
    final attachments = <FileAttachment>[];

    for (int i = 0; i < urls.length; i++) {
      final url = urls[i]['path'];
      final l_iddetal = urls[i]['iddetal'];
      final l_id = urls[i]['id'];
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final file = File('${tempDir.path}/attachment_$i.jpg');
        await file.writeAsBytes(response.bodyBytes);

        attachments.add(FileAttachment(file)
          ..location = Location.attachment
          ..fileName = '${l_iddetal}_${l_id}.jpg');
      } else {
        print('Ошибка при загрузке: $url');
      }
    }

    // Создаём письмо
    final message = Message()
      ..from = Address(username, 'Клюкин Дмитрий')
      //  ..recipients.add('k3@resursm.ru') // основной получатель
      ..recipients.add('brakstekla@resursm.ru') // основной получатель
      //  ..recipients.add('chauzov1995@yandex.ru') // основной получатель
      //   ..ccRecipients.add('manager@example.com') // копия
      ..subject = 'Брак стекла — ${salon_zak}'
      ..text = '''
Доброе утро!

Во вложении фото брака к заказу ${salon_zak}:
${telopisma}


С уважением, Клюкин Дмитрий,
Технолог ЗАО ПО «Ресурс»,
www.giulianovars.ru
тел: 8-922-935-30-45,
      8-961-563-12-86.
'''
      ..attachments = attachments;

    try {
      final sendReport = await send(message, smtpServer);
      print('Письмо отправлено: $sendReport');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Письмо отправлено')),
      );
    } on MailerException catch (e) {
      print('Ошибка при отправке письма: $e');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    } finally {
      setState(() {
        _isSending = false;
        orderId = "";
      });
    }
  }

  Future<void> sendbrak() async {
    if (kolvosel == 0) {
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

    final requestBody3 = {
      "nik": tehhclass.user_nik,
      "pass": tehhclass.user_pass,
      "sql": """
     SELECT FIRST 1 ID FROM MAGAZINEZAM 
WHERE 
  MAGAZINEID = ? AND 
  PRIM = ? AND 
  DATEINSERT = ?;
    """,
      "params": [orderId, "Брак стекла", formattedDate]
    };
    int? insertedId = null;
    final response3 = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode(requestBody3),
    );

    if (response3.statusCode == 200) {
      final jsonResponse = json.decode(response3.body);
      print(jsonResponse);
      if (jsonResponse is List && jsonResponse.isNotEmpty) {
        insertedId = jsonResponse[0]["ID"];
        print("Найден ID: $insertedId");
      } else {
        print("ID не найден — ответ пустой или не содержит нужных данных");
      }
    } else {
      print('Ошибка сервера: ${response3.statusCode}');
      print(response3.body);
      return;
    }

    //  return;

    if (insertedId == null) {
      final requestBody2 = {
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
        "params": [orderId, "Брак стекла", formattedDate]
      };

      final response2 = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode(requestBody2),
      );

      if (response2.statusCode == 200) {
        final jsonResponse = json.decode(response2.body);

        insertedId = jsonResponse["ID"];
        print("Вставлен ID: $insertedId");
      } else {
        print('Ошибка сервера: ${response2.statusCode}');
        print(response2.body);
        return;
      }
    }

    print(_commentController.text);
    print("kolvosel $kolvosel");
    final formattedDate2 = DateFormat('dd.MM').format(now);
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
        _commentController.text.trim(),

      ]
    };

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode(requestBody),
    );



    final requestBody2 = {
      "nik": tehhclass.user_nik,
      "pass": tehhclass.user_pass,
      "sql": """
    UPDATE MCUSTOM
SET PRIM = 
    COALESCE(PRIM, '') || 
    CASE WHEN COALESCE(PRIM, '') <> '' THEN ' ' ELSE '' END ||
    ?
WHERE CustomID = ? AND Art_Material = ?;
    """,
      "params": [

        "${_commentController.text.trim()} (${formattedDate2})",
        orderId,
        articul,
      ]
    };

    final response2 = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode(requestBody2),
    );

    if (response.statusCode == 200 && response2.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Успешно отправлено',
          style: TextStyle(color: Colors.white), // Белый текст
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));

      setState(() {
        _commentController.text = "";
        articul = '';
      });

      print("Всё ок");
    } else {
      print('Ошибка сервера: ${response.statusCode}');
      print(response.body);
    }
  }

  void _insertTextAtCursor(String text) {
    // Устанавливаем фокус


    final textValue = _commentController.text;
    final selection = _commentController.selection;

    final newText = textValue.replaceRange(
      selection.start,
      selection.end,
      text,
    );

    final cursorPosition = selection.start + text.length;

    _commentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }

  final words = ['брак', 'скол'];





  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Брак"),
          actions: [
            IconButton(
              icon: Icon(Icons.qr_code),
              tooltip: 'Сканировать QR-код',
              onPressed: () async {
                // Обработчик нажатия
                print('QR иконка нажата');

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => QRScanPage()),
                );
                if (result != null) {
                  print(result);
                  _lastCode = result;
                  qrscanres();
                  /*  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('QR-код: $result')),
                  );*/
                }
              },
            ),
          ],
        ),
        body: Container(
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          child: articul == ''
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("Отсканируй QR-код"),
                  orderId == "" || true //закоментил отправку
                      ? Container()
                      : Column(
                          children: [
                            Text(
                              "или\nпо заказу ${orderId}",
                              textAlign: TextAlign.center,
                            ),
                            _isSending
                                ? Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Center(
                                        child:
                                            const CircularProgressIndicator()),
                                  )
                                : ElevatedButton(
                                    onPressed: () {
                                      sendEmail();
                                    },
                                    child: const Text('Отправить письмо'),
                                  ), //
                          ],
                        )
                ]))
              : ListView(
                  children: <Widget>[
                    Card(
                      child: ListTile(
                          title: Text(articul),
                          subtitle: Column(
                            children: [
                              Text(
                                  'Заказ: ${orderId}\n${name}\nКол-во: $kolvo'),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: List.generate(kolvo > 7 ? 7 : kolvo,
                                    (index) {
                                  final pageNumber = index + 1;
                                  final isSelected = pageNumber == kolvosel;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2.0),
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          backgroundColor: isSelected
                                              ? Colors.blue
                                              : Colors.grey[300],
                                          foregroundColor: isSelected
                                              ? Colors.white
                                              : Colors.black,
                                          textStyle:
                                              const TextStyle(fontSize: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _selectPage(pageNumber),
                                        child: Text('$pageNumber'),
                                      ),
                                    ),
                                  );
                                }),
                              )
                            ],
                          )),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => camera_screen_sklad(
                                          name: orderId,
                                          cameras: widget.cameras,
                                          brak: true,
                                          iddetal: articul,
                                        )));

                            selectzakaz();
                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Цвет кнопки
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10), // Скруглённые углы
                            ),
                            //  elevation: 4,
                          ),
                          icon: const SizedBox(),
                          // Пусто слева, если не нужна иконка до текста
                          label: Row(
                            children: const [
                              Text(
                                'Добавить фото',
                                style: TextStyle(color: Colors.white),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.photo_camera_rounded,
                                  color: Colors.white),
                            ],
                          ),
                        )
                      ],
                    ),
                    SizedBox(
                      height: 7,
                    ),
                    TextField(
                      controller: _commentController,
                   //   focusNode: tehhclass.myFocusNode3,
                      maxLines: 2,
                      // textInputAction: TextInputAction.send,
                      // 👈 это покажет кнопку "Отправить"

                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Примечание о браке',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: words.map((word) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: SizedBox(
                            width: 52,
                            height: 32,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                textStyle: const TextStyle(fontSize: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: () {
                                _insertTextAtCursor(word + " ");
                              },
                              child: Text(word),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // const Text('Фото:'),
                    Container(
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
                            onTap: () async {
                              print("adsasdas");
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => photoobzor(
                                          photospisurl[index],
                                          "chauzov_gn_fotobrak")));

                              selectzakaz();
                            },
                          ),
                        ),
                      ),
                    )
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
                  child: Icon(Icons.send),
                  onPressed: sendbrak,
                )
              ]));
  }
}
