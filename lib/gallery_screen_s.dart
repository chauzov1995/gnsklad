import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gnsklad/main.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class GalleryScreen2 extends StatefulWidget {
  postav name;

  GalleryScreen2(this.name, {Key? key}) : super(key: key);

  @override
  _GalleryScreen2State createState() => _GalleryScreen2State();
}

class _GalleryScreen2State extends State<GalleryScreen2> {
  @override
  void initState() {

    super.initState();

    firstasd();
  }

  firstasd() async {

    // http://teplogico.ru/gn-spispost
    var response = await http
        .get(Uri.parse('https://teplogico.ru/gn11/${widget.name.id}'));

    users = (json.decode(response.body) as List)
        .map((data) => photo.fromJson(data))
        .toList();

    setState(() {});

    print(users[0].path);
  }

  List<photo> users = <photo>[];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name.name!),
      ),
      body: Padding(padding: const EdgeInsets.only(top: 10),
      child:  ListView.separated(

        itemBuilder: (BuildContext context, int index) { return

          GestureDetector(
              onTap: () async {
                print(users[index].path);

                await launch(users[index].path!);
              },
              child:
              ListTile(
                title: Text('${DateFormat('dd.MM.yyyy').format(DateTime.fromMillisecondsSinceEpoch(users[index].timeselect!*1000))}.pdf'),
                leading: Image.network(
                  "https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/PDF_file_icon.svg/833px-PDF_file_icon.svg.png",
                  fit: BoxFit.contain,height: 50,),
              )

          );

        },
        itemCount: users.length,
        separatorBuilder: (BuildContext context, int index) => const Divider(),

      ),),
    );
  }
}

class photo {
  int? id;
  String? path;
  int? timeselect;

  photo({this.id, this.path,this.timeselect});

  photo.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    path = json['path'];
    timeselect = json['timeselect'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['path'] = path;
    data['timeselect'] = timeselect;
    return data;
  }
}
