import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int res_DetalKode = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: AnimatedContainer(
            color: animation.value,
            width: double.infinity,
            duration: Duration(milliseconds: 6),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: () async {
                  //int sh_curr = 1500000101;
                  int sh_curr = 12519856;
                  if ((sh_curr > 1500000000) && (sh_curr < 1600000000)) {
                    zakazid = '';
                    nakleyka = '';
                    res_DetalKode = sh_curr - 1500000000;
                    var response = await http.get(Uri.parse(
                        'http://172.16.4.104:3000/getyarlik?id=$res_DetalKode'));

                    //   List<postav> prrreeee = (json.decode(response.body) as List)
                    //      .map((data) => postav.fromJson(data))
                    //   .toList();

                    var otvet = json.decode(response.body);
                    if (otvet.containsKey('err')) {
                      countasdasd = otvet['err'];
                    } else {
                      countasdasd = "${otvet['taraName']}";
                    }

                    setState(() {});
                  } else if ((sh_curr > 12000000) && (sh_curr < 99000000)) {
                    if (countasdasd == '') return;

                    int idmagazupak = sh_curr - 12000000;
                    var response = await http.get(Uri.parse(
                        'http://172.16.4.104:3000/setmtara?id=${idmagazupak}&mtaraid=${res_DetalKode}'));
                    var otvet = json.decode(response.body);
                    zakazid = otvet[0]['MAGAZINE_ID'].toString();
                    nakleyka = otvet[0]['CONCATENATION'].toString();
                    _controller.reset();
                    _controller.forward();
                    setState(() {});
                    print(otvet);
                  }
                },
                child: Text("скан"),
              ),
              Text(
                countasdasd,
                style: TextStyle(fontSize: 68),
              ),
              countasdasd == '' || zakazid == ""
                  ? Container()
                  : Column(
                      children: [
                        SizedBox(
                          height: 40,
                        ),
                        Text(
                          "Заказ",
                          style: TextStyle(fontSize: 28),
                        ),
                        Text(
                          "${zakazid}",
                          style: TextStyle(fontSize: 50),
                        ),
                        Text(
                          "${nakleyka}",
                          style: TextStyle(
                              fontSize: 106, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
            ])));
  }
}
