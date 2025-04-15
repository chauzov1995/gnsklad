import 'package:flutter/widgets.dart';
import 'package:flutter_broadcasts/flutter_broadcasts.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';

class tehhclass {
  static String user_nik='';
  static String user_pass='';
  static late Database database;
  static int selectedIndex = 0;
  static FocusNode myFocusNode1 = FocusNode();
  static FocusNode myFocusNode2 = FocusNode();


  static FlutterDataWedge dw = FlutterDataWedge(profileName: "gnprof");
  static BroadcastReceiver receiver = BroadcastReceiver(
    names: <String>["com.android.scanner.broadcast", "android.intent.action.SCANRESULT"],
  );

 static Future<Database> initbd() async {

    database = await openDatabase('my_db.db', version: 2,
        onCreate: (Database db, int version) async {
          // When creating the db, create the table
          await db.execute(
              'CREATE TABLE Test (id INTEGER PRIMARY KEY, sort INTEGER NOT NULL DEFAULT 1)');
          await db.execute(
              "CREATE TABLE Users (id INTEGER PRIMARY KEY, `NIK` varchar NOT NULL DEFAULT '', `USERGROUP` varchar NOT NULL DEFAULT '', `FIO` varchar NOT NULL DEFAULT '', `MUSERGROUPID` varchar NOT NULL DEFAULT '', `USERPASSWORD` varchar NOT NULL DEFAULT '')");

        },onUpgrade:  (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 2) {
            print("update2");
            await db.execute(
                "CREATE TABLE Users (id INTEGER PRIMARY KEY, `NIK` varchar NOT NULL DEFAULT '', `USERGROUP` varchar NOT NULL DEFAULT '', `FIO` varchar NOT NULL DEFAULT '', `MUSERGROUPID` varchar NOT NULL DEFAULT '', `USERPASSWORD` varchar NOT NULL DEFAULT '')");


          }});


    List<Map> list =
    await database.rawQuery('SELECT * FROM Users');
    print(list.length);
print("asdasdasdasdasdasdasdasd");
    if(list.length>0) {
      user_nik = list[0]['NIK'];
      print(user_nik);
      user_pass = list[0]['USERPASSWORD'];
    }

    return database;
  }


}