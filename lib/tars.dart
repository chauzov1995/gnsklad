import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:http/http.dart' as http;
import 'package:gnsklad/tehhclass.dart';
import 'package:vibration/vibration.dart';
import 'package:vibration/vibration_presets.dart';

import 'package:volume_controller/volume_controller.dart';

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


  @override
  void initState() {
    // TODO: implement initState
    firstinit();

    super.initState();
  }

  late List spis;
  Map spiss = {};

  firstinit() async {
    var response = await http.get(Uri.parse(
        'http://172.16.4.104:3000/getalltars?nik=${tehhclass.user_nik}&pass=${tehhclass.user_pass}'));

    spis = json.decode(response.body);

    for (var asdas in spis) {
      spiss.addAll({asdas['ID']: asdas['NAME']});
    }

    _controller = AnimationController(
      vsync: this, // the SingleTickerProviderStateMixin
      duration: Duration(seconds: 6),
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
  int statuss = 0;

  void initScanner2() {
    //для новых сканеров
    tehhclass.receiver.messages.listen((BroadcastMessage? object) {

      if (tehhclass.selectedIndex == 2) {
        print("asdasdasdasdsad");
        if (object != null) {
          setState(() {
            if (object.data!.containsKey('value')) {
              _lastCode = object.data!['value'];
            }
            if (object.data!.containsKey('scandata')) {
              _lastCode = object.data!['scandata'];
            }
            if (object.data!.containsKey('SCAN_BARCODE1')) {
              _lastCode = object.data!['SCAN_BARCODE1'];
            }
            print("initScanner3");
            print(_lastCode);
            // editingController.text = _lastCode;
            if (statuss == 1) {
              statuss = 2;
            }
            findtara(int.parse(_lastCode));
          });
        }
      }
    });

    //для зебры

    StreamSubscription onScanSubscription =
        tehhclass.dw.onScanResult.listen((ScanResult result) {
      if (tehhclass.selectedIndex == 2) {
        setState(() {
          _lastCode = result.data;
          print("initScanner3");
          print(_lastCode);
          // editingController.text = _lastCode;
          if (statuss == 1) {
            statuss = 2;
          }
          findtara(int.parse(_lastCode));
        });
      }
    });

    StreamSubscription onScanSubscription2 =
        tehhclass.dw.onScannerStatus.listen((ScannerStatus result) {
      if (tehhclass.selectedIndex == 2) {
        ScannerStatusType status = result.status;
        setState(() {
          print(status.index);
          _scannerStatus = status.index;

          if (_scannerStatus == 1) {
            statuss = 1;
          } else if (_scannerStatus == 0 && statuss == 1) {
            if (countasdasd == '') {
              statuss = 0;
            } else {
              statuss = 3;
            }
          }
        });
      }
    });
  }
bool flag_vibral_det_v_taru=false;
  void findtara(int sh_curr) async {
    // int sh_curr = 1530000101;
    // int sh_curr = 12519856;
    if ((sh_curr > 1500000000) && (sh_curr < 1600000000)) {//если тара
      setState(() {
        countasdasd = '';
        zakazid = '';
        nakleyka = '';
      });
      res_DetalKode = sh_curr - 1500000000;
      if (spiss[res_DetalKode] == null) {
        countasdasd = "нет тары";
      } else {
        countasdasd = "${spiss[res_DetalKode]}";
      }
      statuss = 3;
      flag_vibral_det_v_taru=false;
      setState(() {});
    } else if ((sh_curr > 12000000) && (sh_curr < 99000000)) {// если деталь
      if(flag_vibral_det_v_taru){
        statuss = 3;

        setState(() {});
        playErrorSound();
        _controller.reset();
        _controller.forward();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сначала снова отсканируй тару',
              style: TextStyle(color: Colors.white), // белый текст
            ),
            backgroundColor: Colors.red, // красный фон
            behavior: SnackBarBehavior.floating, // можно добавить чтобы "висел" над контентом
            duration: Duration(seconds: 2),
          ),
        );

        return;

      }
      if (countasdasd == '' || countasdasd == "нет тары") return;
      setState(() {
        zakazid = '';
        nakleyka = '';
      });

      int idmagazupak = sh_curr - 12000000;
      var response = await http.get(Uri.parse(
          'http://172.16.4.104:3000/setmtara?id=${idmagazupak}&mtaraid=${res_DetalKode}&nik=${tehhclass.user_nik}&pass=${tehhclass.user_pass}'));
      var otvet = json.decode(response.body);
      zakazid = otvet[0]['MAGAZINE_ID'].toString();
      nakleyka = otvet[0]['CONCATENATION'].toString();
      _controller.reset();
      _controller.forward();
      statuss = 3;
      flag_vibral_det_v_taru=true;
      setState(() {});
      print(otvet);
    }
  }

  final _audioPlayer = AudioPlayer();

  Future<void> playErrorSound() async {
    try {
      VolumeController.instance.showSystemUI = false;
  //    double volume = await VolumeController.instance.getVolume();
      await VolumeController.instance.setVolume(1);


      Vibration.vibrate(preset: VibrationPreset.doubleBuzz);


      await _audioPlayer.play(AssetSource('sounds/error-126627.mp3'));

   //   await VolumeController.instance.setVolume(volume);

    } catch (e) {
      print('Ошибка воспроизведения звука: $e');
    }
  }


  @override
  void dispose() {
    _controller.dispose();


    super.dispose();
  }

  int res_DetalKode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Тары"),
        ),
        body: Center(
            child: statuss == 0
                ? Text("Отсканируй штрихкод тары")
                : statuss != 3
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          Text("Сканирую...")
                        ],
                      )
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
                            ]))));
  }
}
