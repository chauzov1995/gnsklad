import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

// Define a custom Form widget.
class photoobzor extends StatefulWidget {

  dynamic asdasdasd;
  photoobzor(this.asdasdasd);


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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("id"+widget.asdasdasd['id'].toString())
      ),
      body: Container(
          child: PhotoView(
            imageProvider: CachedNetworkImageProvider(
                widget.asdasdasd['path']
            )
          )),
    );
  }
}
