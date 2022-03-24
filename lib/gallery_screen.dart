import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gnsklad/main.dart';
import 'package:http/http.dart' as http;


class GalleryScreen extends StatefulWidget {

  postav name;
  GalleryScreen(this.name) ;

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  void initState() {



    super.initState();


firstasd();
  }

  firstasd() async {
   // http://teplogico.ru/gn-spispost
   var  response = await  http.get(Uri.parse('https://teplogico.ru/gn11/${widget.name.id}'));

  users = (json.decode(response.body) as List)
       .map((data) => photo.fromJson(data))
       .toList();

setState(() {

});

   print(users[0].path);
  }


   List<photo> users=<photo>[];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name.name!),
      ),
      body: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: users
            .map((image) => Image.network( image.path??"", fit:BoxFit.cover))
            .toList(),
      ),
    );
  }
}


class photo {
  int? id;
  String? path;

  photo({this.id, this.path});

  photo.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    path = json['path'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['path'] = this.path;
    return data;
  }
}