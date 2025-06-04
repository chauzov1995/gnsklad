import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';

// Define a custom Form widget.
class photoobzor extends StatefulWidget {

  dynamic idfot;
  String table;
  photoobzor(this.idfot, this.table);


  @override
  _photoobzorState createState() => _photoobzorState();
}


class _photoobzorState extends State<photoobzor> {

  _photoobzorState();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }
  @override
  void dispose() {
    super.dispose();
  }

  void _deleteItem(BuildContext context) {
    // Логика удаления, например, показ диалога подтверждения
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить'),
        content: const Text('Вы уверены, что хотите удалить элемент?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Отмена
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              // TODO: Добавьте логику удаления


              var response = await http
                  .get(Uri.parse("https://teplogico.ru/gndeletefot/${widget.idfot['id'].toString()}/${widget.table.toString()}"));





              Navigator.pop(context);
              Navigator.pop(context);

            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("id"+widget.idfot['id'].toString()),
          actions: [
      IconButton(
      icon: const Icon(Icons.delete),
      tooltip: 'Удалить',
      onPressed: () => _deleteItem(context),
    ),
    ],
      ),
      body: Container(
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(
                widget.idfot['path']
            )
          )),
    );
  }
}
