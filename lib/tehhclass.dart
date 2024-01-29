import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';

class tehhclass {
  static String user_nik='';
  static String user_pass='';
  static late Database database;

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
    return database;
  }


}